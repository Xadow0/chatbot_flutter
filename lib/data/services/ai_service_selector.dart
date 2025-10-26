import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/ollama_models.dart';
import '../models/ollama_local_models.dart'; // CAMBIADO: nuevo import
import 'gemini_service.dart';
import 'ollama_service.dart';
import 'openai_service.dart';
import 'local_llm_service.dart';

enum AIProvider {
  gemini,
  ollama,
  openai,
  localLLM, // Ollama Local (ejecutándose en la máquina del usuario)
}

class AIServiceSelector extends ChangeNotifier {
  final GeminiService _geminiService;
  final OllamaService _ollamaService;
  final OpenAIService _openaiService;
  final LocalLLMService _localLLMService;
  
  AIProvider _currentProvider = AIProvider.gemini;
  String _currentOllamaModel = 'phi3:latest';
  String _currentOpenAIModel = 'gpt-4o-mini';
  List<OllamaModel> _availableModels = [];
  bool _ollamaAvailable = false;
  bool _openaiAvailable = false;
  OllamaLocalStatus _localLLMStatus = OllamaLocalStatus.stopped; // CAMBIADO: nuevo tipo
  
  AIServiceSelector({
    required GeminiService geminiService,
    required OllamaService ollamaService,
    required OpenAIService openaiService,
    required LocalLLMService localLLMService,
  }) : _geminiService = geminiService,
       _ollamaService = ollamaService,
       _openaiService = openaiService,
       _localLLMService = localLLMService {
    _initializeServices();
    
    // Escuchar cambios de estado del LLM local
    _localLLMService.addStatusListener(_onLocalLLMStatusChanged);
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
  
  // Getters para LLM local (Ollama Local)
  LocalLLMService get localLLMService => _localLLMService;
  OllamaLocalStatus get localLLMStatus => _localLLMStatus; // CAMBIADO: nuevo tipo
  bool get localLLMAvailable => _localLLMStatus == OllamaLocalStatus.ready; // CAMBIADO
  bool get localLLMLoading => _localLLMStatus == OllamaLocalStatus.connecting; // CAMBIADO
  String? get localLLMError => _localLLMService.errorMessage;
  
  // Stream de estado de conexión
  Stream<ConnectionInfo> get connectionStream => _ollamaService.connectionStream;
  
  // Callback para cambios de estado del LLM local
  void _onLocalLLMStatusChanged(OllamaLocalStatus status) { // CAMBIADO: nuevo tipo
    debugPrint('📡 [AIServiceSelector] Estado LLM local cambió a: ${status.displayText}');
    _localLLMStatus = status;
    notifyListeners();
  }
  
  // NUEVO: Método público para refrescar conexión y modelos de Ollama
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
  
  // Inicializar todos los servicios
  Future<void> _initializeServices() async {
    debugPrint('🎬 [AIServiceSelector] Inicializando servicios de IA...');
    
    // Inicializar Ollama (servidor remoto)
    await _initializeOllama();
    
    // Inicializar OpenAI
    _initializeOpenAI();
    
    // El LLM local se inicializa bajo demanda, no automáticamente
    
    debugPrint('✅ [AIServiceSelector] Servicios inicializados');
    debugPrint('   📊 Gemini: Siempre disponible');
    debugPrint('   📊 Ollama (remoto): ${_ollamaAvailable ? "Disponible" : "No disponible"}');
    debugPrint('   📊 OpenAI: ${_openaiAvailable ? "Disponible" : "No disponible"}');
    debugPrint('   📊 LLM Local (Ollama): ${_localLLMStatus.displayText}');
  }
  
  // Inicializar Ollama (servidor remoto)
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
  
  // Inicializar OpenAI
  void _initializeOpenAI() {
    _openaiAvailable = _openaiService.isAvailable;
    if (_openaiAvailable) {
      debugPrint('✅ [AIServiceSelector] OpenAI disponible');
      debugPrint('   🤖 Modelos disponibles: ${OpenAIService.availableModels.join(", ")}');
    } else {
      debugPrint('⚠️ [AIServiceSelector] OpenAI no disponible (API Key no configurada)');
    }
  }
  
  // MODIFICADO: Inicializar LLM Local (Ollama Local)
  Future<OllamaLocalInitResult> initializeLocalLLM() async { // CAMBIADO: nuevo tipo de retorno
    debugPrint('🚀 [AIServiceSelector] Iniciando Ollama Local...');
    
    final result = await _localLLMService.initializeModel();
    
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
  
  // MODIFICADO: Detener LLM Local
  Future<void> stopLocalLLM() async {
    debugPrint('🛑 [AIServiceSelector] Deteniendo Ollama Local...');
    
    // Si el proveedor actual es el LLM local, cambiar a Gemini
    if (_currentProvider == AIProvider.localLLM) {
      debugPrint('   🔄 Cambiando a Gemini antes de detener');
      await setProvider(AIProvider.gemini);
    }
    
    await _localLLMService.stopModel();
    notifyListeners();
  }
  
  // MODIFICADO: Reintentar inicialización del LLM local
  Future<OllamaLocalInitResult> retryLocalLLM() async { // CAMBIADO: nuevo tipo de retorno
    debugPrint('🔄 [AIServiceSelector] Reintentando inicialización de Ollama Local...');
    return await _localLLMService.retry();
  }
  
  // Verificar disponibilidad de Ollama (servidor remoto)
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
  
  // Cargar modelos disponibles (Ollama remoto)
  Future<void> _loadAvailableModels() async {
    try {
      debugPrint('📋 [AIServiceSelector] Cargando modelos de Ollama remoto...');
      _availableModels = await _ollamaService.getModels();
      
      // Si el modelo actual no está disponible, seleccionar el primero
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
  
  // Cambiar proveedor
  Future<void> setProvider(AIProvider provider) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando proveedor a: $provider');
    
    // Validaciones según el proveedor
    if (provider == AIProvider.ollama) {
      await _checkOllamaAvailability();
      if (!_ollamaAvailable) {
        debugPrint('❌ [AIServiceSelector] No se puede cambiar a Ollama: no disponible');
        throw Exception('Ollama no está disponible. Verifica que el servidor esté accesible.');
      }
    } else if (provider == AIProvider.openai) {
      if (!_openaiAvailable) {
        debugPrint('❌ [AIServiceSelector] No se puede cambiar a OpenAI: no disponible');
        throw Exception('OpenAI no está disponible. Verifica tu API Key.');
      }
    } else if (provider == AIProvider.localLLM) {
      if (_localLLMStatus != OllamaLocalStatus.ready) { // CAMBIADO
        debugPrint('❌ [AIServiceSelector] No se puede cambiar a Ollama Local: no disponible');
        throw Exception('Ollama Local no está disponible. Inicializa primero.');
      }
    }
    
    _currentProvider = provider;
    notifyListeners();
    debugPrint('✅ [AIServiceSelector] Proveedor cambiado a: $provider');
  }
  
  // Cambiar modelo de Ollama remoto
  Future<void> setOllamaModel(String modelName) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo de Ollama a: $modelName');
    
    // Verificar que el modelo esté disponible
    final isAvailable = await _ollamaService.isModelAvailable(modelName);
    if (!isAvailable) {
      debugPrint('❌ [AIServiceSelector] Modelo no disponible: $modelName');
      throw Exception('Modelo $modelName no disponible');
    }
    
    _currentOllamaModel = modelName;
    notifyListeners();
    debugPrint('✅ [AIServiceSelector] Modelo de Ollama cambiado a: $modelName');
  }
  
  // Cambiar modelo de OpenAI
  void setOpenAIModel(String modelName) {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo de OpenAI a: $modelName');
    _currentOpenAIModel = modelName;
    notifyListeners();
  }
  
  // Enviar mensaje al proveedor actual
  Future<String> sendMessage(String message, {List<Message>? history}) async {
    debugPrint('📨 [AIServiceSelector] === ENVIANDO MENSAJE ===');
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
      case AIProvider.localLLM:
        return await _sendToLocalLLM(message, history);
    }
  }
  
  // Enviar a Gemini
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
  
  // Enviar a Ollama (servidor remoto)
  Future<String> _sendToOllama(String message, List<Message>? history) async {
    try {
      debugPrint('   🔍 Verificando disponibilidad del modelo $_currentOllamaModel...');
      
      // Verificar que el modelo esté disponible
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
  
  // Enviar a OpenAI
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
  
  // MODIFICADO: Enviar a Ollama Local
  Future<String> _sendToLocalLLM(String message, List<Message>? history) async {
    try {
      debugPrint('   🔍 Verificando estado de Ollama Local...');
      
      if (_localLLMStatus != OllamaLocalStatus.ready) { // CAMBIADO
        debugPrint('   ❌ Ollama Local no está listo: ${_localLLMStatus.displayText}');
        throw Exception('Ollama Local no está listo');
      }
      
      debugPrint('   ✓ Ollama Local disponible');
      debugPrint('   💭 Generando respuesta localmente...');
      
      String response;
      if (history != null && history.isNotEmpty) {
        debugPrint('   📝 Usando chat con historial (${history.length} mensajes)');
        
        // Convertir historial al formato correcto
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
        
        response = await _localLLMService.chatWithHistory(
          prompt: message,
          history: chatHistory,
        );
      } else {
        debugPrint('   💭 Usando generación simple');
        response = await _localLLMService.generateContent(message);
      }
      
      debugPrint('✅ [AIServiceSelector] Respuesta de Ollama Local recibida (${response.length} chars)');
      debugPrint('🟢 [AIServiceSelector] === ENVÍO EXITOSO ===\n');
      return response;
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error con Ollama Local: $e');
      
      // Proporcionar información de diagnóstico
      debugPrint('💡 [AIServiceSelector] DIAGNÓSTICO:');
      debugPrint('   1. Verifica que Ollama esté ejecutándose (ollama serve)');
      debugPrint('   2. Comprueba que el modelo esté descargado (ollama list)');
      debugPrint('   3. Intenta con un prompt más corto');
      
      throw Exception('Error con Ollama Local: $e');
    }
  }
  
  // Convertir historial a formato de chat para Ollama remoto
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
    _localLLMService.removeStatusListener(_onLocalLLMStatusChanged);
    _localLLMService.dispose();
    _ollamaService.dispose();
    super.dispose();
  }
}