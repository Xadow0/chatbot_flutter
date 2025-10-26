import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../data/models/message_model.dart';
import '../../data/models/quick_response_model.dart';
import '../../data/models/ollama_models.dart';
import '../../data/models/ollama_local_models.dart'; // CAMBIADO: nuevo import para Ollama Local
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
        debugPrint('   🟪 Usando OllamaAdapter (remoto) con modelo: $_currentModel');
        break;
      case AIProvider.openai:
        currentAdapter = _openaiAdapter;
        debugPrint('   🟢 Usando OpenAIAdapter');
        break;
      case AIProvider.localLLM:
        currentAdapter = _localLLMAdapter;
        debugPrint('   🟠 Usando LocalLLMAdapter (Ollama Local)');
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
  
  // Getters para Ollama Local
  OllamaLocalStatus get localLLMStatus => _aiSelector.localLLMStatus; // CAMBIADO: tipo actualizado
  bool get localLLMAvailable => _aiSelector.localLLMAvailable;
  bool get localLLMLoading => _aiSelector.localLLMLoading;
  String? get localLLMError => _aiSelector.localLLMError;
  LocalLLMService get localLLMService => _aiSelector.localLLMService; // NUEVO: acceso al servicio
  
  Stream<ConnectionInfo> get connectionStream => _aiSelector.connectionStream;

  Future<void> _initializeModels() async {
    try {
      debugPrint('🎬 [ChatProvider] Inicializando modelos...');
      
      // Los modelos de Ollama ya se inicializan automáticamente en AIServiceSelector
      // Solo necesitamos obtenerlos
      if (_aiSelector.ollamaAvailable) {
        _availableModels = _aiSelector.availableModels;
        if (_availableModels.isNotEmpty) {
          _currentModel = _availableModels.first.name;
          _ollamaAdapter.updateModel(_currentModel);
        }
      }
      
      // Restaurar preferencias del usuario
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
              debugPrint('   ⚠️ Ollama (remoto) no disponible, usando Gemini por defecto');
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
              debugPrint('   ⚠️ Ollama Local no disponible, usando Gemini por defecto');
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
            _ollamaAdapter.updateModel(_currentModel);
            debugPrint('   ✅ Restaurado modelo Ollama: $lastModel');
          }
          break;
          
        case AIProvider.openai:
          final lastModel = await _preferencesService.getLastOpenAIModel();
          if (lastModel != null) {
            _aiSelector.setOpenAIModel(lastModel);
            debugPrint('   ✅ Restaurado modelo OpenAI: $lastModel');
          }
          break;
          
        case AIProvider.localLLM:
          // Ollama Local no necesita restaurar modelo específico
          // El servicio usa el modelo que esté configurado en Ollama
          debugPrint('   ℹ️ Ollama Local usará el modelo disponible');
          break;
          
        case AIProvider.gemini:
          // Gemini no tiene selección de modelo
          break;
      }
    } catch (e) {
      debugPrint('⚠️ [ChatProvider] Error restaurando modelo: $e');
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

  Future<void> changeProvider(AIProvider newProvider) async {
    debugPrint('🔄 [ChatProvider] Cambiando proveedor a: $newProvider');
    
    try {
      await _aiSelector.setProvider(newProvider);
      _currentProvider = newProvider;
      _updateCommandProcessor();
      
      await _preferencesService.saveLastProvider(newProvider);
      
      notifyListeners();
      debugPrint('✅ [ChatProvider] Proveedor cambiado exitosamente');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando proveedor: $e');
      rethrow;
    }
  }

  Future<void> changeModel(String modelName) async {
    debugPrint('🔄 [ChatProvider] Cambiando modelo Ollama a: $modelName');
    
    try {
      await _aiSelector.setOllamaModel(modelName);
      _currentModel = modelName;
      _ollamaAdapter.updateModel(modelName);
      _updateCommandProcessor();
      
      await _preferencesService.saveLastOllamaModel(modelName);
      
      notifyListeners();
      debugPrint('✅ [ChatProvider] Modelo cambiado exitosamente');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando modelo: $e');
      rethrow;
    }
  }

  Future<void> changeOpenAIModel(String modelName) async {
    debugPrint('🔄 [ChatProvider] Cambiando modelo OpenAI a: $modelName');
    
    try {
      _aiSelector.setOpenAIModel(modelName);
      
      await _preferencesService.saveLastOpenAIModel(modelName);
      
      notifyListeners();
      debugPrint('✅ [ChatProvider] Modelo OpenAI cambiado exitosamente');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando modelo OpenAI: $e');
      rethrow;
    }
  }

  Future<void> refreshModels() async {
    debugPrint('🔄 [ChatProvider] Refrescando modelos...');
    
    try {
      // Refrescar Ollama usando el método público
      await _aiSelector.refreshOllama();
      
      if (_aiSelector.ollamaAvailable) {
        _availableModels = _aiSelector.availableModels;
        
        // Si el modelo actual ya no está disponible, cambiar al primero
        if (_availableModels.isNotEmpty && 
            !_availableModels.any((m) => m.name == _currentModel)) {
          _currentModel = _availableModels.first.name;
          _ollamaAdapter.updateModel(_currentModel);
          
          if (_currentProvider == AIProvider.ollama) {
            _updateCommandProcessor();
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

  // MODIFICADO: Métodos para Ollama Local con nuevo tipo de retorno
  Future<OllamaLocalInitResult> initializeLocalLLM() async {
    debugPrint('🚀 [ChatProvider] Iniciando Ollama Local...');
    try {
      final result = await _aiSelector.initializeLocalLLM();
      notifyListeners();
      
      if (result.success) {
        debugPrint('✅ [ChatProvider] Ollama Local inicializado correctamente');
        debugPrint('   📦 Modelo: ${result.modelName}');
        debugPrint('   📋 Modelos disponibles: ${result.availableModels?.join(", ")}');
      } else {
        debugPrint('❌ [ChatProvider] Error inicializando Ollama Local: ${result.error}');
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Excepción al inicializar Ollama Local: $e');
      notifyListeners();
      return OllamaLocalInitResult(
        success: false,
        error: 'Error inesperado: $e',
      );
    }
  }

  Future<void> stopLocalLLM() async {
    debugPrint('🛑 [ChatProvider] Deteniendo Ollama Local...');
    try {
      await _aiSelector.stopLocalLLM();
      notifyListeners();
      debugPrint('✅ [ChatProvider] Ollama Local detenido correctamente');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error deteniendo Ollama Local: $e');
      notifyListeners();
    }
  }

  Future<OllamaLocalInitResult> retryLocalLLM() async {
    debugPrint('🔄 [ChatProvider] Reintentando inicialización de Ollama Local...');
    return await initializeLocalLLM();
  }

  void _addWelcomeMessage() {
    final welcomeMessage = '''
¡Bienvenido al chat! 👋

Aquí puedes conversar conmigo y utilizar los siguientes comandos:

**Comandos disponibles:**

- **/tryprompt** [escribe aquí tu prompt] -- Este comando te permite ejecutar un análisis y mejora de tu prompt, generando como resultado un prompt mejorado en caso de que sea posible.

💡 **Nuevo:** Los comandos ahora usan la IA que tengas seleccionada. Cambia entre:
• **Gemini** - Rápido y gratis
• **ChatGPT** - Alta calidad (requiere API Key)
• **Ollama Remoto** - Servidor Ubuntu con Phi3/Mistral
• **Ollama Local** - 100% privado en tu PC

¡Empieza escribiendo tu mensaje!''';

    _messages.add(Message.bot(welcomeMessage));
    notifyListeners();
  }

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isProcessing) return;

    debugPrint('\n🚀 [ChatProvider] === ENVIANDO MENSAJE ===');
    debugPrint('   💬 Contenido: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    debugPrint('   🤖 Proveedor actual: $_currentProvider');
    
    // Log del modelo según el proveedor
    switch (_currentProvider) {
      case AIProvider.ollama:
        debugPrint('   📝 Modelo Ollama (remoto): $_currentModel');
        break;
      case AIProvider.localLLM:
        debugPrint('   📝 Modelo Ollama Local: ${_localLLMService.currentModel}');
        break;
      case AIProvider.openai:
        debugPrint('   📝 Modelo OpenAI: ${_aiSelector.currentOpenAIModel}');
        break;
      case AIProvider.gemini:
        debugPrint('   📝 Modelo: gemini-2.5-flash');
        break;
    }

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
      
      // Los comandos se procesan según el proveedor actual
      if (content.startsWith('/')) {
        debugPrint('   🔸 Detectado comando, procesando con $_currentProvider');
        final response = await _sendMessageUseCase.execute(content);
        botResponse = response.content;
      } 
      // Caso especial: Ollama remoto con historial
      else if (_currentProvider == AIProvider.ollama && _aiSelector.ollamaAvailable) {
        debugPrint('   🟪 Usando Ollama (servidor remoto)...');
        botResponse = await _sendToOllama(content);
      }
      // Caso especial: Ollama Local con historial
      else if (_currentProvider == AIProvider.localLLM && _aiSelector.localLLMAvailable) {
        debugPrint('   🟠 Usando Ollama Local...');
        botResponse = await _sendToLocalLLM(content);
      }
      // Resto de proveedores (Gemini, OpenAI)
      else {
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
      
      String errorMessage = '❌ Error: ${e.toString()}';
      
      // Mensajes de ayuda contextuales según el proveedor
      if (_currentProvider == AIProvider.ollama) {
        errorMessage += '\n\n💡 El servidor Ollama remoto no está disponible.\n'
                       '¿Quieres probar con otro proveedor? Toca el selector arriba.';
      } else if (_currentProvider == AIProvider.localLLM) {
        errorMessage += '\n\n💡 Ollama Local no está disponible.\n'
                       'Verifica que Ollama esté ejecutándose: ollama serve\n'
                       'O prueba con otro proveedor.';
      } else if (_currentProvider == AIProvider.openai) {
        errorMessage += '\n\n💡 Verifica tu API Key de OpenAI en .env';
      }
      
      _messages.add(Message.bot(errorMessage));
    } finally {
      _isProcessing = false;
      _updateQuickResponses();
      notifyListeners();

      await _autoSaveConversation();
    }
  }

  // Enviar a Ollama (servidor remoto) con historial
  Future<String> _sendToOllama(String content) async {
    try {
      debugPrint('   📤 [ChatProvider] Preparando mensaje para Ollama (remoto)...');
      debugPrint('   🎯 Modelo: $_currentModel');
      
      final response = await _aiSelector.sendMessage(
        content,
        history: _messages.where((m) => !m.content.contains('¡Bienvenido al chat!')).toList(),
      );
      
      debugPrint('   ✅ Respuesta recibida de Ollama (${response.length} caracteres)');
      return response;
    } catch (e) {
      debugPrint('   ❌ Error con Ollama: $e');
      throw Exception('Error con Ollama remoto: $e');
    }
  }

  // NUEVO: Enviar a Ollama Local con historial
  Future<String> _sendToLocalLLM(String content) async {
    try {
      debugPrint('   📤 [ChatProvider] Preparando mensaje para Ollama Local...');
      debugPrint('   🎯 Modelo: ${_localLLMService.currentModel}');
      
      final response = await _aiSelector.sendMessage(
        content,
        history: _messages.where((m) => !m.content.contains('¡Bienvenido al chat!')).toList(),
      );
      
      debugPrint('   ✅ Respuesta recibida de Ollama Local (${response.length} caracteres)');
      return response;
    } catch (e) {
      debugPrint('   ❌ Error con Ollama Local: $e');
      throw Exception('Error con Ollama Local: $e');
    }
  }

  // Helper para convertir historial (usado por Ollama remoto)
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