import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../data/models/message_model.dart';
import '../../data/models/quick_response_model.dart';
import '../../data/models/ollama_models.dart';
import '../../data/models/local_ollama_models.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/ollama_service.dart';
import '../../data/services/openai_service.dart';
import '../../data/services/local_ollama_service.dart';
import '../../data/services/ai_service_selector.dart';
import '../../data/services/preferences_service.dart';
import '../../data/services/ai_service_adapters.dart';
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
  late final OllamaManagedService _localOllamaService;
  
  // Adaptadores
  late final GeminiServiceAdapter _geminiAdapter;
  late OllamaServiceAdapter _ollamaAdapter; // No final porque se recrea
  late final OpenAIServiceAdapter _openaiAdapter;
  late final LocalOllamaServiceAdapter _localOllamaAdapter;
  
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
    _localOllamaService = OllamaManagedService();
    
    // Crear adaptadores
    _geminiAdapter = GeminiServiceAdapter(_geminiService);
    _ollamaAdapter = OllamaServiceAdapter(_ollamaService, _currentModel);
    _openaiAdapter = OpenAIServiceAdapter(_openaiService);
    _localOllamaAdapter = LocalOllamaServiceAdapter(_localOllamaService);
    
    _preferencesService = PreferencesService();
    
    _aiSelector = AIServiceSelector(
      geminiService: _geminiService,
      ollamaService: _ollamaService,
      openaiService: _openaiService,
      localOllamaService: _localOllamaService,
    );
    
    // <--- AÑADIR ESTA LÍNEA ---
    // Suscribirse a los cambios del selector (¡ESTA ES LA CORRECCIÓN!)
    _aiSelector.addListener(_onAiSelectorChanged);
    
    // Inicializar CommandProcessor con Gemini por defecto
    _commandProcessor = CommandProcessor(_geminiAdapter);

    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: _commandProcessor,
    );

    _initializeModels();
    _addWelcomeMessage();
  }

  // <--- AÑADIR ESTE MÉTODO ---
  /// Escucha los cambios de AIServiceSelector y notifica a los listeners de ChatProvider
  void _onAiSelectorChanged() {
    debugPrint('🔄 [ChatProvider] AIServiceSelector notificó cambios, actualizando UI...');
    
    // Sincronizar estado interno si es necesario (ej. modelo remoto)
    if (_currentProvider == AIProvider.ollama &&
        _aiSelector.ollamaAvailable &&
        _currentModel != _aiSelector.currentOllamaModel) {
      _currentModel = _aiSelector.currentOllamaModel;
      _ollamaAdapter.updateModel(_currentModel);
    }
    
    // Notificar a la UI (ModelSelectorBubble) para que se reconstruya
    notifyListeners();
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
      case AIProvider.localOllama:
        currentAdapter = _localOllamaAdapter;
        debugPrint('   🟠 Usando LocalLLMAdapter (Ollama Embebido)');
        break;
    }
    
    // Crear nuevo CommandProcessor
    _commandProcessor = CommandProcessor(currentAdapter);
    
    // Actualizar SendMessageUseCase
    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: _commandProcessor,
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
  LocalOllamaStatus get localOllamaStatus => _aiSelector.localOllamaStatus;
  bool get localOllamaAvailable => _aiSelector.localOllamaAvailable;
  bool get localOllamaLoading => _aiSelector.localOllamaLoading;
  
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
            
          case AIProvider.localOllama:
            canRestore = _aiSelector.localOllamaAvailable;
            if (!canRestore) {
              debugPrint('   ⚠️ Ollama Embebido no disponible, usando Gemini por defecto');
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
          debugPrint('   ✅ Usando proveedor por defecto: Gemini');
        }
      } else {
        debugPrint('   ℹ️ No hay preferencias guardadas, usando Gemini');
      }
      
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error restaurando preferencias: $e');
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
          if (lastModel != null && _aiSelector.availableOpenAIModels.contains(lastModel)) {
            await _aiSelector.setOpenAIModel(lastModel);
            debugPrint('   ✅ Restaurado modelo OpenAI: $lastModel');
          }
          break;
          
        case AIProvider.localOllama:
          // El modelo de Ollama Local se gestiona automáticamente
          debugPrint('   ℹ️ Ollama Local usa modelo gestionado automáticamente');
          break;
          
        case AIProvider.gemini:
          // Gemini solo tiene un modelo
          break;
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error restaurando modelo del proveedor: $e');
    }
  }

  void toggleModelSelector() {
    _showModelSelector = !_showModelSelector;
    debugPrint('🔄 [ChatProvider] Selector de modelos: ${_showModelSelector ? "Mostrado" : "Oculto"}');
    notifyListeners();
  }

  void hideModelSelector() {
    if (_showModelSelector) {
      _showModelSelector = false;
      debugPrint('🔽 [ChatProvider] Selector de modelos oculto');
      notifyListeners();
    }
  }

  Future<void> changeProvider(AIProvider newProvider) async {
    if (_currentProvider == newProvider) {
      debugPrint('   ℹ️ Ya estás usando $newProvider');
      return;
    }

    debugPrint('🔄 [ChatProvider] Cambiando proveedor de $_currentProvider a $newProvider');

    // Validar disponibilidad
    bool isAvailable = false;
    switch (newProvider) {
      case AIProvider.gemini:
        isAvailable = true;
        break;
      case AIProvider.ollama:
        isAvailable = _aiSelector.ollamaAvailable;
        break;
      case AIProvider.openai:
        isAvailable = _aiSelector.openaiAvailable;
        break;
      case AIProvider.localOllama:
        isAvailable = _aiSelector.localOllamaAvailable;
        break;
    }

    if (!isAvailable) {
      debugPrint('   ❌ $newProvider no está disponible');
      throw Exception('$newProvider no está disponible');
    }

    _currentProvider = newProvider;
    await _aiSelector.setProvider(newProvider);
    
    // Actualizar el CommandProcessor
    _updateCommandProcessor();
    
    // Guardar preferencia
    await _preferencesService.saveLastProvider(newProvider);
    
    notifyListeners();
    debugPrint('   ✅ Proveedor cambiado a $newProvider');
  }

  Future<void> changeModel(String modelName) async {
    if (_currentProvider != AIProvider.ollama) {
      debugPrint('   ⚠️ Solo se puede cambiar modelo en Ollama remoto');
      return;
    }

    if (_currentModel == modelName) {
      debugPrint('   ℹ️ Ya estás usando el modelo $modelName');
      return;
    }

    debugPrint('🔄 [ChatProvider] Cambiando modelo Ollama de $_currentModel a $modelName');

    _currentModel = modelName;
    _ollamaAdapter.updateModel(modelName);
    
    // Actualizar el modelo en el selector
    await _aiSelector.setOllamaModel(modelName);
    
    // Guardar preferencia
    await _preferencesService.saveLastOllamaModel(modelName);
    
    notifyListeners();
    debugPrint('   ✅ Modelo Ollama cambiado a $modelName');
  }

  Future<void> changeOpenAIModel(String modelName) async {
    if (_currentProvider != AIProvider.openai) {
      debugPrint('   ⚠️ Solo se puede cambiar modelo en OpenAI');
      return;
    }

    debugPrint('🔄 [ChatProvider] Cambiando modelo OpenAI a $modelName');

    await _aiSelector.setOpenAIModel(modelName);
    
    // Guardar preferencia
    await _preferencesService.saveLastOpenAIModel(modelName);
    
    notifyListeners();
    debugPrint('   ✅ Modelo OpenAI cambiado a $modelName');
  }

  Future<void> changeLocalOllamaModel(String modelName) async {
    if (_currentProvider != AIProvider.localOllama) {
      debugPrint('   ⚠️ Solo se puede cambiar modelo en Ollama Local');
      return;
    }
    
    final currentLocalModel = _aiSelector.localOllamaService.currentModel;
    if (currentLocalModel != null && (currentLocalModel == modelName || currentLocalModel.startsWith('$modelName:'))) {
      debugPrint('   ℹ️ Ya estás usando el modelo $modelName');
      return;
    }

    debugPrint('🔄 [ChatProvider] Cambiando modelo Ollama Local a $modelName');

    try {
      final success = await _aiSelector.changeLocalOllamaModel(modelName);
      
      if (success) {
        // (Opcional) Guardar preferencia
        // await _preferencesService.saveLastLocalOllamaModel(modelName);
        
        debugPrint('   ✅ Modelo Ollama Local cambiado a $modelName');
      } else {
        debugPrint('   ❌ Error cambiando modelo local');
      }
      
      // El listener _onAiSelectorChanged se encargará de notificar a la UI
      
    } catch (e) {
      debugPrint('   ❌ Error cambiando modelo local: $e');
      rethrow;
    }
  }

  Future<void> refreshModels() async {
    debugPrint('🔄 [ChatProvider] Refrescando modelos de Ollama...');
    
    try {
      await _aiSelector.refreshOllama();
      
      if (_aiSelector.ollamaAvailable) {
        _availableModels = _aiSelector.availableModels;
        
        // Si el modelo actual ya no existe, seleccionar el primero disponible
        if (_availableModels.isNotEmpty && 
            !_availableModels.any((m) => m.name == _currentModel)) {
          _currentModel = _availableModels.first.name;
          _ollamaAdapter.updateModel(_currentModel);
        }
        
        debugPrint('   ✅ Modelos actualizados (${_availableModels.length} disponibles)');
      } else {
        debugPrint('   ⚠️ Ollama no está disponible');
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('   ❌ Error refrescando modelos: $e');
      rethrow;
    }
  }

  void _addWelcomeMessage() {
    const welcomeMessage = '''¡Bienvenido al chat! 🤖

Puedes elegir entre diferentes proveedores de IA:

**Proveedores en la nube:**
- **Gemini** - IA de Google (gratis con límites)
- **ChatGPT** - IA de OpenAI (requiere API key)
- **Ollama Remoto** - Servidor Ollama en tu red local

**Proveedor privado:**
- **Ollama Local** - 100% privado en tu PC (sin instalación, embebido)

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
      case AIProvider.localOllama:
        debugPrint('   📝 Modelo Ollama Local: ${_localOllamaService.currentModel}');
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
      
      // TODOS los mensajes (comandos y normales) pasan por SendMessageUseCase
      // SendMessageUseCase decide si es comando (usa IA) o mensaje normal (eco local)
      debugPrint('   🔸 Procesando mensaje a través de SendMessageUseCase...');
      final response = await _sendMessageUseCase.execute(content);
      botResponse = response.content;
      
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
      } else if (_currentProvider == AIProvider.localOllama) {
        errorMessage += '\n\n💡 Ollama Embebido no está disponible.\n'
                 'Puede que esté inicializándose. Espera unos segundos.\n'
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

  // ============================================================================
  // MÉTODOS DEPRECATED - Ya no se usan en v1.0.0
  // ============================================================================
  // Estos métodos se usaban antes para enviar mensajes directamente a Ollama
  // sin pasar por CommandProcessor. Ahora TODOS los mensajes pasan por
  // SendMessageUseCase, que decide si usar IA (comando) o eco local (sin comando).
  // 
  // Se mantienen comentados para:
  // 1. Referencia histórica
  // 2. Posible uso futuro en "Modo Chat Directo" (v1.1.0)
  // ============================================================================
  
  /*
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

  // Enviar a Ollama Embebido con historial
  Future<String> _sendToLocalLLM(String content) async {
    try {
      debugPrint('   📤 [ChatProvider] Preparando mensaje para Ollama Embebido...');
      debugPrint('   🎯 Modelo: ${_localOllamaService.currentModel}');
      
      final response = await _aiSelector.sendMessage(
        content,
        history: _messages.where((m) => !m.content.contains('¡Bienvenido al chat!')).toList(),
      );
      
      debugPrint('   ✅ Respuesta recibida de Ollama Embebido (${response.length} caracteres)');
      return response;
    } catch (e) {
      debugPrint('   ❌ Error con Ollama Embebido: $e');
      throw Exception('Error con Ollama Embebido: $e');
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
  */

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
    _aiSelector.removeListener(_onAiSelectorChanged); // Dejar de escuchar
    
    _aiSelector.dispose();
    super.dispose();
  }
}