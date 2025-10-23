import 'package:flutter/foundation.dart';
import '../models/message_model.dart';
import '../models/ollama_models.dart';
import 'gemini_service.dart';
import 'ollama_service.dart';
import 'openai_service.dart';

enum AIProvider {
  gemini,
  ollama,
  openai,
}

class AIServiceSelector extends ChangeNotifier {
  final GeminiService _geminiService;
  final OllamaService _ollamaService;
  final OpenAIService _openaiService;
  
  AIProvider _currentProvider = AIProvider.gemini;
  String _currentOllamaModel = 'phi3:latest';
  String _currentOpenAIModel = 'gpt-4o-mini';
  List<OllamaModel> _availableModels = [];
  bool _ollamaAvailable = false;
  bool _openaiAvailable = false;
  
  AIServiceSelector({
    required GeminiService geminiService,
    required OllamaService ollamaService,
    required OpenAIService openaiService,
  }) : _geminiService = geminiService,
       _ollamaService = ollamaService,
       _openaiService = openaiService {
    _initializeServices();
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
  
  // Stream de estado de conexión
  Stream<ConnectionInfo> get connectionStream => _ollamaService.connectionStream;
  
  // Inicializar todos los servicios
  Future<void> _initializeServices() async {
    debugPrint('🎬 [AIServiceSelector] Inicializando servicios de IA...');
    
    // Inicializar Ollama
    await _initializeOllama();
    
    // Inicializar OpenAI
    _initializeOpenAI();
    
    debugPrint('✅ [AIServiceSelector] Servicios inicializados');
    debugPrint('   📊 Gemini: Siempre disponible');
    debugPrint('   📊 Ollama: ${_ollamaAvailable ? "Disponible" : "No disponible"}');
    debugPrint('   📊 OpenAI: ${_openaiAvailable ? "Disponible" : "No disponible"}');
  }
  
  // Inicializar Ollama
  Future<void> _initializeOllama() async {
    try {
      debugPrint('🔷 [AIServiceSelector] Inicializando Ollama...');
      await _checkOllamaAvailability();
      if (_ollamaAvailable) {
        await _loadAvailableModels();
      } else {
        debugPrint('   ⚠️ Ollama no disponible en la inicialización');
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
  
  // Verificar disponibilidad de Ollama
  Future<void> _checkOllamaAvailability() async {
    try {
      debugPrint('💓 [AIServiceSelector] Verificando disponibilidad de Ollama...');
      final health = await _ollamaService.checkHealth();
      _ollamaAvailable = health.success && health.ollamaAvailable;
      debugPrint('   ${_ollamaAvailable ? "✅" : "❌"} Ollama ${_ollamaAvailable ? "disponible" : "no disponible"}');
    } catch (e) {
      debugPrint('   ❌ Error en health check: $e');
      _ollamaAvailable = false;
    }
  }
  
  // Cargar modelos disponibles
  Future<void> _loadAvailableModels() async {
    try {
      debugPrint('📋 [AIServiceSelector] Cargando modelos disponibles...');
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
    
    if (provider == AIProvider.ollama) {
      await _checkOllamaAvailability();
      if (!_ollamaAvailable) {
        debugPrint('❌ [AIServiceSelector] No se puede cambiar a Ollama: no disponible');
        throw Exception('Ollama no está disponible. Verifica que el servidor esté accesible.');
      }
    } else if (provider == AIProvider.openai) {
      if (!_openaiAvailable) {
        debugPrint('❌ [AIServiceSelector] No se puede cambiar a OpenAI: no disponible');
        throw Exception('OpenAI no está disponible. Configura OPENAI_API_KEY en el archivo .env');
      }
    }
    
    _currentProvider = provider;
    debugPrint('✅ [AIServiceSelector] Proveedor cambiado a: $provider');
    notifyListeners();
  }
  
  // Cambiar modelo de Ollama
  Future<void> setOllamaModel(String model) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo Ollama a: $model');
    
    if (await _ollamaService.isModelAvailable(model)) {
      _currentOllamaModel = model;
      debugPrint('✅ [AIServiceSelector] Modelo Ollama cambiado a: $model');
      notifyListeners();
    } else {
      debugPrint('❌ [AIServiceSelector] Modelo $model no está disponible');
      throw Exception('Modelo $model no está disponible');
    }
  }
  
  // Cambiar modelo de OpenAI
  void setOpenAIModel(String model) {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo OpenAI a: $model');
    
    if (_openaiService.isModelAvailable(model)) {
      _currentOpenAIModel = model;
      debugPrint('✅ [AIServiceSelector] Modelo OpenAI cambiado a: $model');
      notifyListeners();
    } else {
      debugPrint('❌ [AIServiceSelector] Modelo OpenAI $model no está disponible');
      throw Exception('Modelo OpenAI $model no está disponible');
    }
  }
  
  // Refrescar estado de Ollama
  Future<void> refreshOllama() async {
    debugPrint('🔄 [AIServiceSelector] Refrescando Ollama...');
    await _ollamaService.reconnect();
    await _initializeOllama();
  }
  
  // Refrescar todos los servicios
  Future<void> refreshAllServices() async {
    debugPrint('🔄 [AIServiceSelector] Refrescando todos los servicios...');
    await _initializeServices();
  }
  
  // Enviar mensaje usando el proveedor actual
  Future<String> sendMessage(String message, {List<Message>? history}) async {
    debugPrint('\n🚀 [AIServiceSelector] === ENVIANDO MENSAJE ===');
    debugPrint('   🤖 Proveedor: $_currentProvider');
    debugPrint('   💬 Mensaje: ${message.length > 50 ? "${message.substring(0, 50)}..." : message}');
    debugPrint('   📚 Historial: ${history?.length ?? 0} mensajes');
    
    try {
      switch (_currentProvider) {
        case AIProvider.gemini:
          debugPrint('   🟦 Enviando a Gemini...');
          return await _sendToGemini(message, history);
        case AIProvider.ollama:
          debugPrint('   🟪 Enviando a Ollama...');
          return await _sendToOllama(message, history);
        case AIProvider.openai:
          debugPrint('   🟩 Enviando a OpenAI...');
          return await _sendToOpenAI(message, history);
      }
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error enviando mensaje: $e');
      debugPrint('🔴 [AIServiceSelector] === ENVÍO FALLIDO ===\n');
      rethrow;
    }
  }
  
  // Enviar a Gemini
  Future<String> _sendToGemini(String message, List<Message>? history) async {
    try {
      final response = await _geminiService.generateContent(message);
      debugPrint('✅ [AIServiceSelector] Respuesta de Gemini recibida (${response.length} chars)');
      debugPrint('🟢 [AIServiceSelector] === ENVÍO EXITOSO ===\n');
      return response;
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error con Gemini: $e');
      throw Exception('Error con Gemini: $e');
    }
  }
  
  // Enviar a Ollama
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
        // Usar chat con historial
        final chatMessages = _convertHistoryToChatMessages(history, message);
        response = await _ollamaService.chatWithHistory(
          model: _currentOllamaModel,
          messages: chatMessages,
        );
      } else {
        debugPrint('   💭 Usando generación simple');
        // Usar generación simple
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
      
      // Proporcionar información de diagnóstico
      if (e.toString().contains('connection') || e.toString().contains('Socket')) {
        debugPrint('💡 [AIServiceSelector] DIAGNÓSTICO:');
        debugPrint('   1. Verifica Tailscale en ambos dispositivos');
        debugPrint('   2. Confirma que el servidor esté corriendo');
        debugPrint('   3. Prueba: curl ${_ollamaService.baseUrl}/api/health');
      } else if (e.toString().contains('Timeout')) {
        debugPrint('💡 [AIServiceSelector] DIAGNÓSTICO:');
        debugPrint('   1. El modelo puede estar cargándose por primera vez');
        debugPrint('   2. La consulta puede ser muy compleja');
        debugPrint('   3. Intenta con un prompt más corto');
      }
      
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
        
        // Convertir historial al formato de OpenAI
        final messages = <Map<String, String>>[];
        
        // Limitar historial a últimos 10 mensajes
        final recentHistory = history.length > 10 
            ? history.sublist(history.length - 10) 
            : history;
        
        for (final msg in recentHistory) {
          messages.add({
            'role': msg.isUser ? 'user' : 'assistant',
            'content': msg.text,
          });
        }
        
        // Agregar mensaje actual
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
      
      // Proporcionar información de diagnóstico
      if (e.toString().contains('401') || e.toString().contains('inválida')) {
        debugPrint('💡 [AIServiceSelector] DIAGNÓSTICO:');
        debugPrint('   1. Verifica que OPENAI_API_KEY sea correcta en .env');
        debugPrint('   2. La API key debe empezar con "sk-"');
        debugPrint('   3. Verifica que la key tenga créditos disponibles');
      } else if (e.toString().contains('429')) {
        debugPrint('💡 [AIServiceSelector] DIAGNÓSTICO:');
        debugPrint('   1. Has excedido el límite de solicitudes');
        debugPrint('   2. Espera unos segundos antes de reintentar');
        debugPrint('   3. Considera usar un modelo más económico (gpt-3.5-turbo)');
      } else if (e.toString().contains('conexión')) {
        debugPrint('💡 [AIServiceSelector] DIAGNÓSTICO:');
        debugPrint('   1. Verifica tu conexión a internet');
        debugPrint('   2. OpenAI puede estar temporalmente no disponible');
      }
      
      throw Exception('Error con OpenAI: $e');
    }
  }
  
  // Convertir historial a formato de chat para Ollama
  List<ChatMessage> _convertHistoryToChatMessages(List<Message> history, String newMessage) {
    final messages = <ChatMessage>[
      ChatMessage(
        role: 'system',
        content: 'Eres un asistente de IA útil y educativo especializado en enseñar sobre inteligencia artificial y prompting. Responde de manera clara, educativa y práctica.',
      ),
    ];
    
    // Agregar historial (últimos 10 mensajes para no sobrecargar)
    final recentHistory = history.length > 10 ? history.sublist(history.length - 10) : history;
    
    debugPrint('   📚 Convirtiendo historial: ${recentHistory.length} mensajes recientes');

    for (final msg in recentHistory) {
      messages.add(ChatMessage(
        role: msg.isUser ? 'user' : 'assistant',
        content: msg.text,
      ));
    }
    
    // Agregar mensaje actual
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
    _ollamaService.dispose();
    super.dispose();
  }
}