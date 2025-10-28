import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/ollama_models.dart';
import '../models/local_ollama_models.dart';
import 'gemini_service.dart';
import 'ollama_service.dart';
import 'openai_service.dart';
import 'local_ollama_service.dart';

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
  bool _openaiAvailable = false;
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
    _initializeServices();
    _localOllamaService.addStatusListener(_onLocalOllamaStatusChanged);
  }
  
  // Getters
  AIProvider get currentProvider => _currentProvider;
  String get currentOllamaModel => _currentOllamaModel;
  String get currentOpenAIModel => _currentOpenAIModel;
  List<OllamaModel> get availableModels => _availableModels;
  List<String> get availableOpenAIModels => OpenAIService.availableModels;
  bool get ollamaAvailable => _ollamaAvailable;
  bool get openaiAvailable => _openaiAvailable;
  OllamaService get ollamaService => _ollamaService;
  OpenAIService get openaiService => _openaiService;
  ConnectionInfo get connectionInfo => _ollamaService.connectionInfo;
  
  // Getters para Ollama Local
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
  
  Future<void> refreshOllama() async {
    debugPrint('🔄 [AIServiceSelector] Refrescando Ollama...');
    try {
      await _ollamaService.reconnect();
      await _checkOllamaAvailability();
      if (_ollamaAvailable) {
        await _loadAvailableModels();
      }
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error refrescando Ollama: $e');
    }
  }
  
  Future<void> _initializeServices() async {
    debugPrint('🎬 [AIServiceSelector] Inicializando servicios de IA...');
    
    await _initializeOllama();
    _initializeOpenAI();
    
    debugPrint('✅ [AIServiceSelector] Servicios inicializados');
    debugPrint('   📊 Gemini: Siempre disponible');
    debugPrint('   📊 Ollama (remoto): ${_ollamaAvailable ? "Disponible" : "No disponible"}');
    debugPrint('   📊 OpenAI: ${_openaiAvailable ? "Disponible" : "No disponible"}');
    debugPrint('   📊 Ollama Local: ${_localOllamaStatus.displayText}');
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
  
  void _initializeOpenAI() {
    _openaiAvailable = _openaiService.isAvailable;
    if (_openaiAvailable) {
      debugPrint('✅ [AIServiceSelector] OpenAI disponible');
      debugPrint('   🤖 Modelos disponibles: ${OpenAIService.availableModels.join(", ")}');
    } else {
      debugPrint('⚠️ [AIServiceSelector] OpenAI no disponible (API Key no configurada)');
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
      
      if (_availableModels.isNotEmpty && 
          !_availableModels.any((m) => m.name == _currentOllamaModel)) {
        final oldModel = _currentOllamaModel;
        _currentOllamaModel = _availableModels.first.name;
        debugPrint('   ⚠️ Modelo $oldModel no encontrado, usando ${_availableModels.first.name}');
      } else {
        debugPrint('   ✅ Modelo actual $_currentOllamaModel está disponible');
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
    
    if (provider == AIProvider.openai && !_openaiAvailable) {
      debugPrint('   ⚠️ OpenAI no está disponible');
      throw Exception('OpenAI no está disponible. Configure API Key en .env');
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
      debugPrint('   ❌ Modelo $modelName no disponible');
      throw Exception('Modelo no disponible');
    }
    
    _currentOllamaModel = modelName;
    notifyListeners();
    debugPrint('   ✅ Modelo Ollama cambiado a $modelName');
  }
  
  Future<void> setOpenAIModel(String modelName) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo OpenAI a: $modelName');
    
    if (!OpenAIService.availableModels.contains(modelName)) {
      debugPrint('   ❌ Modelo $modelName no disponible');
      throw Exception('Modelo no disponible');
    }
    
    _currentOpenAIModel = modelName;
    notifyListeners();
    debugPrint('   ✅ Modelo OpenAI cambiado a $modelName');
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
    _localOllamaService.removeStatusListener(_onLocalOllamaStatusChanged);
    _localOllamaService.dispose();
    _ollamaService.dispose();
    super.dispose();
  }
}