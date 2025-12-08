import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../../domain/entities/message_entity.dart';
import '../../domain/entities/quick_response_entity.dart';
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
import '../../domain/repositories/command_repository.dart'; 
import '../../core/constants/commands_help.dart';
import 'command_management_provider.dart';

class ChatProvider extends ChangeNotifier {
  // ============================================================================
  // ESTADO INTERNO: ENTIDADES (Domain Layer)
  // ============================================================================
  final List<MessageEntity> _messages = [];
  List<QuickResponseEntity> _quickResponses =
      QuickResponseProvider.defaultResponsesAsEntities;
  bool _isProcessing = false;
  bool _isStreaming = false;
  bool _isNewConversation = true;
  bool _isRetryingOllama = false;
  // Controla si el usuario puede seleccionar Ollama remoto desde la UI.
  bool _ollamaSelectable = true;
  bool _needsHistoryLoad = false;

  bool _hasUnsavedChanges = false; // Para saber si hay algo que guardar
  File? _currentConversationFile; // Para saber qué archivo sobrescribir/borrar
  bool _isSaving = false;

  late SendMessageUseCase _sendMessageUseCase; // No final - se actualiza al cambiar proveedor
  late final AIServiceSelector _aiSelector;
  late final PreferencesService _preferencesService;

  // INTERFACES DE REPOSITORIO
  final ChatRepository _chatRepository;
  final ConversationRepository _conversationRepository;
  final CommandRepository _commandRepository; 

  bool Function()? _getSyncStatus;
  
  // Referencia al CommandManagementProvider para obtener carpetas y preferencias
  CommandManagementProvider? _commandManagementProvider;

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

  late CommandProcessor _commandProcessor; // No final - se actualiza al cambiar proveedor

  bool _showModelSelector = false;
  List<OllamaModel> _availableModels = [];
  String _currentModel = 'phi3:latest';
  AIProvider _currentProvider = AIProvider.gemini;

  // ==========================================================================
  // Clave para preferencia de agrupar comandos del sistema (fallback)
  // ==========================================================================
  static const String _groupSystemCommandsKey = 'group_system_commands';

  ChatProvider({
    required ChatRepository chatRepository,
    required ConversationRepository conversationRepository,
    required CommandRepository commandRepository, 
    required AIServiceSelector aiServiceSelector,
  })  : _chatRepository = chatRepository,
        _conversationRepository = conversationRepository,
        _commandRepository = commandRepository,
        _aiSelector = aiServiceSelector,
        _geminiService = aiServiceSelector.geminiService,
        _ollamaService = aiServiceSelector.ollamaService,
        _openaiService = aiServiceSelector.openaiService,
        _localOllamaService = aiServiceSelector.localOllamaService {
    
    // Crear adaptadores
    _geminiAdapter = GeminiServiceAdapter(_geminiService);
    _ollamaAdapter = OllamaServiceAdapter(_ollamaService, _currentModel);
    _openaiAdapter = OpenAIServiceAdapter(_openaiService);
    _localOllamaAdapter = LocalOllamaServiceAdapter(_localOllamaService);

    _preferencesService = PreferencesService();

    // Suscribirse a los cambios del selector
    _aiSelector.addListener(_onAiSelectorChanged);

    // Inicializar CommandProcessor con Gemini por defecto
    _commandProcessor = CommandProcessor(_geminiAdapter, _commandRepository);

    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: _commandProcessor,
      chatRepository: _chatRepository,
    );

    _initializeModels();
  }

  /// Vincula el CommandManagementProvider para obtener carpetas y preferencias
  void setCommandManagementProvider(CommandManagementProvider provider) {
    // Si ya había uno vinculado, nos desuscribimos para evitar fugas de memoria
    if (_commandManagementProvider != null) {
      _commandManagementProvider!.removeListener(_onCommandDataChanged);
    }

    _commandManagementProvider = provider;
    
    // 1. SOLUCIÓN PROFESIONAL: Suscripción completa.
    // Escuchamos cualquier cambio (notificación) que emita el proveedor de comandos.
    provider.addListener(_onCommandDataChanged);
    
    // 2. Sincronización inicial inmediata
    // Si el proveedor ya tiene datos cargados, los aplicamos ya mismo.
    if (!provider.isLoading) {
      _onCommandDataChanged();
    }
    
    debugPrint('✅ [ChatProvider] Vinculado reactivamente a CommandManagementProvider');
  }

  /// Esta función se ejecuta AUTOMÁTICAMENTE cada vez que CommandManagementProvider hace notifyListeners()
  void _onCommandDataChanged() {
    // Evitamos actualizaciones innecesarias si el proveedor está cargando (opcional, según preferencia visual)
    // Pero para la carga inicial, queremos que se ejecute al finalizar la carga.
    if (_commandManagementProvider == null) return;

    // Actualizamos las QuickResponses basándonos en el estado ACTUAL del proveedor de comandos
    _updateQuickResponsesFromProvider();
  }

  /// Método síncrono y rápido para reconstruir las respuestas desde el proveedor vinculado
  void _updateQuickResponsesFromProvider() {
    if (_commandManagementProvider == null) return;

    final provider = _commandManagementProvider!;
    
    // Usamos el helper estático para regenerar la lista
    final organizedResponses = QuickResponseProvider.buildOrganizedResponses(
      commands: provider.commands,
      folders: provider.folders,
      groupSystemCommands: provider.groupSystemCommands, // AQUÍ LEEMOS EL VALOR REAL ACTUALIZADO
    );

    _quickResponses = organizedResponses.map((r) => r.toEntity()).toList();
    
    // Notificamos a la UI del Chat para que se repinte
    notifyListeners();
  }

  // Método para manejar las notificaciones del CommandManagementProvider
  void _onCommandProviderUpdated() {
    // Solo actualizamos si no está cargando, para evitar parpadeos innecesarios durante la carga
    // Opcional: puedes quitar el if si quieres ver actualizaciones en tiempo real
    if (_commandManagementProvider != null && !_commandManagementProvider!.isLoading) {
       refreshQuickResponses();
    }
  }

  /// Vincula el estado de sincronización desde AuthProvider
  void setSyncStatusChecker(bool Function() checker) {
    _getSyncStatus = checker;
  }

  /// Escucha los cambios de AIServiceSelector y notifica a los listeners de ChatProvider
  Future<void> _onAiSelectorChanged() async {
    debugPrint('🔄 [ChatProvider] AIServiceSelector notificó cambios, actualizando UI...');

    // 1. Sincronizar la lista de modelos disponibles
    if (_aiSelector.ollamaAvailable) {
      if (!_ollamaSelectable) {
        _ollamaSelectable = true;
        debugPrint('   🔓 Ollama disponible: desbloqueando selección en la UI');
      }
      
      if (!listEquals(_availableModels, _aiSelector.availableModels)) {
        _availableModels = _aiSelector.availableModels;
        debugPrint(
            '   ✅ Lista de modelos Ollama (remoto) actualizada: ${_availableModels.length} modelos');

        if (_availableModels.isNotEmpty) {
          final currentModelExists =
              _availableModels.any((m) => m.name == _currentModel);

          if (!currentModelExists || _currentModel.isEmpty) {
            _currentModel = _availableModels.first.name;
            _ollamaAdapter.updateModel(_currentModel);
            debugPrint(
                '   ⚠️ Modelo actual no encontrado. Seleccionando por defecto: $_currentModel');
          }
        }
      }

      if (_currentProvider == AIProvider.ollama &&
          _currentModel != _aiSelector.currentOllamaModel) {
        _currentModel = _aiSelector.currentOllamaModel;
        _ollamaAdapter.updateModel(_currentModel);
      }
    } else {
      if (_availableModels.isNotEmpty) {
        _availableModels = [];
        debugPrint('   ❌ Ollama (remoto) desconectado. Vaciando lista de modelos.');
      }

      if (_ollamaSelectable) {
        _ollamaSelectable = false;
        debugPrint('   🔒 Bloqueando selección de Ollama en la UI (desconectado)');
      }

      if (_currentProvider == AIProvider.ollama) {
        debugPrint('   ⚠️ ¡Ollama (remoto) era el proveedor activo y se ha desconectado!');
        debugPrint('   🔄 Cambiando automáticamente a Gemini por defecto...');

        await selectProvider(AIProvider.gemini);

        debugPrint('   ✅ [AIServiceSelector change] Cambio a Gemini completado.');
        
        _addOllamaConnectionErrorMessage();
      }
    }
    notifyListeners();
  }

  /// Añade un mensaje de error al chat cuando Ollama (remoto) se desconecta
  void _addOllamaConnectionErrorMessage() {
    final errorMessage = MessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: '❌ El servidor de Ollama (remoto) se ha desconectado.\n\n'
          'Se ha cambiado automáticamente a **Gemini**.\n\n'
          'Por favor, comprueba la conexión del servidor e inténtalo de nuevo más tarde.',
      type: MessageTypeEntity.bot,
      timestamp: DateTime.now(),
    );

    if (_messages.isEmpty ||
        (_messages.last.type != MessageTypeEntity.bot) ||
        (_messages.last.content != errorMessage.content)) {
      _messages.add(errorMessage);
    }
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
        _ollamaAdapter.updateModel(_currentModel);
        currentAdapter = _ollamaAdapter;
        debugPrint(
            '   🟪 Usando OllamaAdapter (remoto) con modelo: $_currentModel');
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

    // Crear nuevo CommandProcessor pasando el Repositorio
    _commandProcessor = CommandProcessor(currentAdapter, _commandRepository);

    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: _commandProcessor,
      chatRepository: _chatRepository,
    );

    debugPrint(
        '🔄 [ChatProvider] CommandProcessor actualizado para: $_currentProvider');
  }

  // ============================================================================
  // GETTERS: EXPONE ENTIDADES A LA UI
  // ============================================================================
  List<MessageEntity> get messages => List.unmodifiable(_messages);
  List<QuickResponseEntity> get quickResponses => _quickResponses;
  bool get isProcessing => _isProcessing;
  bool get isStreaming => _isStreaming;
  bool get showModelSelector => _showModelSelector;
  List<OllamaModel> get availableModels => _availableModels;
  String get currentModel => _currentModel;
  AIProvider get currentProvider => _currentProvider;
  ConnectionInfo get connectionInfo => _aiSelector.connectionInfo;
  bool get ollamaAvailable => _aiSelector.ollamaAvailable && _ollamaSelectable;
  bool get isRetryingOllama => _isRetryingOllama;
    bool get hasUnsavedChanges => _hasUnsavedChanges;

  AIServiceSelector get aiSelector => _aiSelector;
  bool get openaiAvailable => _aiSelector.openaiAvailable;
  String get currentOpenAIModel => _aiSelector.currentOpenAIModel;
  List<String> get availableOpenAIModels => _aiSelector.availableOpenAIModels;

  LocalOllamaStatus get localOllamaStatus => _aiSelector.localOllamaStatus;
  bool get localOllamaAvailable => _aiSelector.localOllamaAvailable;
  bool get localOllamaLoading => _aiSelector.localOllamaLoading;

  Stream<ConnectionInfo> get connectionStream => _aiSelector.connectionStream;

  // ============================================================================
  // MÉTODOS PARA GESTIÓN DE HISTORIAL (para HistoryPage)
  // ============================================================================

  Future<List<FileSystemEntity>> listConversations() {
    return _conversationRepository.listConversations();
  }

  Future<void> _initializeModels() async {
    try {
      debugPrint('🎬 [ChatProvider] Inicializando modelos...');

      if (_aiSelector.ollamaAvailable) {
        _availableModels = _aiSelector.availableModels;
        if (_availableModels.isNotEmpty) {
          _currentModel = _availableModels.first.name;
          _ollamaAdapter.updateModel(_currentModel);
        }
      }

      await _restoreUserPreferences();
      
      // Cargar quick responses iniciales (incluye comandos del usuario)
      await _updateQuickResponses();

      _ollamaSelectable = _aiSelector.ollamaAvailable;

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
              debugPrint(
                  '   ⚠️ Ollama (remoto) no disponible, usando Gemini por defecto');
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
              debugPrint(
                  '   ⚠️ Ollama Embebido no disponible, usando Gemini por defecto');
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
    debugPrint(
        '🔄 [ChatProvider] Toggling model selector: $_showModelSelector -> ${!_showModelSelector}');
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
      _currentModel = _aiSelector.currentOllamaModel;
      notifyListeners();
    }
  }

  Future<void> selectProvider(AIProvider provider) async {
    debugPrint('🔄 [ChatProvider] Cambiando proveedor a: $provider');
    
    if (provider == AIProvider.ollama && !_aiSelector.ollamaAvailable) {
      debugPrint('   ❌ Ollama (remoto) no disponible. No se puede seleccionar por ahora.');
      return;
    }
    
    bool isAvailable = false;
    switch (provider) {
      case AIProvider.gemini:
        isAvailable = true;
        break;
      case AIProvider.ollama:
        isAvailable = true;
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

    if (_needsHistoryLoad && _currentProvider != provider) {
      debugPrint('   📚 Detectado cambio de proveedor con historial pendiente');
      debugPrint('   🔄 Cargando historial en el nuevo proveedor: $provider');
      
      final oldProvider = _currentProvider;
      _currentProvider = provider;
      
      _loadHistoryIntoAIService(_messages);
      _needsHistoryLoad = false;
      
      debugPrint('   ✅ Historial transferido de $oldProvider a $provider');
    }
    
    _currentProvider = provider;
    await _aiSelector.setProvider(provider);
    _updateCommandProcessor();
    
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

  Future<bool> retryOllamaConnection() async {
    debugPrint('🔄 [ChatProvider] Intentando reconectar con Ollama...');
    _isRetryingOllama = true;
    notifyListeners();

    try {
      await _ollamaService.reconnect();
      
      const int maxAttempts = 10;
      const Duration interval = Duration(milliseconds: 300);
      int attempts = 0;
      while (!_aiSelector.ollamaAvailable && attempts < maxAttempts) {
        await Future.delayed(interval);
        attempts++;
      }

      final bool isSuccess = _aiSelector.ollamaAvailable;

      if (isSuccess) {
        _ollamaSelectable = true;
        debugPrint('   🔓 Selección de Ollama desbloqueada (reconectado)');
        debugPrint('   ✅ [ChatProvider] Reconexión exitosa. Seleccionando Ollama.');
        await selectProvider(AIProvider.ollama); 
      } else {
        _ollamaSelectable = false;
        debugPrint('   ❌ [ChatProvider] La reconexión falló.');
        if (_currentProvider != AIProvider.gemini) {
          await selectProvider(AIProvider.gemini);
        }
      }
      return isSuccess;
    } catch (e) {
      debugPrint('   ❌ [ChatProvider] Error durante la reconexión: $e');
      return false;
    } finally {
      _isRetryingOllama = false;
      notifyListeners();
    }
  }
  
  Future<void> refreshConnection() async {
    await retryOllamaConnection();
  }

  Future<LocalOllamaInitResult?> initializeLocalOllama() async {
    debugPrint(
        '🚀 [ChatProvider] Iniciando instalación/configuración de Ollama Embebido...');

    try {
      final result = await _aiSelector.initializeLocalOllama();

      if (result.success) {
        debugPrint('   ✅ Ollama Embebido inicializado correctamente');
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
    final welcomeMessage = CommandsHelp.getWelcomeMessage();

    final welcomeEntity = MessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: welcomeMessage,
      type: MessageTypeEntity.bot,
      timestamp: DateTime.now(),
    );

    _messages.add(welcomeEntity);
    notifyListeners();
  }

  /// Refresca los quick responses, útil cuando se crean/editan comandos de usuario
  /// o cuando cambia la preferencia de agrupar comandos del sistema
  Future<void> refreshQuickResponses() async {
    await _updateQuickResponses();
    notifyListeners();
  }

  /// Envío con streaming (para Gemini)
  Future<void> _sendMessageWithStreaming(String content) async {
    debugPrint('\n🌊 [ChatProvider] === ENVIANDO CON STREAMING ===');
    debugPrint('   💬 Contenido: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    debugPrint('   🤖 Proveedor: $_currentProvider');

    if (_needsHistoryLoad) {
      _loadHistoryIntoAIService(_messages);
      _needsHistoryLoad = false;
    }

    if (_isNewConversation) _isNewConversation = false;
    hideModelSelector();

    // Generar IDs únicos garantizados
    final now = DateTime.now();
    final userMessageId = '${now.millisecondsSinceEpoch}_user';
    final botMessageId = '${now.millisecondsSinceEpoch}_bot';

    // Añadir mensaje del usuario
    final userMessageEntity = MessageEntity(
      id: userMessageId,
      content: content,
      type: MessageTypeEntity.user,
      timestamp: now,
    );
    _messages.add(userMessageEntity);
    notifyListeners();

    // Crear mensaje del bot vacío
    _messages.add(MessageEntity(
      id: botMessageId,
      content: '',
      type: MessageTypeEntity.bot,
      timestamp: now,
    ));

    _isProcessing = true;
    _isStreaming = true;
    notifyListeners();

    final buffer = StringBuffer();

    try {
      final adapter = _aiSelector.getCurrentAdapter();
      
      await for (final chunk in adapter.generateContentStream(content)) {
        buffer.write(chunk);
        
        final index = _messages.indexWhere((m) => m.id == botMessageId);
        if (index != -1) {
          _messages[index] = MessageEntity(
            id: botMessageId,
            content: buffer.toString(),
            type: MessageTypeEntity.bot,
            timestamp: now,
          );
          notifyListeners();
        }
      }

      debugPrint('✅ [ChatProvider] Streaming completado: ${buffer.length} caracteres');

    } catch (e) {
      debugPrint('❌ [ChatProvider] Error en streaming: $e');

      final index = _messages.indexWhere((m) => m.id == botMessageId);
      if (index != -1) {
        _messages[index] = MessageEntity(
          id: botMessageId,
          content: buffer.isNotEmpty 
              ? '${buffer.toString()}\n\n❌ Error: $e'
              : '❌ Error: $e',
          type: MessageTypeEntity.bot,
          timestamp: now,
        );
      }
    } finally {
      _isProcessing = false;
      _isStreaming = false;
      _hasUnsavedChanges = true;
      await _updateQuickResponses();
      notifyListeners();
    }
  }

  /// Envío de comando con streaming
  Future<void> _sendCommandWithStreaming(String content) async {
    debugPrint('\n🌊 [ChatProvider] === ENVIANDO COMANDO CON STREAMING ===');
    debugPrint('   💬 Comando: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    debugPrint('   🤖 Proveedor: $_currentProvider');

    hideModelSelector();

    // Generar IDs únicos
    final now = DateTime.now();
    final userMessageId = '${now.millisecondsSinceEpoch}_user';
    final botMessageId = '${now.millisecondsSinceEpoch}_bot';

    // Añadir mensaje del usuario
    final userMessageEntity = MessageEntity(
      id: userMessageId,
      content: content,
      type: MessageTypeEntity.user,
      timestamp: now,
    );
    _messages.add(userMessageEntity);
    notifyListeners();

    // Procesar comando para obtener el stream
    final commandResult = await _commandProcessor.processMessageStream(content);

    if (!commandResult.isCommand) {
      // No debería pasar, pero por si acaso, usar flujo normal
      debugPrint('   ⚠️ No es comando, redirigiendo a streaming normal');
      return _sendMessageWithStreaming(content);
    }

    // Si hay error de validación (ej: falta contenido)
    if (commandResult.error != null) {
      _messages.add(MessageEntity(
        id: botMessageId,
        content: '⚠️ ${commandResult.error}',
        type: MessageTypeEntity.bot,
        timestamp: now,
      ));
      notifyListeners();
      _hasUnsavedChanges = true;
      return;
    }

    // Crear mensaje del bot vacío
    _messages.add(MessageEntity(
      id: botMessageId,
      content: '',
      type: MessageTypeEntity.bot,
      timestamp: now,
    ));

    _isProcessing = true;
    _isStreaming = true;
    notifyListeners();

    final buffer = StringBuffer();

    try {
      await for (final chunk in commandResult.responseStream!) {
        buffer.write(chunk);
        
        final index = _messages.indexWhere((m) => m.id == botMessageId);
        if (index != -1) {
          _messages[index] = MessageEntity(
            id: botMessageId,
            content: buffer.toString(),
            type: MessageTypeEntity.bot,
            timestamp: now,
          );
          notifyListeners();
        }
      }

      debugPrint('✅ [ChatProvider] Comando streaming completado: ${buffer.length} caracteres');

    } catch (e) {
      debugPrint('❌ [ChatProvider] Error en comando streaming: $e');

      final index = _messages.indexWhere((m) => m.id == botMessageId);
      if (index != -1) {
        _messages[index] = MessageEntity(
          id: botMessageId,
          content: buffer.isNotEmpty 
              ? '${buffer.toString()}\n\n❌ Error: $e'
              : '❌ Error: $e',
          type: MessageTypeEntity.bot,
          timestamp: now,
        );
      }
    } finally {
      _isProcessing = false;
      _isStreaming = false;
      _hasUnsavedChanges = true;
      await _updateQuickResponses();
      notifyListeners();
    }
  }

  Future<void> sendMessage(String content) async {
  if (content.trim().isEmpty || _isProcessing) return;

  final isCommand = content.trim().startsWith('/');
  
  // Usar streaming para proveedores que lo soportan
  final supportsStreaming = _currentProvider == AIProvider.gemini || 
                            _currentProvider == AIProvider.localOllama || 
                            _currentProvider == AIProvider.ollama;
  
  if (supportsStreaming) {
    if (isCommand) {
      return _sendCommandWithStreaming(content);
    } else {
      return _sendMessageWithStreaming(content);
    }
  }

    debugPrint('\n🚀 [ChatProvider] === ENVIANDO MENSAJE ===');
    debugPrint(
        '   💬 Contenido: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    debugPrint('   🤖 Proveedor actual: $_currentProvider');

    if (_needsHistoryLoad) {
      debugPrint('   📚 Cargando historial en el proveedor actual antes de enviar...');
      _loadHistoryIntoAIService(_messages);
      _needsHistoryLoad = false;
    }

    // Logs simplificados
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
      debugPrint('   🔸 Procesando mensaje a través de SendMessageUseCase...');
      // SendMessageUseCase usará el CommandProcessor que ya tiene el repositorio inyectado
      final botResponseEntity = await _sendMessageUseCase.execute(content);

      _messages.add(botResponseEntity);
      debugPrint('✅ [ChatProvider] Mensaje procesado exitosamente');
      debugPrint('🟢 [ChatProvider] === ENVÍO EXITOSO ===\n');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error procesando mensaje: $e');
      debugPrint('🔴 [ChatProvider] === ENVÍO FALLIDO ===\n');

      String errorMessage = '❌ Error: ${e.toString()}';

      if (_currentProvider == AIProvider.ollama) {
        errorMessage += '\n\n💡 El servidor Ollama remoto no está disponible.\n'
                       'Cambiando automáticamente a Gemini...';
        
        final errorEntity = MessageEntity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: errorMessage,
          type: MessageTypeEntity.bot,
          timestamp: DateTime.now(),
        );
        _messages.add(errorEntity);

        _currentProvider = AIProvider.gemini;
        _ollamaSelectable = false;
        _updateCommandProcessor();
        await _preferencesService.saveLastProvider(AIProvider.gemini);
        debugPrint('   ✅ [sendMessage catch] CAMBIO AUTOMÁTICO a Gemini exitoso');
        
      } else if (_currentProvider == AIProvider.localOllama) {
        errorMessage += '\n\n💡 Ollama Embebido no está disponible.\n'
            'Puede que esté inicializándose. Espera unos segundos.\n'
            'O prueba con otro proveedor.';
        final errorEntity = MessageEntity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: errorMessage,
          type: MessageTypeEntity.bot,
          timestamp: DateTime.now(),
        );
        _messages.add(errorEntity);
      } else if (_currentProvider == AIProvider.openai) {
        errorMessage += '\n\n💡 Verifica tu API Key de OpenAI en .env';
        final errorEntity = MessageEntity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: errorMessage,
          type: MessageTypeEntity.bot,
          timestamp: DateTime.now(),
        );
        _messages.add(errorEntity);
      } else {
        final errorEntity = MessageEntity(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: errorMessage,
          type: MessageTypeEntity.bot,
          timestamp: DateTime.now(),
        );
        _messages.add(errorEntity);
      }
    } finally {
      _isProcessing = false;
      await _updateQuickResponses();
      notifyListeners();

      _hasUnsavedChanges = true;
      debugPrint('📝 [ChatProvider] Cambios pendientes marcados. Se guardarán al salir.');
       notifyListeners();
    }
  }

  // ============================================================================
  // _updateQuickResponses con soporte para carpetas y CommandManagementProvider
  // ============================================================================
  Future<void> _updateQuickResponses() async {
    try {
      // Si tenemos CommandManagementProvider, usarlo para obtener datos actualizados
      if (_commandManagementProvider != null) {
      _updateQuickResponsesFromProvider();
      return;
    }
      
      // Fallback: obtener datos directamente del repositorio
      final allCommands = await _commandRepository.getAllCommands();
      final allFolders = await _commandRepository.getAllFolders();
      
      // Obtener preferencia de agrupar comandos del sistema
      final prefs = await SharedPreferences.getInstance();
      final groupSystemCommands = prefs.getBool(_groupSystemCommandsKey) ?? false;
      
      // Usar el método estático para generar respuestas organizadas
      final organizedResponses = QuickResponseProvider.buildOrganizedResponses(
        commands: allCommands,
        folders: allFolders,
        groupSystemCommands: groupSystemCommands,
      );
      
      _quickResponses = organizedResponses.map((r) => r.toEntity()).toList();
      
      debugPrint('📦 [ChatProvider] Quick responses actualizadas (fallback): ${_quickResponses.length} items');
      
    } catch (e) {
      debugPrint('⚠️ [ChatProvider] Error cargando quick responses: $e');
      _quickResponses = QuickResponseProvider.defaultResponsesAsEntities;
    }
  }

  Future<void> _autoSaveConversation() async {
    if (_messages.isEmpty) return;
    try {
      await _conversationRepository.saveConversation(_messages);
      final isSyncEnabled = _getSyncStatus?.call() ?? false;
      if (kDebugMode) {
        debugPrint(
            "💾 [ChatProvider] Conversación guardada automáticamente (${_messages.length} mensajes)");
        if (isSyncEnabled) {
          debugPrint("☁️ [ChatProvider] Conversación sincronizada con la nube");
        }
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error al guardar conversación: $e');
    }
  }

  Future<void> clearMessages() async {
    debugPrint('🗑️ [ChatProvider] Limpiando mensajes...');
    
    _messages.clear();
    _isNewConversation = true;
    _needsHistoryLoad = false;
    
    _currentConversationFile = null;
    _hasUnsavedChanges = false;

    _clearAIServiceHistory();
    _addWelcomeMessage();
    notifyListeners();
  }

  void _clearAIServiceHistory() {
    debugPrint('🧹 [ChatProvider] Limpiando historial de servicios de IA...');
    try { _geminiService.clearConversation(); } catch (e) { debugPrint('   ⚠️ Error limpiando Gemini: $e'); }
    try { _openaiService.clearConversation(); } catch (e) { debugPrint('   ⚠️ Error limpiando OpenAI: $e'); }
    try { _ollamaService.clearConversation(); } catch (e) { debugPrint('   ⚠️ Error limpiando Ollama: $e'); }
    try { _localOllamaService.clearConversation(); } catch (e) { debugPrint('   ⚠️ Error limpiando Ollama Local: $e'); }
  }

  Future<void> loadConversation(File file) async {
    if (_currentConversationFile != null && 
        _currentConversationFile!.path == file.path && 
        _hasUnsavedChanges) {
      debugPrint('🛑 [ChatProvider] Bloqueada recarga accidental: Ya tienes esta conversación abierta con cambios.');
      return;
    }

    debugPrint('📂 [ChatProvider] Cargando conversación desde archivo...');

    try {
      final loadedMessages = await _conversationRepository.loadConversation(file);
      _messages
        ..clear()
        ..addAll(loadedMessages);

      _isNewConversation = false;
      _needsHistoryLoad = true;
      
      _currentConversationFile = file;
      _hasUnsavedChanges = false;

      await _updateQuickResponses();
      notifyListeners();

      debugPrint('   ✅ Conversación cargada (${_messages.length} mensajes)');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cargando conversación: $e');
    }
  }

  @override
  void dispose() {
    debugPrint('🔴 [ChatProvider] Disposing...');
    _commandManagementProvider?.removeListener(_onCommandDataChanged);
    
    _aiSelector.removeListener(_onAiSelectorChanged);
    _aiSelector.dispose();
    super.dispose();
  }

  void _loadHistoryIntoAIService(List<MessageEntity> messages) {
    debugPrint('📚 [ChatProvider] Cargando historial en servicio de IA...');
    debugPrint('   🎯 Proveedor actual: $_currentProvider');
    
    switch (_currentProvider) {
      case AIProvider.gemini:
        _loadGeminiHistory(messages);
        break;
      case AIProvider.openai:
        _loadOpenAIHistory(messages);
        break;
      case AIProvider.ollama:
        _loadOllamaHistory(messages);
        break;
      case AIProvider.localOllama:
        _loadLocalOllamaHistory(messages);
        break;
    }
  }

  void _loadGeminiHistory(List<MessageEntity> messages) {
    try {
      _geminiService.clearConversation();
      for (final message in messages) {
        if (message.type == MessageTypeEntity.user) {
          _geminiService.addUserMessage(message.content);
        } else if (message.type == MessageTypeEntity.bot) {
          _geminiService.addBotMessage(message.content);
        }
      }
      debugPrint('   ✅ Historial de Gemini cargado: ${messages.length} mensajes');
    } catch (e) {
      debugPrint('   ⚠️ Error cargando historial en Gemini: $e');
    }
  }

  void _loadOpenAIHistory(List<MessageEntity> messages) {
    try {
      _openaiService.clearConversation();
      for (final message in messages) {
        if (message.type == MessageTypeEntity.user) {
          _openaiService.addUserMessage(message.content);
        } else if (message.type == MessageTypeEntity.bot) {
          _openaiService.addBotMessage(message.content);
        }
      }
      debugPrint('   ✅ Historial de OpenAI cargado: ${messages.length} mensajes');
    } catch (e) {
      debugPrint('   ⚠️ Error cargando historial en OpenAI: $e');
    }
  }

  void _loadOllamaHistory(List<MessageEntity> messages) {
    try {
      _ollamaService.clearConversation();
      for (final message in messages) {
        if (message.type == MessageTypeEntity.user) {
          _ollamaService.addUserMessage(message.content);
        } else if (message.type == MessageTypeEntity.bot) {
          _ollamaService.addBotMessage(message.content);
        }
      }
      debugPrint('   ✅ Historial de Ollama cargado: ${messages.length} mensajes');
    } catch (e) {
      debugPrint('   ⚠️ Error cargando historial en Ollama: $e');
    }
  }

  void _loadLocalOllamaHistory(List<MessageEntity> messages) {
    try {
      _localOllamaService.clearConversation();
      for (final message in messages) {
        if (message.type == MessageTypeEntity.user) {
          _localOllamaService.addUserMessage(message.content);
        } else if (message.type == MessageTypeEntity.bot) {
          _localOllamaService.addBotMessage(message.content);
        }
      }
      debugPrint('   ✅ Historial de Ollama Local cargado: ${messages.length} mensajes');
    } catch (e) {
      debugPrint('   ⚠️ Error cargando historial en Ollama Local: $e');
    }
  }

  Future<DeleteResult> deleteAllConversations() async {
    try {
      final isSyncEnabled = _getSyncStatus?.call() ?? false;
      await _conversationRepository.deleteAllConversations();
      return DeleteResult(
        success: true,
        syncWasEnabled: isSyncEnabled,
        message: isSyncEnabled 
            ? 'Todas las conversaciones eliminadas (local y nube)'
            : 'Conversaciones eliminadas localmente. Si sincronizaste previamente, permanecen en la nube.',
      );
    } catch (e) {
      return DeleteResult(
        success: false,
        syncWasEnabled: false,
        message: 'Error eliminando conversaciones: $e',
      );
    }
  }

  Future<DeleteResult> deleteConversations(List<File> files) async {
    try {
      final isSyncEnabled = _getSyncStatus?.call() ?? false;
      await _conversationRepository.deleteConversations(files);
      final count = files.length;
      return DeleteResult(
        success: true,
        syncWasEnabled: isSyncEnabled,
        message: isSyncEnabled 
            ? '$count conversación(es) eliminada(s) (local y nube)'
            : '$count conversación(es) eliminada(s) localmente. Si sincronizaste previamente, permanecen en la nube.',
      );
    } catch (e) {
      return DeleteResult(
        success: false,
        syncWasEnabled: false,
        message: 'Error eliminando conversaciones: $e',
      );
    }
  }

  Future<void> endSession() async {
    if (_isSaving) return; 
    
    if (_messages.isEmpty) return;
    if (_messages.length == 1 && _messages.first.type == MessageTypeEntity.bot) return;
    if (!_hasUnsavedChanges) return;

    _isSaving = true;
    debugPrint('💾 [ChatProvider] Guardando sesión (Actualización)...');

    try {
      await _conversationRepository.saveConversation(
        _messages, 
        existingFile: _currentConversationFile
      );
      
      debugPrint('   ✅ Conversación guardada/actualizada correctamente.');

    } catch (e) {
      debugPrint('❌ [ChatProvider] Error al guardar sesión: $e');
    } finally {
      _hasUnsavedChanges = false;
      _isSaving = false;
    }
  }
}

/// Resultado de una operación de eliminación
class DeleteResult {
  final bool success;
  final bool syncWasEnabled;
  final String message;

  DeleteResult({
    required this.success,
    required this.syncWasEnabled,
    required this.message,
  });
}