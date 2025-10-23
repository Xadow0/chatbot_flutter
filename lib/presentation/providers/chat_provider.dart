import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../data/models/message_model.dart';
import '../../data/models/quick_response_model.dart';
import '../../data/models/ollama_models.dart';
import '../../data/services/gemini_service.dart';
import '../../data/services/ollama_service.dart';
import '../../data/services/openai_service.dart';
import '../../data/services/ai_service_selector.dart';
import '../../data/services/preferences_service.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../domain/usecases/command_processor.dart';
import '../../domain/usecases/send_message_usecase.dart';

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  List<QuickResponse> _quickResponses = QuickResponseProvider.defaultResponses;
  bool _isProcessing = false;
  bool _isNewConversation = true;

  late final SendMessageUseCase _sendMessageUseCase;
  late final AIServiceSelector _aiSelector;
  late final PreferencesService _preferencesService;
  
  // Estado específico para la selección de modelos
  bool _showModelSelector = false;
  List<OllamaModel> _availableModels = [];
  String _currentModel = 'phi3:latest';
  AIProvider _currentProvider = AIProvider.gemini;

  ChatProvider() {
    final geminiService = GeminiService();
    final ollamaService = OllamaService();
    final openaiService = OpenAIService();
    
    // Inicializar servicio de preferencias
    _preferencesService = PreferencesService();
    
    // Inicializar selector de IA
    _aiSelector = AIServiceSelector(
      geminiService: geminiService,
      ollamaService: ollamaService,
      openaiService: openaiService,
    );
    
    // Configurar command processor con ambos servicios
    final commandProcessor = CommandProcessor(geminiService);
    final localRepository = LocalChatRepository();

    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: commandProcessor,
      chatRepository: localRepository,
    );

    // Inicializar modelos disponibles y restaurar preferencias
    _initializeModels();
    
    // Añadir mensaje de bienvenida al iniciar una conversación nueva
    _addWelcomeMessage();
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
  
  // Nuevos getters para OpenAI
  AIServiceSelector get aiSelector => _aiSelector;
  bool get openaiAvailable => _aiSelector.openaiAvailable;
  String get currentOpenAIModel => _aiSelector.currentOpenAIModel;
  List<String> get availableOpenAIModels => _aiSelector.availableOpenAIModels;
  
  // Stream de conexión
  Stream<ConnectionInfo> get connectionStream => _aiSelector.connectionStream;

  /// Inicializar modelos disponibles y restaurar preferencias
  Future<void> _initializeModels() async {
    try {
      debugPrint('🎬 [ChatProvider] Inicializando modelos...');
      
      // Verificar si Ollama está disponible
      await _aiSelector.refreshOllama();
      
      if (_aiSelector.ollamaAvailable) {
        _availableModels = _aiSelector.availableModels;
        if (_availableModels.isNotEmpty) {
          _currentModel = _availableModels.first.name;
        }
      }
      
      // Restaurar preferencias del usuario
      await _restoreUserPreferences();
      
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error inicializando modelos: $e');
    }
  }
  
  /// Restaurar las preferencias del usuario
  Future<void> _restoreUserPreferences() async {
    try {
      debugPrint('🔄 [ChatProvider] Restaurando preferencias...');
      
      // Obtener último proveedor usado
      final lastProvider = await _preferencesService.getLastProvider();
      
      if (lastProvider != null) {
        // Verificar disponibilidad del proveedor antes de restaurarlo
        bool canRestore = false;
        
        switch (lastProvider) {
          case AIProvider.gemini:
            // Gemini siempre disponible
            canRestore = true;
            break;
            
          case AIProvider.ollama:
            // Verificar si Ollama está disponible
            canRestore = _aiSelector.ollamaAvailable;
            if (!canRestore) {
              debugPrint('   ⚠️ Ollama no disponible, usando Gemini por defecto');
            }
            break;
            
          case AIProvider.openai:
            // Verificar si OpenAI está configurado
            canRestore = _aiSelector.openaiAvailable;
            if (!canRestore) {
              debugPrint('   ⚠️ OpenAI no disponible, usando Gemini por defecto');
            }
            break;
        }
        
        if (canRestore) {
          _currentProvider = lastProvider;
          await _aiSelector.setProvider(lastProvider);
          debugPrint('   ✅ Restaurado proveedor: $lastProvider');
          
          // Restaurar modelo específico según el proveedor
          await _restoreProviderModel(lastProvider);
        } else {
          // Si no se puede restaurar, usar Gemini por defecto
          _currentProvider = AIProvider.gemini;
          await _aiSelector.setProvider(AIProvider.gemini);
          debugPrint('   ℹ️ Usando Gemini por defecto');
        }
      } else {
        debugPrint('   ℹ️ No hay preferencias previas, usando Gemini');
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error restaurando preferencias: $e');
      // En caso de error, usar Gemini por defecto
      _currentProvider = AIProvider.gemini;
    }
  }
  
  /// Restaurar el modelo específico del proveedor
  Future<void> _restoreProviderModel(AIProvider provider) async {
    try {
      switch (provider) {
        case AIProvider.ollama:
          final lastModel = await _preferencesService.getLastOllamaModel();
          if (lastModel != null && _availableModels.any((m) => m.name == lastModel)) {
            _currentModel = lastModel;
            await _aiSelector.setOllamaModel(lastModel);
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
          // Gemini usa un solo modelo, no hay que restaurar nada
          break;
      }
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error restaurando modelo: $e');
    }
  }

  /// Alternar visibilidad del selector de modelos
  void toggleModelSelector() {
    _showModelSelector = !_showModelSelector;
    notifyListeners();
  }

  /// Ocultar selector de modelos
  void hideModelSelector() {
    if (_showModelSelector) {
      _showModelSelector = false;
      notifyListeners();
    }
  }

  /// Cambiar proveedor de IA
  Future<void> changeProvider(AIProvider provider) async {
    try {
      debugPrint('🔄 [ChatProvider] Cambiando proveedor a: $provider');
      
      // Verificar disponibilidad según el proveedor
      if (provider == AIProvider.ollama && !_aiSelector.ollamaAvailable) {
        throw Exception('Ollama no está disponible');
      }
      
      if (provider == AIProvider.openai && !_aiSelector.openaiAvailable) {
        throw Exception('OpenAI no está disponible. Configura OPENAI_API_KEY en .env');
      }
      
      await _aiSelector.setProvider(provider);
      _currentProvider = provider;
      
      // Si es Ollama y tenemos modelos, usar el modelo actual
      if (provider == AIProvider.ollama && _availableModels.isNotEmpty) {
        await _aiSelector.setOllamaModel(_currentModel);
      }
      
      // Guardar preferencia del usuario
      await _preferencesService.saveLastProvider(provider);
      
      debugPrint('   ✅ Proveedor cambiado y guardado: $provider');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando proveedor: $e');
      rethrow;
    }
  }

  /// Cambiar modelo de Ollama
  Future<void> changeModel(String modelName) async {
    try {
      debugPrint('🔄 [ChatProvider] Cambiando modelo a: $modelName');
      
      if (_currentProvider != AIProvider.ollama) {
        // Cambiar a Ollama automáticamente si se selecciona un modelo
        await changeProvider(AIProvider.ollama);
      }
      
      await _aiSelector.setOllamaModel(modelName);
      _currentModel = modelName;
      
      // Guardar preferencia del modelo
      await _preferencesService.saveLastOllamaModel(modelName);
      
      _showModelSelector = false; // Ocultar selector después de seleccionar
      
      debugPrint('   ✅ Modelo cambiado y guardado: $modelName');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando modelo: $e');
      rethrow;
    }
  }
  
  /// Cambiar modelo de OpenAI
  Future<void> changeOpenAIModel(String modelName) async {
    try {
      debugPrint('🔄 [ChatProvider] Cambiando modelo OpenAI a: $modelName');
      
      if (_currentProvider != AIProvider.openai) {
        // Cambiar a OpenAI automáticamente si se selecciona un modelo
        await changeProvider(AIProvider.openai);
      }
      
      _aiSelector.setOpenAIModel(modelName);
      
      // Guardar preferencia del modelo
      await _preferencesService.saveLastOpenAIModel(modelName);
      
      _showModelSelector = false; // Ocultar selector después de seleccionar
      
      debugPrint('   ✅ Modelo OpenAI cambiado y guardado: $modelName');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error cambiando modelo OpenAI: $e');
      rethrow;
    }
  }

  /// Refrescar modelos disponibles
  Future<void> refreshModels() async {
    try {
      debugPrint('🔄 [ChatProvider] Refrescando modelos...');
      
      await _aiSelector.refreshOllama();
      if (_aiSelector.ollamaAvailable) {
        _availableModels = _aiSelector.availableModels;
        
        // Si el modelo actual no está disponible, seleccionar el primero
        if (_availableModels.isNotEmpty && 
            !_availableModels.any((m) => m.name == _currentModel)) {
          _currentModel = _availableModels.first.name;
          await _aiSelector.setOllamaModel(_currentModel);
          debugPrint('   ℹ️ Modelo cambiado a: $_currentModel');
        }
      }
      
      debugPrint('   ✅ Modelos refrescados');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [ChatProvider] Error refrescando modelos: $e');
    }
  }

  /// Añade el mensaje de bienvenida inicial
  void _addWelcomeMessage() {
    final welcomeMessage = '''
¡Bienvenido al chat! 👋

Aquí puedes conversar conmigo y utilizar los siguientes comandos:

**Comandos disponibles:**

- **/tryprompt** [escribe aquí tu prompt] -- Este comando te permite ejecutar un análisis y mejora de tu prompt, generando como resultado un prompt mejorado en caso de que sea posible.

💡 **Nuevo:** Ahora puedes usar IA local con Ollama. Toca el botón de modelos en la parte superior para cambiar entre diferentes IAs.

¡Empieza escribiendo tu mensaje!''';

    _messages.add(Message.bot(welcomeMessage));
    notifyListeners();
  }

  /// Envía un mensaje usando el servicio actual (Gemini o Ollama)
  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isProcessing) return;

    debugPrint('\n🚀 [ChatProvider] === ENVIANDO MENSAJE ===');
    debugPrint('   💬 Contenido: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
    debugPrint('   🤖 Proveedor actual: $_currentProvider');
    debugPrint('   📝 Modelo actual: $_currentModel');

    // Marcar que ya no es una conversación nueva después del primer mensaje
    if (_isNewConversation) {
      _isNewConversation = false;
    }

    // Ocultar selector de modelos si está visible
    hideModelSelector();

    final userMessage = Message.user(content);
    _messages.add(userMessage);
    _isProcessing = true;
    notifyListeners();

    try {
      String botResponse;
      
      if (_currentProvider == AIProvider.ollama && _aiSelector.ollamaAvailable) {
        debugPrint('   🟪 Usando Ollama...');
        // Usar Ollama
        botResponse = await _sendToOllama(content);
      } else {
        debugPrint('   🟦 Usando Gemini...');
        // Usar Gemini (comportamiento original)
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
      
      // Si falla Ollama, ofrecer cambiar a Gemini
      if (_currentProvider == AIProvider.ollama) {
        errorMessage += '\n\n💡 ¿Quieres probar con Gemini? Toca el selector de modelos arriba.';
      }
      
      _messages.add(Message.bot(errorMessage));
    } finally {
      _isProcessing = false;
      _updateQuickResponses();
      notifyListeners();

      // 🔹 Guarda automáticamente cada vez que cambia la conversación
      await _autoSaveConversation();
    }
  }

  /// Enviar mensaje a Ollama
  Future<String> _sendToOllama(String content) async {
    try {
      debugPrint('   📤 [ChatProvider] Preparando mensaje para Ollama...');
      debugPrint('   🎯 Modelo: $_currentModel');
      
      // Si es un comando, usar el command processor existente con Gemini
      if (content.startsWith('/')) {
        debugPrint('   🔸 Detectado comando, usando Gemini para procesarlo');
        final response = await _sendMessageUseCase.execute(content);
        return response.content;
      }

      // Para mensajes normales, usar Ollama directamente a través del selector
      debugPrint('   💬 Enviando mensaje normal a Ollama');
      
      // Usar el selector de AI que ya maneja la verificación y el envío
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

  /// Convertir historial a formato de chat para Ollama
  List<ChatMessage> _convertHistoryToChatMessages(List<Message> history, String newMessage) {
    final messages = <ChatMessage>[
      ChatMessage(
        role: 'system',
        content: 'Eres un asistente de IA útil y educativo especializado en enseñar sobre inteligencia artificial y prompting. Responde de manera clara, educativa y práctica.',
      ),
    ];

    // Agregar historial (últimos 10 mensajes para no sobrecargar)
    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;

    for (final msg in recentHistory) {
      // Saltar mensaje de bienvenida
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

  /// Guarda automáticamente la conversación actual
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

  /// Limpia el chat (opcionalmente guardando antes)
  Future<void> clearMessages({bool saveBeforeClear = true}) async {
    debugPrint('🗑️ [ChatProvider] Limpiando mensajes...');
    
    if (saveBeforeClear && _messages.isNotEmpty) {
      await ConversationRepository.saveConversation(_messages);
    }
    _messages.clear();
    _isNewConversation = true;
    
    // Añadir mensaje de bienvenida al limpiar
    _addWelcomeMessage();
    notifyListeners();
    
    debugPrint('   ✅ Mensajes limpiados');
  }

  /// Carga una conversación desde un archivo
  Future<void> loadConversation(File file) async {
    debugPrint('📂 [ChatProvider] Cargando conversación desde archivo...');
    
    final loadedMessages = await ConversationRepository.loadConversation(file);
    _messages
      ..clear()
      ..addAll(loadedMessages);
    
    // Marcar como conversación existente (no mostrar mensaje de bienvenida)
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