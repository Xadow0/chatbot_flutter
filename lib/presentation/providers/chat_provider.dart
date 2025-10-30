import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/quick_response_entity.dart';
import '../../data/models/message_model.dart';
import '../../data/models/quick_response_model.dart';
import '../../data/models/remote_ollama_models.dart';
import '../../data/models/local_ollama_models.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/ollama_service.dart';
import '../../data/services/openai_service.dart';
import '../../data/services/local_ollama_service.dart';
import '../../data/services/ai_service_selector.dart';
import '../../data/services/preferences_service.dart';
import '../../data/services/ai_service_adapters.dart';
import '../../domain/usecases/command_processor.dart';
import '../../domain/usecases/send_message_usecase.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/repositories/conversation_repository.dart';

/// Provider principal del chat
/// 
/// IMPORTANTE: Este provider trabaja INTERNAMENTE con ENTIDADES (domain layer).
/// Solo convierte a modelos cuando necesita interactuar con servicios de persistencia.
class ChatProvider extends ChangeNotifier {
  // ============================================================================
  // ESTADO INTERNO: ENTIDADES (Domain Layer)
  // ============================================================================
  final List<MessageEntity> _messages = [];
  List<QuickResponseEntity> _quickResponses = QuickResponseProvider.defaultResponsesAsEntities;
  bool _isProcessing = false;
  bool _isNewConversation = true;

  late SendMessageUseCase _sendMessageUseCase; // No final - se actualiza al cambiar proveedor
  late final AIServiceSelector _aiSelector;
  late final PreferencesService _preferencesService;

  // INTERFACES DE REPOSITORIO
  final ChatRepository _chatRepository;
  final ConversationRepository _conversationRepository;
  
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

  ChatProvider( {
    required ChatRepository chatRepository,
    required ConversationRepository conversationRepository,
  })  : _chatRepository = chatRepository,
        _conversationRepository = conversationRepository {

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
    
    // Suscribirse a los cambios del selector
    _aiSelector.addListener(_onAiSelectorChanged);
    
    // Inicializar CommandProcessor con Gemini por defecto
    _commandProcessor = CommandProcessor(_geminiAdapter);

    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: _commandProcessor,
      chatRepository: _chatRepository, // <- Inyectar aquí
    );

    // Inicializar modelos y agregar mensaje de bienvenida
    _initializeModels().then((_) => _addWelcomeMessage());
  }

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
    
    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: _commandProcessor,
      chatRepository: _chatRepository, 
    );
    
    debugPrint('🔄 [ChatProvider] CommandProcessor actualizado para: $_currentProvider');
  }

  // ============================================================================
  // GETTERS: EXPONE ENTIDADES A LA UI
  // ============================================================================
  List<MessageEntity> get messages => List.unmodifiable(_messages);
  List<QuickResponseEntity> get quickResponses => _quickResponses;
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

  // ============================================================================
  // MÉTODOS PARA GESTIÓN DE HISTORIAL (para HistoryPage)
  // ============================================================================
  
  /// Expone el método listConversations del repositorio a la UI
  Future<List<FileSystemEntity>> listConversations() {
    return _conversationRepository.listConversations();
  }

  /// Expone el método deleteAllConversations del repositorio a la UI
  Future<void> deleteAllConversations() async {
    await _conversationRepository.deleteAllConversations();
    notifyListeners(); // Notificar si la UI debe reaccionar
  }

  Future<void> deleteConversations(List<File> files) async {
    await _conversationRepository.deleteConversations(files);
    notifyListeners();
  }

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
          _updateCommandProcessor();
          debugPrint('   ✅ Proveedor restaurado: $lastProvider');
        }
      }
    } catch (e) {
      debugPrint('   ❌ Error restaurando preferencias: $e');
    }
  }

  void toggleModelSelector() {
    debugPrint('🔄 [ChatProvider] Toggling model selector: $_showModelSelector -> ${!_showModelSelector}');
    _showModelSelector = !_showModelSelector;
    notifyListeners();
  }

  void hideModelSelector() {
    if (_showModelSelector) {
      debugPrint('🔄 [ChatProvider] Hiding model selector');
      _showModelSelector = false;
      notifyListeners();
    }
  }

  Future<void> selectModel(String modelName) async {
    debugPrint('🔄 [ChatProvider] Cambiando modelo a: $modelName');
    
    try {
      _currentModel = modelName;
      _aiSelector.setOllamaModel(modelName);
      _ollamaAdapter.updateModel(modelName);
      hideModelSelector();
      notifyListeners();
      debugPrint('   ✅ Modelo cambiado a: $modelName');
    } catch (e) {
      debugPrint('   ❌ Error al cambiar modelo: $e');
      // Revertir el cambio local
      _currentModel = _aiSelector.currentOllamaModel;
      notifyListeners();
    }
  }

  Future<void> selectProvider(AIProvider provider) async {
    debugPrint('🔄 [ChatProvider] Cambiando proveedor a: $provider');
    
    // Verificar disponibilidad del proveedor
    bool isAvailable = false;
    switch (provider) {
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
      debugPrint('   ❌ Proveedor $provider no disponible');
      return;
    }
    
    _currentProvider = provider;
    _aiSelector.setProvider(provider);
    _updateCommandProcessor();
    
    // Guardar preferencia
    await _preferencesService.saveLastProvider(provider);
    
    hideModelSelector();
    notifyListeners();
    
    debugPrint('   ✅ Proveedor cambiado a: $provider');
  }

  Future<void> selectOpenAIModel(String modelId) async {
    debugPrint('🔄 [ChatProvider] Cambiando modelo OpenAI a: $modelId');
    
    try {
      await _aiSelector.setOpenAIModel(modelId);
      debugPrint('   ✅ Modelo OpenAI cambiado a: $modelId');
    } catch (e) {
      debugPrint('   ❌ Error al cambiar modelo OpenAI: $e');
    }
    
    notifyListeners();
  }

  Future<void> refreshConnection() async {
    debugPrint('🔄 [ChatProvider] Refrescando conexión...');
    // El método checkConnections se maneja internamente en AIServiceSelector
    // a través de sus eventos y notificaciones
    
    if (_aiSelector.ollamaAvailable) {
      _availableModels = _aiSelector.availableModels;
      if (_availableModels.isNotEmpty && _currentModel.isEmpty) {
        _currentModel = _availableModels.first.name;
        _ollamaAdapter.updateModel(_currentModel);
      }
    }
    
    notifyListeners();
    debugPrint('   ✅ Conexión refrescada');
  }

  Future<LocalOllamaInitResult?> initializeLocalOllama() async {
    debugPrint('🚀 [ChatProvider] Iniciando instalación/configuración de Ollama Embebido...');
    
    try {
      final result = await _aiSelector.initializeLocalOllama();
      
      if (result.success) {
        debugPrint('   ✅ Ollama Embebido inicializado correctamente');
        
        // Auto-cambiar a Local Ollama si tuvo éxito
        if (_aiSelector.localOllamaAvailable) {
          await selectProvider(AIProvider.localOllama);
        }
        
        notifyListeners();
      } else {
        debugPrint('   ❌ Error en inicialización: ${result.error}');
      }
      
      return result;
    } catch (e) {
      debugPrint('   ❌ Excepción durante inicialización: $e');
      return null;
    }
  }

  void _addWelcomeMessage() {
    const welcomeMessage = '''¡Bienvenido al chat! 🎉

Soy tu asistente de aprendizaje de IA y Prompting.

**Proveedores disponibles:**
- **Gemini** - IA de Google (rápida y potente)
- **OpenAI** - ChatGPT (el más conocido)
- **Ollama (Remoto)** - Tu propio servidor de IA

**Proveedor privado:**
- **Ollama Local** - 100% privado en tu PC (sin instalación, embebido)

¡Empieza escribiendo tu mensaje!''';

    final welcomeEntity = MessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: welcomeMessage,
      type: MessageTypeEntity.bot,
      timestamp: DateTime.now(),
    );

    _messages.add(welcomeEntity);
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

    // Crear entidad de mensaje del usuario
    final userMessageEntity = MessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: MessageTypeEntity.user,
      timestamp: DateTime.now(),
    );

    _messages.add(userMessageEntity);
    _isProcessing = true;
    notifyListeners();

    try {
      // SendMessageUseCase trabaja con entidades y retorna una entidad
      debugPrint('   🔸 Procesando mensaje a través de SendMessageUseCase...');
      final botResponseEntity = await _sendMessageUseCase.execute(content);
      
      _messages.add(botResponseEntity);
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
      
      final errorEntity = MessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: errorMessage,
        type: MessageTypeEntity.bot,
        timestamp: DateTime.now(),
      );

      _messages.add(errorEntity);
    } finally {
      _isProcessing = false;
      _updateQuickResponses();
      notifyListeners();

      await _autoSaveConversation();
    }
  }

  void _updateQuickResponses() {
    // Convertir entidades a modelos solo para obtener respuestas contextuales
    final messageModels = _messages.map((entity) => Message.fromEntity(entity)).toList();
    _quickResponses = QuickResponseProvider.getContextualResponsesAsEntities(messageModels);
  }

  Future<void> _autoSaveConversation() async {
    if (_messages.isEmpty) return;
    try {
      // ConversationRepository trabaja con entidades
      await _conversationRepository.saveConversation(_messages);
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
      await _conversationRepository.saveConversation(_messages);
    }
    _messages.clear();
    _isNewConversation = true;
    
    _addWelcomeMessage();
    notifyListeners();
    
    debugPrint('   ✅ Mensajes limpiados');
  }

  Future<void> loadConversation(File file) async {
    debugPrint('📂 [ChatProvider] Cargando conversación desde archivo...');
    
    // ConversationRepository retorna entidades
    final loadedMessages = await _conversationRepository.loadConversation(file);
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
    _aiSelector.removeListener(_onAiSelectorChanged);
    
    _aiSelector.dispose();
    super.dispose();
  }
}