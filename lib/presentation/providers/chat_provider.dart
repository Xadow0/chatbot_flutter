import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../data/models/message_model.dart';
import '../../data/models/quick_response_model.dart';
import '../../data/models/ollama_models.dart';
import '../../data/models/local_llm_models.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/ollama_service.dart';
import '../../data/services/openai_service.dart';
import '../../data/services/local_llm_service.dart';
import '../../data/services/ai_service_selector.dart';
import '../../data/services/preferences_service.dart';
import '../../data/services/ai_service_adapters.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../domain/usecases/command_processor.dart';
import '../../domain/usecases/send_message_usecase.dart';

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  List<QuickResponse> _quickResponses = QuickResponseProvider.defaultResponses;
  bool _isProcessing = false;
  bool _isNewConversation = true;

  late SendMessageUseCase _sendMessageUseCase; // No final - se actualiza al cambiar proveedor
  late final AIServiceSelector _aiSelector;
  late final PreferencesService _preferencesService;
  
  // Referencias a los servicios
  late final GeminiService _geminiService;
  late final OllamaService _ollamaService;
  late final OpenAIService _openaiService;
  late final LocalLLMService _localLLMService;
  
  // Adaptadores
  late final GeminiServiceAdapter _geminiAdapter;
  late OllamaServiceAdapter _ollamaAdapter; // No final porque se recrea
  late final OpenAIServiceAdapter _openaiAdapter;
  late final LocalLLMServiceAdapter _localLLMAdapter;
  
  // CommandProcessor que se actualizará
  late CommandProcessor _commandProcessor; // No final - se actualiza al cambiar proveedor
  
  bool _showModelSelector = false;
  List<OllamaModel> _availableModels = [];
  String _currentModel = 'phi3:latest';
  AIProvider _currentProvider = AIProvider.gemini;

  ChatProvider() {
    // Inicializar servicios
    _geminiService = GeminiService();
    _ollamaService = OllamaService();
    _openaiService = OpenAIService();
    _localLLMService = LocalLLMService();
    
    // Crear adaptadores
    _geminiAdapter = GeminiServiceAdapter(_geminiService);
    _ollamaAdapter = OllamaServiceAdapter(_ollamaService, _currentModel);
    _openaiAdapter = OpenAIServiceAdapter(_openaiService);
    _localLLMAdapter = LocalLLMServiceAdapter(_localLLMService);
    
    _preferencesService = PreferencesService();
    
    _aiSelector = AIServiceSelector(
      geminiService: _geminiService,
      ollamaService: _ollamaService,
      openaiService: _openaiService,
      localLLMService: _localLLMService,
    );
    
    // Inicializar CommandProcessor con Gemini por defecto
    _commandProcessor = CommandProcessor(_geminiAdapter);
    final localRepository = LocalChatRepository();

    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: _commandProcessor,
      chatRepository: localRepository,
    );

    _initializeModels();
    _addWelcomeMessage();
  }

  /// Actualiza el CommandProcessor según el proveedor actual
  void _updateCommandProcessor() {
    AIServiceBase currentAdapter;
    
    switch (_currentProvider) {
      case AIProvider.gemini:
        currentAdapter = _geminiAdapter;
        debugPrint('   🔵 Usando GeminiAdapter');
        break;
      case AIProvider.ollama:
        // Actualizar el modelo en el adaptador existente
        _ollamaAdapter.updateModel(_currentModel);
        currentAdapter = _ollamaAdapter;
        debugPrint('   🟪 Usando OllamaAdapter con modelo: $_currentModel');
        break;
      case AIProvider.openai:
        currentAdapter = _openaiAdapter;
        debugPrint('   🟢 Usando OpenAIAdapter');
        break;
      case AIProvider.localLLM:
        currentAdapter = _localLLMAdapter;
        debugPrint('   🟠 Usando LocalLLMAdapter');
        break;
    }
    
    // Crear nuevo CommandProcessor
    _commandProcessor = CommandProcessor(currentAdapter);
    
    // Actualizar SendMessageUseCase
    final localRepository = LocalChatRepository();
    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: _commandProcessor,
      chatRepository: localRepository,
    );
    
    debugPrint('🔄 [ChatProvider] CommandProcessor actualizado para: $_currentProvider');
  }

  // Getters
  List<Message> get messages => List.unmodifiable(_messages);
  List<QuickResponse> get quickResponses => _quickResponses;
  bool get isProcessing => _isProcessing;
  bool get showModelSelector => _showModelSelector;
  List<OllamaModel> get availableModels => _availableModels;
  String get currentModel => _currentModel;
  AIProvider get currentProvider => _currentProvider;
  ConnectionInfo get connectionInfo => _aiSelector.connectionInfo;
  bool get ollamaAvailable => _aiSelector.ollamaAvailable;
  
  AIServiceSelector get aiSelector => _aiSelector;
  bool get openaiAvailable => _aiSelector.openaiAvailable;
  String get currentOpenAIModel => _aiSelector.currentOpenAIModel;
  List<String> get availableOpenAIModels => _aiSelector.availableOpenAIModels;
  
  LocalLLMStatus get localLLMStatus => _aiSelector.localLLMStatus;
  bool get localLLMAvailable => _aiSelector.localLLMAvailable;
  bool get localLLMLoading => _aiSelector.localLLMLoading;
  String? get localLLMError => _aiSelector.localLLMError;
  
  Stream<ConnectionInfo> get connectionStream => _aiSelector.connectionStream;

  Future<void> _initializeModels() async {
    try {
      debugPrint('🎬 [ChatProvider] Inicializando modelos...');
      
      await _aiSelector.refreshOllama();
      
      if (_aiSelector.ollamaAvailable) {
        _availableModels = _aiSelector.availableModels;
        if (_availableModels.isNotEmpty) {
          _currentModel = _availableModels.first.name;
          _ollamaAdapter.updateModel(_currentModel);
        }
      }
      
      await _restoreUserPreferences();
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error inicializando modelos: $e');
    }
  }
  
  Future<void> _restoreUserPreferences() async {
    try {
      debugPrint('🔄 [ChatProvider] Restaurando preferencias...');
      
      final lastProvider = await _preferencesService.getLastProvider();
      
      if (lastProvider != null) {
        bool canRestore = false;
        
        switch (lastProvider) {
          case AIProvider.gemini:
            canRestore = true;
            break;
            
          case AIProvider.ollama:
            canRestore = _aiSelector.ollamaAvailable;
            if (!canRestore) {
              debugPrint('   ⚠️ Ollama no disponible, usando Gemini por defecto');
            }
            break;
            
          case AIProvider.openai:
            canRestore = _aiSelector.openaiAvailable;
            if (!canRestore) {
              debugPrint('   ⚠️ OpenAI no disponible, usando Gemini por defecto');
            }
            break;
            
          case AIProvider.localLLM:
            canRestore = _aiSelector.localLLMAvailable;
            if (!canRestore) {
              debugPrint('   ⚠️ LLM Local no disponible, usando Gemini por defecto');
            }
            break;
        }
        
        if (canRestore) {
          _currentProvider = lastProvider;
          await _aiSelector.setProvider(lastProvider);
          _updateCommandProcessor();
          debugPrint('   ✅ Restaurado proveedor: $lastProvider');
          
          await _restoreProviderModel(lastProvider);
        } else {
          _currentProvider = AIProvider.gemini;
          await _aiSelector.setProvider(AIProvider.gemini);
          _updateCommandProcessor();
          debugPrint('   ℹ️ Usando Gemini por defecto');
        }
      } else {
        debugPrint('   ℹ️ No hay preferencias previas, usando Gemini');
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error restaurando preferencias: $e');
      _currentProvider = AIProvider.gemini;
      _updateCommandProcessor();
    }
  }
  
  Future<void> _restoreProviderModel(AIProvider provider) async {
    try {
      switch (provider) {
        case AIProvider.ollama:
          final lastModel = await _preferencesService.getLastOllamaModel();
          if (lastModel != null && _availableModels.any((m) => m.name == lastModel)) {
            _currentModel = lastModel;
            await _aiSelector.setOllamaModel(lastModel);
            _ollamaAdapter.updateModel(lastModel);
            debugPrint('   ✅ Restaurado modelo Ollama: $lastModel');
          } else {
            debugPrint('   ℹ️ Modelo Ollama no disponible, usando: $_currentModel');
          }
          break;
          
        case AIProvider.openai:
          final lastModel = await _preferencesService.getLastOpenAIModel();
          if (lastModel != null && _aiSelector.availableOpenAIModels.contains(lastModel)) {
            _aiSelector.setOpenAIModel(lastModel);
            debugPrint('   ✅ Restaurado modelo OpenAI: $lastModel');
          } else {
            debugPrint('   ℹ️ Usando modelo OpenAI por defecto');
          }
          break;
          
        case AIProvider.gemini:
        case AIProvider.localLLM:
          break;
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error restaurando modelo: $e');
    }
  }

  void toggleModelSelector() {
    _showModelSelector = !_showModelSelector;
    notifyListeners();
  }

  void hideModelSelector() {
    if (_showModelSelector) {
      _showModelSelector = false;
      notifyListeners();
    }
  }

  Future<void> changeProvider(AIProvider provider) async {
    try {
      debugPrint('🔄 [ChatProvider] Cambiando proveedor a: $provider');
      
      // Validación especial para LocalLLM
      if (provider == AIProvider.localLLM) {
        debugPrint('   🔍 Verificando estado del LLM local...');
        if (_aiSelector.localLLMStatus != LocalLLMStatus.ready) {
          final statusText = _aiSelector.localLLMStatus.displayText;
          debugPrint('   ❌ LLM local no está listo: $statusText');
          throw Exception('El modelo local no está listo ($statusText). Inícialo primero.');
        }
        debugPrint('   ✅ LLM local está listo');
      }
      
      if (provider == AIProvider.ollama && !_aiSelector.ollamaAvailable) {
        throw Exception('Ollama no está disponible');
      }
      
      if (provider == AIProvider.openai && !_aiSelector.openaiAvailable) {
        throw Exception('OpenAI no está disponible. Configura tu API key.');
      }
      
      // Cambiar proveedor en el selector
      await _aiSelector.setProvider(provider).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Timeout al cambiar proveedor. El servicio no responde.');
        },
      );
      
      _currentProvider = provider;
      
      // Actualizar CommandProcessor
      _updateCommandProcessor();
      
      await _preferencesService.saveLastProvider(provider);
      
      debugPrint('   ✅ Proveedor cambiado a: $provider');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando proveedor: $e');
      
      // Mensaje más específico según el error
      String errorMessage = e.toString();
      if (errorMessage.contains('Timeout')) {
        errorMessage = 'El servicio no responde. Intenta nuevamente.';
      } else if (errorMessage.contains('LateInitialization')) {
        errorMessage = 'Error interno al cambiar proveedor. Reinicia la app.';
      }
      
      throw Exception(errorMessage);
    }
  }

  /// Cambiar modelo de Ollama (nombre correcto del método)
  Future<void> changeModel(String modelName) async {
    try {
      debugPrint('🔄 [ChatProvider] Cambiando modelo Ollama a: $modelName');
      
      if (!_aiSelector.ollamaAvailable) {
        throw Exception('Ollama no está disponible');
      }
      
      await _aiSelector.setOllamaModel(modelName);
      _currentModel = modelName;
      
      // Si Ollama está activo, actualizar el adaptador
      if (_currentProvider == AIProvider.ollama) {
        _ollamaAdapter.updateModel(modelName);
        debugPrint('   🔄 Adaptador actualizado con modelo: $modelName');
      }
      
      await _preferencesService.saveLastOllamaModel(modelName);
      
      debugPrint('   ✅ Modelo cambiado a: $modelName');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando modelo: $e');
      rethrow;
    }
  }

  Future<void> changeOpenAIModel(String modelName) async {
    try {
      debugPrint('🔄 [ChatProvider] Cambiando modelo OpenAI a: $modelName');
      
      if (!_aiSelector.openaiAvailable) {
        throw Exception('OpenAI no está disponible');
      }
      
      _aiSelector.setOpenAIModel(modelName);
      
      await _preferencesService.saveLastOpenAIModel(modelName);
      
      debugPrint('   ✅ Modelo OpenAI cambiado a: $modelName');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando modelo OpenAI: $e');
      rethrow;
    }
  }

  /// Refrescar modelos de Ollama (nombre correcto del método)
  Future<void> refreshModels() async {
    try {
      debugPrint('🔄 [ChatProvider] Refrescando modelos de Ollama...');
      
      await _aiSelector.refreshOllama();
      
      if (_aiSelector.ollamaAvailable) {
        _availableModels = _aiSelector.availableModels;
        
        if (_availableModels.isNotEmpty && 
            !_availableModels.any((m) => m.name == _currentModel)) {
          _currentModel = _availableModels.first.name;
          await _aiSelector.setOllamaModel(_currentModel);
          if (_currentProvider == AIProvider.ollama) {
            _ollamaAdapter.updateModel(_currentModel);
          }
          debugPrint('   ℹ️ Modelo cambiado a: $_currentModel');
        }
      }
      
      debugPrint('   ✅ Modelos refrescados');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error refrescando modelos: $e');
    }
  }

  Future<LocalLLMInitResult> initializeLocalLLM() async {
    debugPrint('🚀 [ChatProvider] Iniciando LLM local...');
    try {
      final result = await _aiSelector.initializeLocalLLM();
      notifyListeners();
      
      if (result.success) {
        debugPrint('✅ [ChatProvider] LLM local inicializado correctamente');
        debugPrint('   📦 Modelo: ${result.modelName}');
        debugPrint('   💾 Tamaño: ${result.modelSize}');
      } else {
        debugPrint('❌ [ChatProvider] Error inicializando LLM local: ${result.error}');
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Excepción al inicializar LLM local: $e');
      notifyListeners();
      return LocalLLMInitResult(
        success: false,
        error: 'Error inesperado: $e',
      );
    }
  }

  Future<void> stopLocalLLM() async {
    debugPrint('🛑 [ChatProvider] Deteniendo LLM local...');
    try {
      await _aiSelector.stopLocalLLM();
      notifyListeners();
      debugPrint('✅ [ChatProvider] LLM local detenido correctamente');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error deteniendo LLM local: $e');
      notifyListeners();
    }
  }

  Future<LocalLLMInitResult> retryLocalLLM() async {
    debugPrint('🔄 [ChatProvider] Reintentando inicialización del LLM local...');
    return await initializeLocalLLM();
  }

  void _addWelcomeMessage() {
    final welcomeMessage = '''
¡Bienvenido al chat! 👋

Aquí puedes conversar conmigo y utilizar los siguientes comandos:

**Comandos disponibles:**

- **/tryprompt** [escribe aquí tu prompt] -- Este comando te permite ejecutar un análisis y mejora de tu prompt, generando como resultado un prompt mejorado en caso de que sea posible.

💡 **Nuevo:** Los comandos ahora usan la IA que tengas seleccionada. Cambia entre Gemini, OpenAI, Ollama o IA Local usando el selector arriba.

¡Empieza escribiendo tu mensaje!''';

    _messages.add(Message.bot(welcomeMessage));
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isProcessing) return;

    debugPrint('\n🚀 [ChatProvider] === ENVIANDO MENSAJE ===');
    debugPrint('   💬 Contenido: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    debugPrint('   🤖 Proveedor actual: $_currentProvider');
    debugPrint('   📝 Modelo actual: $_currentModel');

    if (_isNewConversation) {
      _isNewConversation = false;
    }

    hideModelSelector();

    final userMessage = Message.user(content);
    _messages.add(userMessage);
    _isProcessing = true;
    notifyListeners();

    try {
      String botResponse;
      
      // Los comandos ahora se procesan según el proveedor actual
      if (content.startsWith('/')) {
        debugPrint('   🔸 Detectado comando, procesando con $_currentProvider');
        final response = await _sendMessageUseCase.execute(content);
        botResponse = response.content;
      } else if (_currentProvider == AIProvider.ollama && _aiSelector.ollamaAvailable) {
        debugPrint('   🟪 Usando Ollama...');
        botResponse = await _sendToOllama(content);
      } else {
        debugPrint('   🟦 Usando $_currentProvider...');
        final response = await _sendMessageUseCase.execute(content);
        botResponse = response.content;
      }
      
      _messages.add(Message.bot(botResponse));
      debugPrint('✅ [ChatProvider] Mensaje procesado exitosamente');
      debugPrint('🟢 [ChatProvider] === ENVÍO EXITOSO ===\n');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error procesando mensaje: $e');
      debugPrint('🔴 [ChatProvider] === ENVÍO FALLIDO ===\n');
      
      String errorMessage = '❌ Error inesperado: ${e.toString()}';
      
      if (_currentProvider == AIProvider.ollama) {
        errorMessage += '\n\n💡 ¿Quieres probar con Gemini? Toca el selector de modelos arriba.';
      }
      
      _messages.add(Message.bot(errorMessage));
    } finally {
      _isProcessing = false;
      _updateQuickResponses();
      notifyListeners();

      await _autoSaveConversation();
    }
  }

  Future<String> _sendToOllama(String content) async {
    try {
      debugPrint('   📤 [ChatProvider] Preparando mensaje para Ollama...');
      debugPrint('   🎯 Modelo: $_currentModel');
      
      debugPrint('   💬 Enviando mensaje normal a Ollama');
      
      final response = await _aiSelector.sendMessage(
        content,
        history: _messages.where((m) => !m.content.contains('¡Bienvenido al chat!')).toList(),
      );
      
      debugPrint('   ✅ Respuesta recibida de Ollama (${response.length} caracteres)');
      return response;
    } catch (e) {
      debugPrint('   ❌ Error con Ollama: $e');
      throw Exception('Error con Ollama: $e');
    }
  }

  List<ChatMessage> _convertHistoryToChatMessages(List<Message> history, String newMessage) {
    final messages = <ChatMessage>[
      ChatMessage(
        role: 'system',
        content: 'Eres un asistente de IA útil y educativo especializado en enseñar sobre inteligencia artificial y prompting. Responde de manera clara, educativa y práctica.',
      ),
    ];

    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;

    for (final msg in recentHistory) {
      if (msg.content.contains('¡Bienvenido al chat!')) continue;
      
      messages.add(ChatMessage(
        role: msg.isUser ? 'user' : 'assistant',
        content: msg.content,
      ));
    }

    return messages;
  }

  void _updateQuickResponses() {
    _quickResponses = QuickResponseProvider.getContextualResponses(_messages);
  }

  Future<void> _autoSaveConversation() async {
    if (_messages.isEmpty) return;
    try {
      await ConversationRepository.saveConversation(_messages);
      if (kDebugMode) {
        debugPrint("💾 [ChatProvider] Conversación guardada automáticamente (${_messages.length} mensajes)");
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error al guardar conversación: $e');
    }
  }

  Future<void> clearMessages({bool saveBeforeClear = true}) async {
    debugPrint('🗑️ [ChatProvider] Limpiando mensajes...');
    
    if (saveBeforeClear && _messages.isNotEmpty) {
      await ConversationRepository.saveConversation(_messages);
    }
    _messages.clear();
    _isNewConversation = true;
    
    _addWelcomeMessage();
    notifyListeners();
    
    debugPrint('   ✅ Mensajes limpiados');
  }

  Future<void> loadConversation(File file) async {
    debugPrint('📂 [ChatProvider] Cargando conversación desde archivo...');
    
    final loadedMessages = await ConversationRepository.loadConversation(file);
    _messages
      ..clear()
      ..addAll(loadedMessages);
    
    _isNewConversation = false;
    
    _updateQuickResponses();
    notifyListeners();
    
    debugPrint('   ✅ Conversación cargada (${_messages.length} mensajes)');
  }

  @override
  void dispose() {
    debugPrint('🔴 [ChatProvider] Disposing...');
    _aiSelector.dispose();
    super.dispose();
  }
}