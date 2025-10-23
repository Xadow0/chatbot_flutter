import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/ollama_models.dart';

class OllamaService {
  // URLs desde .env
  late final String _tailscaleUrl;
  late final String _fallbackUrl;
  
  late String _baseUrl;
  final String? _apiKey;
  final Duration _timeout = const Duration(seconds: 60);
  
  // Estado de conexión
  ConnectionInfo _connectionInfo = ConnectionInfo(
    status: ConnectionStatus.disconnected,
    url: '',
    isHealthy: false,
  );
  
  // Stream controller para notificar cambios de estado
  final _connectionController = StreamController<ConnectionInfo>.broadcast();
  
  OllamaService({String? apiKey}) : _apiKey = apiKey {
    // Leer URLs desde .env
    _tailscaleUrl = dotenv.env['TAILSCALE_URL'] ?? 'http://100.125.201.64:3001';
    _fallbackUrl = dotenv.env['FALLBACK_URL'] ?? 'http://192.168.1.100:3001';
    
    _baseUrl = _tailscaleUrl;
    
    debugPrint('🔧 [OllamaService] Configuración de URLs:');
    debugPrint('   📍 Tailscale: $_tailscaleUrl');
    debugPrint('   📍 Fallback: $_fallbackUrl');
    
    _initializeConnection();
  }
  
  // Getters
  ConnectionInfo get connectionInfo => _connectionInfo;
  Stream<ConnectionInfo> get connectionStream => _connectionController.stream;
  String get baseUrl => _baseUrl;
  
  // Inicializar conexión
  Future<void> _initializeConnection() async {
    debugPrint('🔷 [OllamaService] Iniciando conexión...');
    await _detectBestConnection();
  }
  
  // Auto-detectar mejor conexión
  Future<void> _detectBestConnection() async {
    debugPrint('🔍 [OllamaService] Detectando mejor conexión...');
    _updateConnectionStatus(ConnectionStatus.connecting, _tailscaleUrl);
    
    // Verificar conectividad de red
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint('❌ [OllamaService] Sin conexión a internet');
      _updateConnectionStatus(
        ConnectionStatus.error, 
        _tailscaleUrl,
        errorMessage: 'Sin conexión a internet'
      );
      return;
    }
    
    debugPrint('📶 [OllamaService] Conectividad: $connectivityResult');
    
    // Intentar Tailscale primero
    debugPrint('🔗 [OllamaService] Probando conexión Tailscale: $_tailscaleUrl');
    if (await _testConnection(_tailscaleUrl)) {
      _baseUrl = _tailscaleUrl;
      debugPrint('✅ [OllamaService] Conexión Tailscale establecida');
      final health = await _getHealthData(_tailscaleUrl);
      _updateConnectionStatus(
        ConnectionStatus.connected, 
        _tailscaleUrl,
        isHealthy: true,
        healthData: health
      );
      return;
    }
    
    // Intentar conexión local como backup
    debugPrint('🔗 [OllamaService] Probando conexión local: $_fallbackUrl');
    if (await _testConnection(_fallbackUrl)) {
      _baseUrl = _fallbackUrl;
      debugPrint('✅ [OllamaService] Conexión local establecida');
      final health = await _getHealthData(_fallbackUrl);
      _updateConnectionStatus(
        ConnectionStatus.connected, 
        _fallbackUrl,
        isHealthy: true,
        healthData: health
      );
      return;
    }
    
    // No hay conexión disponible
    debugPrint('❌ [OllamaService] No se puede conectar al servidor');
    debugPrint('💡 [OllamaService] Solución: Verifica que:');
    debugPrint('   1. El servidor esté ejecutándose en la torre');
    debugPrint('   2. Tailscale esté activo en ambos dispositivos');
    debugPrint('   3. La IP $_tailscaleUrl sea correcta');
    _updateConnectionStatus(
      ConnectionStatus.error, 
      _tailscaleUrl,
      errorMessage: 'No se puede conectar al servidor'
    );
  }
  
  // Probar conexión a una URL
  Future<bool> _testConnection(String url) async {
    try {
      debugPrint('   🔌 Probando: $url/api/health');
      final response = await http.get(
        Uri.parse('$url/api/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      
      final success = response.statusCode == 200;
      debugPrint('   ${success ? "✓" : "✗"} Estado: ${response.statusCode}');
      return success;
    } catch (e) {
      debugPrint('   ✗ Error: $e');
      return false;
    }
  }
  
  // Obtener datos de salud
  Future<OllamaHealthResponse?> _getHealthData(String url) async {
    try {
      final response = await http.get(
        Uri.parse('$url/api/health'),
        headers: _headers,
      ).timeout(const Duration(seconds: 8));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('   💚 Health data: ${data.toString().substring(0, data.toString().length > 100 ? 100 : data.toString().length)}');
        return OllamaHealthResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint('   ⚠️ No se pudo obtener health data: $e');
    }
    return null;
  }
  
  // Actualizar estado de conexión
  void _updateConnectionStatus(
    ConnectionStatus status, 
    String url, {
    bool isHealthy = false,
    String? errorMessage,
    OllamaHealthResponse? healthData,
  }) {
    _connectionInfo = ConnectionInfo(
      status: status,
      url: url,
      isHealthy: isHealthy,
      errorMessage: errorMessage,
      healthData: healthData,
    );
    _connectionController.add(_connectionInfo);
    debugPrint('📊 [OllamaService] Estado: $status | URL: $url | Healthy: $isHealthy');
  }
  
  // Headers para requests
  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_apiKey != null) headers['X-API-Key'] = _apiKey!;
    return headers;
  }
  
  // Manejar respuesta HTTP (para endpoints que usan formato estándar)
  T _handleResponse<T>(http.Response response, T Function(Map<String, dynamic>) parser) {
    if (response.statusCode == 200) {
      try {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return parser(data);
        } else {
          throw OllamaException(
            data['error'] ?? 'Error desconocido del servidor',
            statusCode: response.statusCode,
          );
        }
      } catch (e) {
        if (e is OllamaException) rethrow;
        throw OllamaException('Error procesando respuesta: $e');
      }
    } else {
      throw OllamaException(
        'Error del servidor: ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
  }
  
  // Health Check
  Future<OllamaHealthResponse> checkHealth() async {
    try {
      debugPrint('💓 [OllamaService] Verificando salud del servidor...');
      final response = await http.get(
        Uri.parse('$_baseUrl/api/health'),
        headers: _headers,
      ).timeout(_timeout);
      
      debugPrint('   📥 Status: ${response.statusCode}');
      return _handleResponse(response, (data) => OllamaHealthResponse.fromJson(data));
    } catch (e) {
      debugPrint('❌ [OllamaService] Health check falló: $e');
      // Si falla, intentar reconectar
      await _detectBestConnection();
      rethrow;
    }
  }
  
  // Listar modelos disponibles
  Future<List<OllamaModel>> getModels() async {
    try {
      debugPrint('📋 [OllamaService] Obteniendo lista de modelos...');
      final response = await http.get(
        Uri.parse('$_baseUrl/api/models'),
        headers: _headers,
      ).timeout(_timeout);
      
      debugPrint('   📥 Status: ${response.statusCode}');
      
      final models = _handleResponse(response, (data) {
        return (data['models'] as List)
            .map((model) => OllamaModel.fromJson(model))
            .toList();
      });
      
      debugPrint('   ✅ ${models.length} modelos encontrados');
      for (var model in models) {
        debugPrint('      • ${model.name}');
      }
      
      return models;
    } catch (e) {
      debugPrint('❌ [OllamaService] Error obteniendo modelos: $e');
      throw OllamaException('Error obteniendo modelos: $e');
    }
  }
  
  // Verificar si un modelo está disponible
  Future<bool> isModelAvailable(String modelName) async {
    try {
      debugPrint('🔍 [OllamaService] Verificando disponibilidad de modelo: $modelName');
      
      // En lugar de hacer petición individual, obtener lista de modelos
      final models = await getModels();
      final available = models.any((model) => model.name == modelName);
      
      debugPrint('   ${available ? "✅" : "❌"} Modelo $modelName ${available ? "disponible" : "no disponible"}');
      return available;
    } catch (e) {
      debugPrint('   ⚠️ Error verificando modelo: $e');
      return false;
    }
  }
  
  // Generar respuesta simple
  Future<String> generateResponse({
    required String model,
    required String prompt,
    String? systemPrompt,
    Map<String, dynamic>? options,
  }) async {
    try {
      debugPrint('🔵 [OllamaService] === INICIANDO GENERACIÓN ===');
      debugPrint('   📍 URL: $_baseUrl/api/generate');
      debugPrint('   🤖 Modelo: $model');
      debugPrint('   💬 Prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}');
      if (systemPrompt != null) {
        debugPrint('   🎯 System: ${systemPrompt.length > 50 ? "${systemPrompt.substring(0, 50)}..." : systemPrompt}');
      }
      
      final requestBody = {
        'model': model,
        'prompt': prompt,
        'stream': false,
        if (systemPrompt != null) 'system': systemPrompt,
        if (options != null) 'options': options,
      };
      
      final requestBodyStr = json.encode(requestBody);
      debugPrint('   📤 Request size: ${requestBodyStr.length} bytes');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/generate'),
        headers: _headers,
        body: requestBodyStr,
      ).timeout(_timeout);
      
      debugPrint('   📥 Response status: ${response.statusCode}');
      debugPrint('   📊 Response size: ${response.body.length} bytes');
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          debugPrint('   🔍 Analizando formato de respuesta...');
          debugPrint('   📋 Keys disponibles: ${data.keys.join(", ")}');
          
          // Formato OpenAI-compatible (como tu servidor)
          // {"id":"ollama-xxx","object":"text_completion","model":"mistral","created":xxx,"choices":[{"index":0,"message":{"role":"assistant","content":"..."},"finish_reason":"stop"}]}
          if (data.containsKey('choices') && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
            debugPrint('   ✓ Formato detectado: OpenAI-compatible');
            final choice = (data['choices'] as List)[0];
            
            if (choice['message'] != null && choice['message']['content'] != null) {
              final content = choice['message']['content'] as String;
              debugPrint('   ✅ Respuesta extraída: ${content.length} caracteres');
              debugPrint('   📝 Primeros 100 chars: ${content.length > 100 ? "${content.substring(0, 100)}..." : content}');
              debugPrint('🟢 [OllamaService] === GENERACIÓN EXITOSA ===\n');
              return content;
            } else {
              debugPrint('   ⚠️ Estructura de mensaje no válida en choice');
            }
          }
          
          // Fallback para formato estándar de Ollama
          if (data.containsKey('response')) {
            debugPrint('   ✓ Formato detectado: Ollama estándar');
            final content = data['response'] as String;
            debugPrint('   ✅ Respuesta extraída: ${content.length} caracteres');
            debugPrint('🟢 [OllamaService] === GENERACIÓN EXITOSA ===\n');
            return content;
          }
          
          // Si llegamos aquí, el formato no es reconocido
          debugPrint('   ❌ Formato de respuesta no reconocido');
          debugPrint('   📄 Response body completo: ${response.body}');
          debugPrint('🔴 [OllamaService] === ERROR: FORMATO DESCONOCIDO ===\n');
          debugPrint('💡 SOLUCIÓN: Verifica que el servidor esté devolviendo el formato correcto');
          throw OllamaException('Formato de respuesta no reconocido. Keys disponibles: ${data.keys.join(", ")}');
          
        } catch (e) {
          debugPrint('   ❌ Error parseando JSON: $e');
          debugPrint('   📄 Response body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}');
          debugPrint('🔴 [OllamaService] === ERROR DE PARSING ===\n');
          throw OllamaException('Error procesando respuesta del servidor: $e');
        }
      } else {
        debugPrint('   ❌ Error HTTP ${response.statusCode}');
        debugPrint('   📄 Response: ${response.body}');
        debugPrint('🔴 [OllamaService] === ERROR HTTP ===\n');
        debugPrint('💡 SOLUCIÓN:');
        debugPrint('   - Status 404: Endpoint no encontrado, verifica la URL');
        debugPrint('   - Status 500: Error interno del servidor');
        debugPrint('   - Status 503: Servidor no disponible o modelo no cargado');
        throw OllamaException(
          'Error del servidor: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      debugPrint('⏱️ [OllamaService] Timeout después de $_timeout');
      debugPrint('💡 SOLUCIÓN: El modelo puede estar cargándose o la consulta es muy compleja');
      throw OllamaException('Timeout: El servidor tardó demasiado en responder');
    } on SocketException catch (e) {
      debugPrint('🔌 [OllamaService] Error de conexión: $e');
      debugPrint('💡 SOLUCIÓN:');
      debugPrint('   1. Verifica que Tailscale esté activo');
      debugPrint('   2. Verifica que el servidor esté corriendo en la torre');
      debugPrint('   3. Prueba con: curl http://100.125.201.64:3001/api/health');
      throw OllamaException('Error de conexión: Verifica que el servidor esté accesible via Tailscale');
    } catch (e) {
      debugPrint('❌ [OllamaService] Error inesperado: $e');
      debugPrint('🔴 [OllamaService] === ERROR INESPERADO ===\n');
      if (e is OllamaException) rethrow;
      throw OllamaException('Error generando respuesta: $e');
    }
  }
  
  // Chat con historial de mensajes
  Future<String> chatWithHistory({
    required String model,
    required List<ChatMessage> messages,
    Map<String, dynamic>? options,
  }) async {
    try {
      debugPrint('💬 [OllamaService] === INICIANDO CHAT ===');
      debugPrint('   📍 URL: $_baseUrl/api/chat');
      debugPrint('   🤖 Modelo: $model');
      debugPrint('   📝 Mensajes: ${messages.length}');
      
      final requestBody = {
        'model': model,
        'messages': messages.map((msg) => msg.toJson()).toList(),
        'stream': false,
        if (options != null) 'options': options,
      };
      
      debugPrint('   📤 Request preparado con ${messages.length} mensajes');
      
      final response = await http.post(
        Uri.parse('$_baseUrl/api/chat'),
        headers: _headers,
        body: json.encode(requestBody),
      ).timeout(_timeout);
      
      debugPrint('   📥 Response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;
          debugPrint('   🔍 Keys disponibles: ${data.keys.join(", ")}');
          
          // Formato OpenAI-compatible
          if (data.containsKey('choices') && data['choices'] is List && (data['choices'] as List).isNotEmpty) {
            debugPrint('   ✓ Formato: OpenAI-compatible');
            final choice = (data['choices'] as List)[0];
            if (choice['message'] != null && choice['message']['content'] != null) {
              final content = choice['message']['content'] as String;
              debugPrint('   ✅ Chat exitoso: ${content.length} caracteres');
              debugPrint('🟢 [OllamaService] === CHAT EXITOSO ===\n');
              return content;
            }
          }
          
          // Formato estándar Ollama
          if (data['message'] != null && data['message']['content'] != null) {
            debugPrint('   ✓ Formato: Ollama estándar (message.content)');
            final content = data['message']['content'] as String;
            debugPrint('   ✅ Chat exitoso: ${content.length} caracteres');
            debugPrint('🟢 [OllamaService] === CHAT EXITOSO ===\n');
            return content;
          }
          
          if (data.containsKey('response')) {
            debugPrint('   ✓ Formato: Ollama alternativo (response)');
            final content = data['response'] as String;
            debugPrint('   ✅ Chat exitoso: ${content.length} caracteres');
            debugPrint('🟢 [OllamaService] === CHAT EXITOSO ===\n');
            return content;
          }
          
          debugPrint('   ❌ Formato no reconocido');
          debugPrint('   📄 Response: ${response.body}');
          debugPrint('🔴 [OllamaService] === ERROR: FORMATO DESCONOCIDO ===\n');
          throw OllamaException('Formato de respuesta no reconocido en chat');
        } catch (e) {
          debugPrint('   ❌ Error parseando respuesta: $e');
          debugPrint('🔴 [OllamaService] === ERROR DE PARSING ===\n');
          throw OllamaException('Error procesando respuesta de chat: $e');
        }
      } else {
        debugPrint('   ❌ Error HTTP ${response.statusCode}');
        debugPrint('   📄 Response: ${response.body}');
        debugPrint('🔴 [OllamaService] === ERROR HTTP ===\n');
        throw OllamaException(
          'Error del servidor en chat: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      debugPrint('⏱️ [OllamaService] Chat timeout después de $_timeout');
      throw OllamaException('Timeout en chat: El servidor tardó demasiado');
    } on SocketException catch (e) {
      debugPrint('🔌 [OllamaService] Error de conexión en chat: $e');
      throw OllamaException('Error de conexión en chat');
    } catch (e) {
      debugPrint('❌ [OllamaService] Error inesperado en chat: $e');
      if (e is OllamaException) rethrow;
      throw OllamaException('Error en chat: $e');
    }
  }
  
  // Reconectar manualmente
  Future<void> reconnect() async {
    debugPrint('🔄 [OllamaService] Reconectando...');
    await _detectBestConnection();
  }
  
  // Forzar uso de URL específica
  Future<void> setCustomUrl(String url) async {
    debugPrint('🔧 [OllamaService] Configurando URL personalizada: $url');
    _baseUrl = url;
    await _detectBestConnection();
  }
  
  // Limpiar recursos
  void dispose() {
    debugPrint('🔴 [OllamaService] Cerrando conexión...');
    _connectionController.close();
  }
}