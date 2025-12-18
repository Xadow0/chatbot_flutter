import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'dart:async';
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
import '../../domain/repositories/iconversation_repository.dart';
import '../../domain/repositories/icommand_repository.dart';
import '../../core/constants/commands_help.dart';
import 'command_management_provider.dart';

class ChatProvider extends ChangeNotifier {
  final List<MessageEntity> _messages = [];
  List<QuickResponseEntity> _quickResponses = QuickResponseProvider.defaultResponsesAsEntities;
  bool _isProcessing = false;
  bool _isStreaming = false;
  StreamSubscription<String>? _streamSubscription;
  bool _isNewConversation = true;
  bool _isRetryingOllama = false;
  bool _ollamaSelectable = true;
  bool _needsHistoryLoad = false;

  bool _hasUnsavedChanges = false;
  File? _currentConversationFile;
  bool _isSaving = false;
  
  // ============================================================================
  // NUEVO: Control de sesión activa
  // ============================================================================
  /// Indica si hay una conversación activa en la sesión actual.
  /// Se pone en true cuando el usuario envía su primer mensaje.
  /// Se pone en false cuando el usuario crea una nueva conversación explícitamente.
  bool _hasActiveSession = false;

  late final AIServiceSelector _aiSelector;
  late final PreferencesService _preferencesService;

  final IConversationRepository _conversationRepository;
  final ICommandRepository _commandRepository;

  bool Function()? _getSyncStatus;

  CommandManagementProvider? _commandManagementProvider;

  late final GeminiService _geminiService;
  late final OllamaService _ollamaService;
  late final OpenAIService _openaiService;
  late final OllamaManagedService _localOllamaService;

  late final GeminiServiceAdapter _geminiAdapter;
  late OllamaServiceAdapter _ollamaAdapter;
  late final OpenAIServiceAdapter _openaiAdapter;
  late final LocalOllamaServiceAdapter _localOllamaAdapter;

  late CommandProcessor _commandProcessor;

  bool _showModelSelector = false;
  List<OllamaModel> _availableModels = [];
  String _currentModel = 'phi3:latest';
  AIProvider _currentProvider = AIProvider.gemini;

  static const String _groupSystemCommandsKey = 'group_system_commands';

  ChatProvider({
    required IConversationRepository conversationRepository,
    required ICommandRepository commandRepository,
    required AIServiceSelector aiServiceSelector,
  })  : _conversationRepository = conversationRepository,
        _commandRepository = commandRepository,
        _aiSelector = aiServiceSelector,
        _geminiService = aiServiceSelector.geminiService,
        _ollamaService = aiServiceSelector.ollamaService,
        _openaiService = aiServiceSelector.openaiService,
        _localOllamaService = aiServiceSelector.localOllamaService {
    _geminiAdapter = GeminiServiceAdapter(_geminiService);
    _ollamaAdapter = OllamaServiceAdapter(_ollamaService, _currentModel);
    _openaiAdapter = OpenAIServiceAdapter(_openaiService);
    _localOllamaAdapter = LocalOllamaServiceAdapter(_localOllamaService);

    _preferencesService = PreferencesService();

    _aiSelector.addListener(_onAiSelectorChanged);

    _commandProcessor = CommandProcessor(_geminiAdapter, _commandRepository);

    _initializeModels();
  }

  void setCommandManagementProvider(CommandManagementProvider provider) {
    if (_commandManagementProvider != null) {
      _commandManagementProvider!.removeListener(_onCommandDataChanged);
    }

    _commandManagementProvider = provider;
    provider.addListener(_onCommandDataChanged);

    if (!provider.isLoading) {
      _onCommandDataChanged();
    }

    debugPrint('✅ [ChatProvider] Vinculado reactivamente a CommandManagementProvider');
  }

  void _onCommandDataChanged() {
    if (_commandManagementProvider == null) return;
    _updateQuickResponsesFromProvider();
  }

  void _updateQuickResponsesFromProvider() {
    if (_commandManagementProvider == null) return;

    final provider = _commandManagementProvider!;

    final organizedResponses = QuickResponseProvider.buildOrganizedResponses(
      commands: provider.commands,
      folders: provider.folders,
      groupSystemCommands: provider.groupSystemCommands,
    );

    _quickResponses = organizedResponses.map((r) => r.toEntity()).toList();
    notifyListeners();
  }

  void setSyncStatusChecker(bool Function() checker) {
    _getSyncStatus = checker;
  }

  Future<void> _onAiSelectorChanged() async {
    debugPrint('🔄 [ChatProvider] AIServiceSelector notificó cambios, actualizando UI...');

    if (_aiSelector.ollamaAvailable) {
      if (!_ollamaSelectable) {
        _ollamaSelectable = true;
        debugPrint('   🔓 Ollama disponible: desbloqueando selección en la UI');
      }

      if (!listEquals(_availableModels, _aiSelector.availableModels)) {
        _availableModels = _aiSelector.availableModels;
        debugPrint('   ✅ Lista de modelos Ollama (remoto) actualizada: ${_availableModels.length} modelos');

        if (_availableModels.isNotEmpty) {
          final currentModelExists = _availableModels.any((m) => m.name == _currentModel);

          if (!currentModelExists || _currentModel.isEmpty) {
            _currentModel = _availableModels.first.name;
            _ollamaAdapter.updateModel(_currentModel);
            debugPrint('   ⚠️ Modelo actual no encontrado. Seleccionando por defecto: $_currentModel');
          }
        }
      }

      if (_currentProvider == AIProvider.ollama && _currentModel != _aiSelector.currentOllamaModel) {
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

    _commandProcessor = CommandProcessor(currentAdapter, _commandRepository);
    debugPrint('🔄 [ChatProvider] CommandProcessor actualizado para: $_currentProvider');
  }

  // ============================================================================
  // GETTERS
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
  
  // NUEVO: Getter para saber si hay una sesión activa
  bool get hasActiveSession => _hasActiveSession;
  
  /// Indica si la conversación actual tiene contenido significativo para guardar
  /// (más que solo el mensaje de bienvenida del bot)
  bool get hasSignificantContent {
    if (_messages.isEmpty) return false;
    // Si solo hay un mensaje y es del bot (bienvenida), no es significativo
    if (_messages.length == 1 && _messages.first.type == MessageTypeEntity.bot) return false;
    // Si hay al menos un mensaje del usuario, es significativo
    return _messages.any((m) => m.type == MessageTypeEntity.user);
  }

  AIServiceSelector get aiSelector => _aiSelector;
  bool get openaiAvailable => _aiSelector.openaiAvailable;
  String get currentOpenAIModel => _aiSelector.currentOpenAIModel;
  List<String> get availableOpenAIModels => _aiSelector.availableOpenAIModels;

  LocalOllamaStatus get localOllamaStatus => _aiSelector.localOllamaStatus;
  bool get localOllamaAvailable => _aiSelector.localOllamaAvailable;
  bool get localOllamaLoading => _aiSelector.localOllamaLoading;

  Stream<ConnectionInfo> get connectionStream => _aiSelector.connectionStream;

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
      await _updateQuickResponses();

      _ollamaSelectable = _aiSelector.ollamaAvailable;

      // NUEVO: Añadir mensaje de bienvenida al inicializar si no hay mensajes
      // Esto asegura que siempre haya un mensaje inicial al abrir la app
      if (_messages.isEmpty) {
        _addWelcomeMessage();
        debugPrint('👋 [ChatProvider] Mensaje de bienvenida añadido en inicialización');
      }

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
    debugPrint('🚀 [ChatProvider] Iniciando instalación/configuración de Ollama Embebido...');

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

  Future<void> refreshQuickResponses() async {
    await _updateQuickResponses();
    notifyListeners();
  }

  Future<void> _sendMessageWithStreaming(String content) async {
    debugPrint('\n🌊 [ChatProvider] === ENVIANDO CON STREAMING ===');
    debugPrint('   💬 Contenido: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    debugPrint('   🤖 Proveedor: $_currentProvider');

    if (_needsHistoryLoad) {
      _loadHistoryIntoAIService(_messages);
      _needsHistoryLoad = false;
    }

    if (_isNewConversation) _isNewConversation = false;
    
    // NUEVO: Marcar que hay una sesión activa
    _hasActiveSession = true;
    
    hideModelSelector();

    final now = DateTime.now();
    final userMessageId = '${now.millisecondsSinceEpoch}_user';
    final botMessageId = '${now.millisecondsSinceEpoch}_bot';

    final userMessageEntity = MessageEntity(
      id: userMessageId,
      content: content,
      type: MessageTypeEntity.user,
      timestamp: now,
    );
    _messages.add(userMessageEntity);
    notifyListeners();

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
    final completer = Completer<void>();

    try {
      final adapter = _aiSelector.getCurrentAdapter();
      final stream = adapter.generateContentStream(content);

      _streamSubscription = stream.listen(
        (chunk) {
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
        },
        onError: (error) {
          debugPrint('❌ [ChatProvider] Error en streaming: $error');

          final index = _messages.indexWhere((m) => m.id == botMessageId);
          if (index != -1) {
            _messages[index] = MessageEntity(
              id: botMessageId,
              content: buffer.isNotEmpty ? '${buffer.toString()}\n\n❌ Error: $error' : '❌ Error: $error',
              type: MessageTypeEntity.bot,
              timestamp: now,
            );
          }
          completer.complete();
        },
        onDone: () {
          debugPrint('✅ [ChatProvider] Streaming completado: ${buffer.length} caracteres');
          completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error iniciando streaming: $e');

      final index = _messages.indexWhere((m) => m.id == botMessageId);
      if (index != -1) {
        _messages[index] = MessageEntity(
          id: botMessageId,
          content: '❌ Error: $e',
          type: MessageTypeEntity.bot,
          timestamp: now,
        );
      }
    } finally {
      _streamSubscription = null;
      _isProcessing = false;
      _isStreaming = false;
      _hasUnsavedChanges = true;
      await _updateQuickResponses();
      notifyListeners();
    }
  }

  Future<void> _sendCommandWithStreaming(String content) async {
    debugPrint('\n🌊 [ChatProvider] === ENVIANDO COMANDO CON STREAMING ===');
    debugPrint('   💬 Comando: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    debugPrint('   🤖 Proveedor: $_currentProvider');

    hideModelSelector();
    
    // NUEVO: Marcar que hay una sesión activa
    _hasActiveSession = true;

    final now = DateTime.now();
    final userMessageId = '${now.millisecondsSinceEpoch}_user';
    final botMessageId = '${now.millisecondsSinceEpoch}_bot';

    final userMessageEntity = MessageEntity(
      id: userMessageId,
      content: content,
      type: MessageTypeEntity.user,
      timestamp: now,
    );
    _messages.add(userMessageEntity);
    notifyListeners();

    final commandResult = await _commandProcessor.processMessageStream(content);

    if (!commandResult.isCommand) {
      debugPrint('   ⚠️ No es comando, redirigiendo a streaming normal');
      return _sendMessageWithStreaming(content);
    }

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
    final completer = Completer<void>();

    try {
      _streamSubscription = commandResult.responseStream!.listen(
        (chunk) {
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
        },
        onError: (error) {
          debugPrint('❌ [ChatProvider] Error en comando streaming: $error');

          final index = _messages.indexWhere((m) => m.id == botMessageId);
          if (index != -1) {
            _messages[index] = MessageEntity(
              id: botMessageId,
              content: buffer.isNotEmpty ? '${buffer.toString()}\n\n❌ Error: $error' : '❌ Error: $error',
              type: MessageTypeEntity.bot,
              timestamp: now,
            );
          }
          completer.complete();
        },
        onDone: () {
          debugPrint('✅ [ChatProvider] Comando streaming completado: ${buffer.length} caracteres');
          completer.complete();
        },
        cancelOnError: true,
      );

      await completer.future;
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error iniciando comando streaming: $e');

      final index = _messages.indexWhere((m) => m.id == botMessageId);
      if (index != -1) {
        _messages[index] = MessageEntity(
          id: botMessageId,
          content: '❌ Error: $e',
          type: MessageTypeEntity.bot,
          timestamp: now,
        );
      }
    } finally {
      _streamSubscription = null;
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

    if (isCommand) {
      return _sendCommandWithStreaming(content);
    } else {
      return _sendMessageWithStreaming(content);
    }
  }

  Future<void> _updateQuickResponses() async {
    try {
      if (_commandManagementProvider != null) {
        _updateQuickResponsesFromProvider();
        return;
      }

      final allCommands = await _commandRepository.getAllCommands();
      final allFolders = await _commandRepository.getAllFolders();

      final prefs = await SharedPreferences.getInstance();
      final groupSystemCommands = prefs.getBool(_groupSystemCommandsKey) ?? false;

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

  // ============================================================================
  // NUEVO: Método para iniciar una nueva conversación explícitamente
  // ============================================================================
  /// Inicia una nueva conversación.
  /// 1. Guarda la conversación actual si tiene contenido significativo
  /// 2. Limpia los mensajes y el historial de IA
  /// 3. Resetea el estado de la sesión
  Future<void> startNewConversation() async {
    debugPrint('🆕 [ChatProvider] Iniciando nueva conversación...');
    
    // 1. Guardar la conversación actual si tiene contenido
    if (hasSignificantContent && _hasUnsavedChanges) {
      debugPrint('   💾 Guardando conversación actual antes de crear nueva...');
      await saveCurrentConversation();
    }
    
    // 2. Limpiar todo
    _messages.clear();
    _isNewConversation = true;
    _needsHistoryLoad = false;
    _currentConversationFile = null;
    _hasUnsavedChanges = false;
    _hasActiveSession = false;
    
    // 3. Limpiar historial de servicios de IA
    _clearAIServiceHistory();
    
    // 4. Añadir mensaje de bienvenida
    _addWelcomeMessage();
    
    notifyListeners();
    debugPrint('   ✅ Nueva conversación iniciada');
  }

  /// MODIFICADO: clearMessages ya NO inicia una nueva conversación automáticamente.
  /// Solo limpia los mensajes actuales sin guardar.
  /// Usar startNewConversation() para el flujo completo.
  Future<void> clearMessages() async {
    debugPrint('🗑️ [ChatProvider] Limpiando mensajes (sin guardar)...');

    _messages.clear();
    _isNewConversation = true;
    _needsHistoryLoad = false;
    _currentConversationFile = null;
    _hasUnsavedChanges = false;
    // NO reseteamos _hasActiveSession aquí para mantener la sesión

    _clearAIServiceHistory();
    _addWelcomeMessage();
    notifyListeners();
  }

  void _clearAIServiceHistory() {
    debugPrint('🧹 [ChatProvider] Limpiando historial de servicios de IA...');
    try {
      _geminiService.clearConversation();
    } catch (e) {
      debugPrint('   ⚠️ Error limpiando Gemini: $e');
    }
    try {
      _openaiService.clearConversation();
    } catch (e) {
      debugPrint('   ⚠️ Error limpiando OpenAI: $e');
    }
    try {
      _ollamaService.clearConversation();
    } catch (e) {
      debugPrint('   ⚠️ Error limpiando Ollama: $e');
    }
    try {
      _localOllamaService.clearConversation();
    } catch (e) {
      debugPrint('   ⚠️ Error limpiando Ollama Local: $e');
    }
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
      _hasActiveSession = true; // Marcar sesión activa al cargar

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

  void cancelStreaming() {
    if (_isStreaming && _streamSubscription != null) {
      debugPrint('⏹️ [ChatProvider] Cancelando streaming...');
      _streamSubscription?.cancel();
      _streamSubscription = null;
      _isProcessing = false;
      _isStreaming = false;
      _hasUnsavedChanges = true;
      notifyListeners();
      debugPrint('✅ [ChatProvider] Streaming cancelado');
    }
  }

  // ============================================================================
  // NUEVO: Método público para guardar la conversación actual
  // ============================================================================
  /// Guarda la conversación actual de forma explícita.
  /// Útil para llamar desde el ciclo de vida de la app.
  Future<void> saveCurrentConversation() async {
    if (_isSaving) return;
    if (!hasSignificantContent) {
      debugPrint('💾 [ChatProvider] No hay contenido significativo para guardar');
      return;
    }
    if (!_hasUnsavedChanges) {
      debugPrint('💾 [ChatProvider] No hay cambios sin guardar');
      return;
    }

    _isSaving = true;
    debugPrint('💾 [ChatProvider] Guardando conversación actual...');

    try {
      await _conversationRepository.saveConversation(
        _messages, 
        existingFile: _currentConversationFile,
      );
      _hasUnsavedChanges = false;
      debugPrint('   ✅ Conversación guardada correctamente.');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error al guardar conversación: $e');
    } finally {
      _isSaving = false;
    }
  }

  /// Guarda la conversación automáticamente cuando la app pierde el foco.
  /// Este método es llamado desde el AppLifecycleObserver.
  Future<void> onAppPaused() async {
    debugPrint('⏸️ [ChatProvider] App pausada - verificando guardado automático...');
    await saveCurrentConversation();
  }
  
  /// Guarda la conversación cuando la app se va a cerrar.
  /// Este método es llamado desde el AppLifecycleObserver.
  Future<void> onAppDetached() async {
    debugPrint('🔌 [ChatProvider] App desconectada - guardando conversación...');
    await saveCurrentConversation();
  }

  /// endSession ahora solo guarda, no resetea la sesión
  Future<void> endSession() async {
    if (_isSaving) return;

    if (_messages.isEmpty) return;
    if (_messages.length == 1 && _messages.first.type == MessageTypeEntity.bot) return;
    if (!_hasUnsavedChanges) return;

    _isSaving = true;
    debugPrint('💾 [ChatProvider] Guardando sesión (Actualización)...');

    try {
      await _conversationRepository.saveConversation(_messages, existingFile: _currentConversationFile);

      debugPrint('   ✅ Conversación guardada/actualizada correctamente.');
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error al guardar sesión: $e');
    } finally {
      _hasUnsavedChanges = false;
      _isSaving = false;
    }
  }
}

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