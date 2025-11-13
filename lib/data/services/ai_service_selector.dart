import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/remote_ollama_models.dart';
import '../models/local_ollama_models.dart';
import 'gemini_service.dart';
import 'ollama_service.dart';
import 'openai_service.dart';
import 'local_ollama_service.dart';
import 'dart:async';
import 'ai_service_adapters.dart';
import '../../domain/usecases/command_processor.dart';

enum AIProvider {
  gemini,
  ollama,
  openai,
  localOllama,
}

class AIServiceSelector extends ChangeNotifier {
  final GeminiService _geminiService;
  final OllamaService _ollamaService;
  final OpenAIService _openaiService;
  final OllamaManagedService _localOllamaService;
  
  AIProvider _currentProvider = AIProvider.gemini;
  String _currentOllamaModel = 'phi3:latest';
  String _currentOpenAIModel = 'gpt-4o-mini';
  List<OllamaModel> _availableModels = [];
  bool _ollamaAvailable = false;
  
  // 🔐 NUEVO: Cache para disponibilidad de OpenAI
  bool _openaiAvailable = false;
  
  StreamSubscription? _ollamaConnectionSubscription;

  LocalOllamaStatus _localOllamaStatus = LocalOllamaStatus.notInitialized;
  
  AIServiceSelector({
    required GeminiService geminiService,
    required OllamaService ollamaService,
    required OpenAIService openaiService,
    required OllamaManagedService localOllamaService,
  }) : _geminiService = geminiService,
       _ollamaService = ollamaService,
       _openaiService = openaiService,
       _localOllamaService = localOllamaService {
    _ollamaConnectionSubscription = 
        _ollamaService.connectionStream.listen(_onOllamaConnectionChanged);
    
    // 2. Escuchar el estado de Ollama Local
    _localOllamaService.addStatusListener(_onLocalOllamaStatusChanged);
    
    // 3. Inicializar OpenAI (esto es de una sola vez)
    _initializeOpenAI();
    
    // 4. Comprobar el estado inicial de Ollama Remoto (por si ya estaba conectado)
    _onOllamaConnectionChanged(_ollamaService.connectionInfo);
    
    debugPrint('✅ [AIServiceSelector] Servicios inicializados y escuchando cambios...');
  }
  
  // Getters
  AIProvider get currentProvider => _currentProvider;
  String get currentOllamaModel => _currentOllamaModel;
  String get currentOpenAIModel => _currentOpenAIModel;
  List<OllamaModel> get availableModels => _availableModels;
  List<String> get availableOpenAIModels => OpenAIService.availableModels;
  bool get ollamaAvailable => _ollamaAvailable;
  
  // Devuelve el valor cacheado (bool) en lugar de Future<bool>
  bool get openaiAvailable => _openaiAvailable;
  
  OllamaService get ollamaService => _ollamaService;
  OpenAIService get openaiService => _openaiService;
  ConnectionInfo get connectionInfo => _ollamaService.connectionInfo;
  
  // Getters para Ollama Local
  GeminiService get geminiService => _geminiService;
  OllamaManagedService get localOllamaService => _localOllamaService;
  LocalOllamaStatus get localOllamaStatus => _localOllamaStatus;
  bool get localOllamaAvailable => _localOllamaStatus == LocalOllamaStatus.ready;
  bool get localOllamaLoading => _localOllamaStatus.isProcessing;
  String? get localOllamaError => _localOllamaService.errorMessage;
  
  Stream<ConnectionInfo> get connectionStream => _ollamaService.connectionStream;
  
  void _onLocalOllamaStatusChanged(LocalOllamaStatus status) {
    debugPrint('📡 [AIServiceSelector] Estado Ollama Local cambió a: ${status.displayText}');
    _localOllamaStatus = status;
    notifyListeners();
  }
  
  // Método para refrescar la disponibilidad de OpenAI
  Future<void> refreshOpenAIAvailability() async {
    try {
      debugPrint('🔄 [AIServiceSelector] Verificando disponibilidad de OpenAI...');
      _openaiAvailable = await _openaiService.isAvailable();
      debugPrint('   ${_openaiAvailable ? "✅" : "❌"} OpenAI ${_openaiAvailable ? "disponible" : "no disponible"}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error verificando OpenAI: $e');
      _openaiAvailable = false;
      notifyListeners();
    }
  }
  
  Future<void> refreshOllama() async {
    debugPrint('🔄 [AIServiceSelector] Refrescando Ollama...');
    try {
      // Esto hará que OllamaService vuelva a comprobar su conexión.
      // Si el estado cambia, disparará el stream,
      // lo que activará nuestro listener _onOllamaConnectionChanged.
      await _ollamaService.reconnect();
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error refrescando Ollama: $e');
    }
    // No es necesario hacer nada más, el listener se encarga.
  }
  
  Future<void> _initializeServices() async {
    debugPrint('🎬 [AIServiceSelector] Inicializando servicios de IA...');
    
    await _initializeOllama();
    
    // Inicializar disponibilidad de OpenAI
    await _initializeOpenAI();
    
    debugPrint('✅ [AIServiceSelector] Servicios inicializados');
    debugPrint('   📊 Gemini: Siempre disponible');
    debugPrint('   📊 Ollama (remoto): ${_ollamaAvailable ? "Disponible" : "No disponible"}');
    debugPrint('   📊 OpenAI: ${_openaiAvailable ? "Disponible" : "No disponible"}');
    debugPrint('   📊 Ollama Local: ${_localOllamaStatus.displayText}');
  }

  // AÑADIR ESTE MÉTODO NUEVO
  Future<void> _onOllamaConnectionChanged(ConnectionInfo info) async {
    debugPrint('📡 [AIServiceSelector] Estado Ollama Remoto cambió a: ${info.status}');
    
    if (info.status == ConnectionStatus.connected) {
      final wasAvailable = _ollamaAvailable;
      _ollamaAvailable = true;
      
      // Solo cargar modelos si es la primera vez que se conecta
      // o si estaba previamente desconectado
      if (!wasAvailable) {
        debugPrint('   -> Conexión establecida. Cargando modelos...');
        await _loadAvailableModels(); // Carga los modelos
      }
    } else {
      // Si se desconecta o hay error
      if (_ollamaAvailable) {
        debugPrint('   -> Conexión perdida. Vaciando modelos.');
      }
      _ollamaAvailable = false;
      _availableModels = []; // Limpia los modelos si no hay conexión
    }
    
    // Notifica al ChatProvider sobre el cambio
    notifyListeners();
  }
  
  Future<void> _initializeOllama() async {
    try {
      debugPrint('🔷 [AIServiceSelector] Inicializando Ollama remoto...');
      await _checkOllamaAvailability();
      if (_ollamaAvailable) {
        await _loadAvailableModels();
      } else {
        debugPrint('   ⚠️ Ollama remoto no disponible en la inicialización');
      }
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error inicializando Ollama: $e');
    }
    notifyListeners();
  }
  
  // Inicializar disponibilidad de OpenAI
  Future<void> _initializeOpenAI() async {
    try {
      debugPrint('🔷 [AIServiceSelector] Inicializando OpenAI...');
      _openaiAvailable = await _openaiService.isAvailable();
      debugPrint('   ${_openaiAvailable ? "✅" : "⚠️"} OpenAI ${_openaiAvailable ? "disponible" : "no disponible"}');
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error inicializando OpenAI: $e');
      _openaiAvailable = false;
    }
  }
  
  Future<LocalOllamaInitResult> initializeLocalOllama() async {
    debugPrint('🚀 [AIServiceSelector] Iniciando Ollama Local...');
    
    final result = await _localOllamaService.initialize();
    
    if (result.success) {
      debugPrint('✅ [AIServiceSelector] Ollama Local inicializado correctamente');
      debugPrint('   🤖 Modelo activo: ${result.modelName}');
      debugPrint('   📋 Modelos disponibles: ${result.availableModels?.join(", ")}');
    } else {
      debugPrint('❌ [AIServiceSelector] Error inicializando Ollama Local: ${result.error}');
    }
    
    notifyListeners();
    return result;
  }
  
  Future<void> stopLocalOllama() async {
    debugPrint('🛑 [AIServiceSelector] Deteniendo Ollama Local...');
    
    if (_currentProvider == AIProvider.localOllama) {
      debugPrint('   🔄 Cambiando a Gemini antes de detener');
      await setProvider(AIProvider.gemini);
    }
    
    await _localOllamaService.stop();
    notifyListeners();
  }
  
  Future<LocalOllamaInitResult> retryLocalOllama() async {
    debugPrint('🔄 [AIServiceSelector] Reintentando inicialización de Ollama Local...');
    return await _localOllamaService.retry();
  }
  
  Future<void> _checkOllamaAvailability() async {
    try {
      debugPrint('💓 [AIServiceSelector] Verificando disponibilidad de Ollama remoto...');
      final health = await _ollamaService.checkHealth();
      _ollamaAvailable = health.success && health.ollamaAvailable;
      debugPrint('   ${_ollamaAvailable ? "✅" : "❌"} Ollama remoto ${_ollamaAvailable ? "disponible" : "no disponible"}');
    } catch (e) {
      debugPrint('   ❌ Error en health check: $e');
      _ollamaAvailable = false;
    }
  }
  
  Future<void> _loadAvailableModels() async {
    try {
      debugPrint('📋 [AIServiceSelector] Cargando modelos de Ollama remoto...');
      _availableModels = await _ollamaService.getModels();
      
      if (_availableModels.isNotEmpty) {
        final modelExists = _availableModels.any((m) => m.name == _currentOllamaModel);
        if (modelExists) {
          debugPrint('   ✅ Modelo actual $_currentOllamaModel está disponible');
        } else {
          final oldModel = _currentOllamaModel;
          _currentOllamaModel = _availableModels.first.name;
          debugPrint('   ⚠️ Modelo $oldModel no encontrado, usando ${_availableModels.first.name}');
        }
      } else {
        // Si no hay modelos, no podemos decir que el modelo actual está disponible
        debugPrint('   ❌ No se encontraron modelos en el servidor.');
      }
      
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error cargando modelos: $e');
      _availableModels = [];
    }
  }
  
  Future<void> setProvider(AIProvider provider) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando proveedor a: $provider');
    
    if (provider == AIProvider.ollama && !_ollamaAvailable) {
      debugPrint('   ⚠️ Ollama remoto no está disponible');
      throw Exception('Ollama remoto no está disponible');
    }
    
    // Ahora usa la variable cacheada
    if (provider == AIProvider.openai && !_openaiAvailable) {
      debugPrint('   ⚠️ OpenAI no está disponible');
      throw Exception('OpenAI no está disponible. Configure su API Key en Ajustes');
    }
    
    if (provider == AIProvider.localOllama && !localOllamaAvailable) {
      debugPrint('   ⚠️ Ollama Local no está listo');
      throw Exception('Ollama Local no está listo. Inicialízalo primero.');
    }
    
    _currentProvider = provider;
    notifyListeners();
    debugPrint('   ✅ Proveedor cambiado a $provider');
  }
  
  Future<void> setOllamaModel(String modelName) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo Ollama a: $modelName');
    
    if (!_availableModels.any((m) => m.name == modelName)) {
      debugPrint('   ❌ Modelo $modelName no está disponible');
      throw Exception('Modelo $modelName no está disponible');
    }
    
    _currentOllamaModel = modelName;
    notifyListeners();
    debugPrint('   ✅ Modelo cambiado a $modelName');
  }
  
  Future<void> setOpenAIModel(String modelName) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo OpenAI a: $modelName');
    
    if (!OpenAIService.availableModels.contains(modelName)) {
      debugPrint('   ❌ Modelo $modelName no está disponible');
      throw Exception('Modelo $modelName no está disponible');
    }
    
    _currentOpenAIModel = modelName;
    notifyListeners();
    debugPrint('   ✅ Modelo OpenAI cambiado a $modelName');
  }
  
  Future<bool> setLocalOllamaModel(String modelName) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo Ollama Local a: $modelName');
    
    final success = await _localOllamaService.changeModel(modelName);
    
    if (success) {
      debugPrint('   ✅ Modelo Ollama Local cambiado a $modelName');
    } else {
      debugPrint('   ❌ Error cambiando modelo Ollama Local');
    }
    
    // El listener _onLocalOllamaStatusChanged se activará
    // y notificará a los listeners (ChatProvider)
    return success;
  }
  
  Future<String> sendMessage(String message, {List<Message>? history}) async {
    debugPrint('📤 [AIServiceSelector] === ENVIANDO MENSAJE ===');
    debugPrint('   🎯 Proveedor: $_currentProvider');
    debugPrint('   💬 Mensaje: ${message.length > 50 ? "${message.substring(0, 50)}..." : message}');
    debugPrint('   📚 Historial: ${history?.length ?? 0} mensajes');
    
    switch (_currentProvider) {
      case AIProvider.gemini:
        return await _sendToGemini(message, history);
      case AIProvider.ollama:
        return await _sendToOllama(message, history);
      case AIProvider.openai:
        return await _sendToOpenAI(message, history);
      case AIProvider.localOllama:
        return await _sendToLocalOllama(message, history);
    }
  }
  
  Future<String> _sendToGemini(String message, List<Message>? history) async {
    try {
      debugPrint('   💎 Usando Gemini...');
      final response = await _geminiService.generateContent(message);
      debugPrint('✅ [AIServiceSelector] Respuesta de Gemini recibida (${response.length} chars)');
      debugPrint('🟢 [AIServiceSelector] === ENVÍO EXITOSO ===\n');
      return response;
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error con Gemini: $e');
      throw Exception('Error con Gemini: $e');
    }
  }
  
  Future<String> _sendToOllama(String message, List<Message>? history) async {
    try {
      debugPrint('   🔍 Verificando disponibilidad del modelo $_currentOllamaModel...');
      
      final isAvailable = await _ollamaService.isModelAvailable(_currentOllamaModel);
      if (!isAvailable) {
        debugPrint('   ❌ Modelo $_currentOllamaModel no disponible');
        throw Exception('Modelo $_currentOllamaModel no disponible');
      }
      
      debugPrint('   ✓ Modelo disponible');
      
      String response;
      if (history != null && history.isNotEmpty) {
        debugPrint('   📝 Usando chat con historial (${history.length} mensajes)');
        final chatMessages = _convertHistoryToChatMessages(history, message);
        response = await _ollamaService.chatWithHistory(
          model: _currentOllamaModel,
          messages: chatMessages,
        );
      } else {
        debugPrint('   💭 Usando generación simple');
        response = await _ollamaService.generateResponse(
          model: _currentOllamaModel,
          prompt: message,
          systemPrompt: 'Eres un asistente de IA útil y educativo especializado en enseñar sobre inteligencia artificial y prompting.',
        );
      }
      
      debugPrint('✅ [AIServiceSelector] Respuesta de Ollama recibida (${response.length} chars)');
      debugPrint('🟢 [AIServiceSelector] === ENVÍO EXITOSO ===\n');
      return response;
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error con Ollama: $e');
      throw Exception('Error con Ollama: $e');
    }
  }
  
  Future<String> _sendToOpenAI(String message, List<Message>? history) async {
    try {
      debugPrint('   🔍 Usando modelo: $_currentOpenAIModel');
      
      String response;
      if (history != null && history.isNotEmpty) {
        debugPrint('   📝 Usando chat con historial (${history.length} mensajes)');
        
        final messages = <Map<String, String>>[];
        final recentHistory = history.length > 10 
            ? history.sublist(history.length - 10) 
            : history;
        
        for (final msg in recentHistory) {
          messages.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          });
        }
        
        messages.add({
          'role': 'user',
          'content': message,
        });
        
        response = await _openaiService.chatWithHistory(
          messages: messages,
          model: _currentOpenAIModel,
        );
      } else {
        debugPrint('   💭 Usando generación simple');
        response = await _openaiService.generateContent(
          message,
          model: _currentOpenAIModel,
        );
      }
      
      debugPrint('✅ [AIServiceSelector] Respuesta de OpenAI recibida (${response.length} chars)');
      debugPrint('🟢 [AIServiceSelector] === ENVÍO EXITOSO ===\n');
      return response;
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error con OpenAI: $e');
      throw Exception('Error con OpenAI: $e');
    }
  }
  
  Future<String> _sendToLocalOllama(String message, List<Message>? history) async {
    try {
      debugPrint('   🔍 Verificando estado de Ollama Local...');
      
      if (_localOllamaStatus != LocalOllamaStatus.ready) {
        debugPrint('   ❌ Ollama Local no está listo: ${_localOllamaStatus.displayText}');
        throw Exception('Ollama Local no está listo');
      }
      
      debugPrint('   ✓ Ollama Local disponible');
      debugPrint('   💭 Generando respuesta localmente...');
      
      String response;
      if (history != null && history.isNotEmpty) {
        debugPrint('   📝 Usando chat con historial (${history.length} mensajes)');
        
        final chatHistory = <Map<String, String>>[];
        final recentHistory = history.length > 10 
            ? history.sublist(history.length - 10) 
            : history;
        
        for (final msg in recentHistory) {
          chatHistory.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          });
        }
        
        response = await _localOllamaService.chatWithHistory(
          prompt: message,
          history: chatHistory,
        );
      } else {
        debugPrint('   💭 Usando generación simple');
        response = await _localOllamaService.generateContent(message);
      }
      
      debugPrint('✅ [AIServiceSelector] Respuesta de Ollama Local recibida (${response.length} chars)');
      debugPrint('🟢 [AIServiceSelector] === ENVÍO EXITOSO ===\n');
      return response;
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error con Ollama Local: $e');
      throw Exception('Error con Ollama Local: $e');
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
    
    debugPrint('   📚 Convirtiendo historial: ${recentHistory.length} mensajes recientes');

    for (final msg in recentHistory) {
      messages.add(ChatMessage(
        role: msg.isUser ? 'user' : 'assistant',
        content: msg.text,
      ));
    }
    
    messages.add(ChatMessage(
      role: 'user',
      content: newMessage,
    ));
    
    debugPrint('   ✓ Total de mensajes para chat: ${messages.length}');
    
    return messages;
  }
  
  @override
  void dispose() {
    debugPrint('🔴 [AIServiceSelector] Disposing...');
    _ollamaConnectionSubscription?.cancel();
    _localOllamaService.removeStatusListener(_onLocalOllamaStatusChanged);
    _localOllamaService.dispose();
    _ollamaService.dispose();
    super.dispose();
  }

  AIServiceBase getCurrentAdapter() {
    debugPrint('🔌 [AIServiceSelector] Obteniendo adaptador para: $_currentProvider');
    
    switch (_currentProvider) {
      case AIProvider.gemini:
        return GeminiServiceAdapter(_geminiService);
      case AIProvider.openai:
        return OpenAIServiceAdapter(_openaiService);
      case AIProvider.ollama:
        return OllamaServiceAdapter(_ollamaService, _currentOllamaModel);
      case AIProvider.localOllama:
        return LocalOllamaServiceAdapter(_localOllamaService);
    }
  }
}