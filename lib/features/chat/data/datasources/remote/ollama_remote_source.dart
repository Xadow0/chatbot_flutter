import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../models/remote_ollama_models.dart';

class OllamaService {
  late final String _tailscaleUrl;
  late final String _fallbackUrl;

  late String _baseUrl;
  final String? _apiKey;
  final Duration _timeout = const Duration(seconds: 60);
  final List<ChatMessage> _conversationHistory = [];

  ConnectionInfo _connectionInfo = ConnectionInfo(
    status: ConnectionStatus.disconnected,
    url: '',
    isHealthy: false,
  );

  final _connectionController = StreamController<ConnectionInfo>.broadcast();

  OllamaService({String? apiKey}) : _apiKey = apiKey {
    _tailscaleUrl = dotenv.env['TAILSCALE_URL'] ?? 'http://100.125.201.64:3001';
    _fallbackUrl = dotenv.env['FALLBACK_URL'] ?? 'http://192.168.1.100:3001';

    _baseUrl = _tailscaleUrl;

    debugPrint('🔧 [OllamaService] Configuración de URLs:');
    debugPrint('   📍 Tailscale: $_tailscaleUrl');
    debugPrint('   📍 Fallback: $_fallbackUrl');

    _initializeConnectionAsync();
  }

  ConnectionInfo get connectionInfo => _connectionInfo;
  Stream<ConnectionInfo> get connectionStream => _connectionController.stream;
  String get baseUrl => _baseUrl;

  void _initializeConnectionAsync() {
    debugPrint('🔷 [OllamaService] Iniciando conexión...');
    Future.microtask(() => _detectBestConnection());
  }

  Future<void> _detectBestConnection() async {
    debugPrint('🔍 [OllamaService] Detectando mejor conexión...');
    _updateConnectionStatus(ConnectionStatus.connecting, _tailscaleUrl);

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none) || connectivityResult.isEmpty) {
      debugPrint('❌ [OllamaService] Sin conexión a internet');
      _updateConnectionStatus(
        ConnectionStatus.error,
        _tailscaleUrl,
        errorMessage: 'Sin conexión a internet',
      );
      return;
    }

    debugPrint('📶 [OllamaService] Conectividad: $connectivityResult');

    debugPrint('🔗 [OllamaService] Probando conexión Tailscale: $_tailscaleUrl');
    if (await _testConnection(_tailscaleUrl)) {
      _baseUrl = _tailscaleUrl;
      debugPrint('✅ [OllamaService] Conexión Tailscale establecida');
      final health = await _getHealthData(_tailscaleUrl);
      _updateConnectionStatus(
        ConnectionStatus.connected,
        _tailscaleUrl,
        isHealthy: true,
        healthData: health,
      );
      return;
    }

    debugPrint('🔗 [OllamaService] Probando conexión local: $_fallbackUrl');
    if (await _testConnection(_fallbackUrl)) {
      _baseUrl = _fallbackUrl;
      debugPrint('✅ [OllamaService] Conexión local establecida');
      final health = await _getHealthData(_fallbackUrl);
      _updateConnectionStatus(
        ConnectionStatus.connected,
        _fallbackUrl,
        isHealthy: true,
        healthData: health,
      );
      return;
    }

    debugPrint('❌ [OllamaService] No se puede conectar al servidor');
    _updateConnectionStatus(
      ConnectionStatus.error,
      _tailscaleUrl,
      errorMessage: 'No se puede conectar al servidor',
    );
  }

  Future<bool> _testConnection(String url) async {
    try {
      debugPrint('   🔌 Probando: $url/api/health');
      final response = await http
          .get(
            Uri.parse('$url/api/health'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 3));

      final success = response.statusCode == 200;
      debugPrint('   ${success ? "✓" : "✗"} Estado: ${response.statusCode}');
      return success;
    } catch (e) {
      debugPrint('   ✗ Error: $e');
      return false;
    }
  }

  Future<OllamaHealthResponse?> _getHealthData(String url) async {
    try {
      final response = await http
          .get(
            Uri.parse('$url/api/health'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return OllamaHealthResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint('   ⚠️ No se pudo obtener health data: $e');
    }
    return null;
  }

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

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_apiKey != null) headers['X-API-Key'] = _apiKey;
    return headers;
  }

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

  Future<OllamaHealthResponse> checkHealth() async {
    try {
      debugPrint('💓 [OllamaService] Verificando salud del servidor...');
      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/health'),
            headers: _headers,
          )
          .timeout(_timeout);

      debugPrint('   📥 Status: ${response.statusCode}');
      return _handleResponse(response, (data) => OllamaHealthResponse.fromJson(data));
    } catch (e) {
      debugPrint('❌ [OllamaService] Health check falló: $e');
      await _detectBestConnection();
      rethrow;
    }
  }

  Future<List<OllamaModel>> getModels() async {
    try {
      debugPrint('📋 [OllamaService] Obteniendo lista de modelos...');

      final response = await http
          .get(
            Uri.parse('$_baseUrl/api/models'),
            headers: _headers,
          )
          .timeout(_timeout);

      debugPrint('   📥 Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body) as Map<String, dynamic>;

          List<OllamaModel> parseModelsList(Map<String, dynamic> dataMap) {
            if (dataMap.containsKey('models') && dataMap['models'] is List) {
              final modelsList = dataMap['models'] as List;
              return modelsList.map((model) => OllamaModel.fromJson(model)).toList();
            }
            throw OllamaException('La clave "models" no se encontró o no es una lista');
          }

          List<OllamaModel> models;

          if (data.containsKey('success') && data['success'] == true) {
            if (data.containsKey('models')) {
              models = parseModelsList(data);
            } else if (data.containsKey('data') && data['data'] is Map<String, dynamic>) {
              models = parseModelsList(data['data'] as Map<String, dynamic>);
            } else if (data.containsKey('ollama') && data['ollama'] is Map<String, dynamic>) {
              models = parseModelsList(data['ollama'] as Map<String, dynamic>);
            } else {
              throw OllamaException('Formato wrapper no reconocido');
            }
          } else if (data.containsKey('models')) {
            models = parseModelsList(data);
          } else {
            throw OllamaException('Formato de respuesta de modelos no reconocido');
          }

          debugPrint('   ✅ ${models.length} modelos encontrados');
          return models;
        } catch (e) {
          if (e is OllamaException) rethrow;
          throw OllamaException('Error procesando respuesta de modelos: $e');
        }
      } else {
        throw OllamaException(
          'Error del servidor obteniendo modelos: ${response.statusCode}',
          statusCode: response.statusCode,
        );
      }
    } catch (e) {
      debugPrint('❌ [OllamaService] Error obteniendo modelos: $e');
      if (e is OllamaException) rethrow;
      throw OllamaException('Error obteniendo modelos: $e');
    }
  }

  Future<bool> isModelAvailable(String modelName) async {
    try {
      final models = await getModels();
      return models.any((model) => model.name == modelName);
    } catch (e) {
      return false;
    }
  }

  void clearConversation() {
    _conversationHistory.clear();
    debugPrint('🧹 [OllamaService] Historial de conversación limpiado');
  }

  void addUserMessage(String content) {
    _conversationHistory.add(ChatMessage(
      role: 'user',
      content: content,
    ));
    debugPrint('📝 [OllamaService] Mensaje de usuario añadido al historial');
  }

  void addBotMessage(String content) {
    _conversationHistory.add(ChatMessage(
      role: 'assistant',
      content: content,
    ));
    debugPrint('📝 [OllamaService] Mensaje del bot añadido al historial');
  }

  Stream<String> generateContentStream({
    required String model,
    required String prompt,
    Map<String, dynamic>? options,
  }) async* {
    debugPrint('🌊 [OllamaService] generateContentStream (sin historial)');
    debugPrint('   🤖 Modelo: $model');

    final client = http.Client();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/api/generate'),
      );
      request.headers.addAll(_headers);
      request.body = json.encode({
        'model': model,
        'prompt': prompt,
        'stream': true,
        if (options != null) 'options': options,
      });

      final response = await client.send(request).timeout(_timeout);

      if (response.statusCode != 200) {
        throw OllamaException('Error HTTP ${response.statusCode}', statusCode: response.statusCode);
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;

        try {
          final data = json.decode(chunk) as Map<String, dynamic>;

          if (data.containsKey('choices') && data['choices'] is List) {
            final choices = data['choices'] as List;
            if (choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
            if (data['done'] == true || choices[0]['finish_reason'] != null) break;
          } else if (data.containsKey('response')) {
            final text = data['response'] as String?;
            if (text != null && text.isNotEmpty) {
              yield text;
            }
            if (data['done'] == true) break;
          }
        } catch (e) {
          debugPrint('   ⚠️ Error parseando chunk: $e');
        }
      }

      debugPrint('✅ [OllamaService] Stream completado');
    } finally {
      client.close();
    }
  }

  Stream<String> generateContentStreamContext({
    required String model,
    required String prompt,
    Map<String, dynamic>? options,
  }) async* {
    debugPrint('🌊 [OllamaService] generateContentStreamContext');
    debugPrint('   🤖 Modelo: $model');
    debugPrint('   📚 Historial: ${_conversationHistory.length} mensajes');

    _conversationHistory.add(ChatMessage(role: 'user', content: prompt));

    final messages = _conversationHistory.map((msg) => msg.toJson()).toList();

    final client = http.Client();
    final fullResponse = StringBuffer();
    bool hasError = false;

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/api/chat'),
      );
      request.headers.addAll(_headers);
      request.body = json.encode({
        'model': model,
        'messages': messages,
        'stream': true,
        if (options != null) 'options': options,
      });

      final response = await client.send(request).timeout(_timeout);

      if (response.statusCode != 200) {
        hasError = true;
        throw OllamaException('Error HTTP ${response.statusCode}', statusCode: response.statusCode);
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;

        try {
          final data = json.decode(chunk) as Map<String, dynamic>;

          if (data.containsKey('choices') && data['choices'] is List) {
            final choices = data['choices'] as List;
            if (choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;
              if (content != null && content.isNotEmpty) {
                fullResponse.write(content);
                yield content;
              }
            }
            if (data['done'] == true || choices[0]['finish_reason'] != null) break;
          } else if (data.containsKey('message')) {
            final message = data['message'] as Map<String, dynamic>?;
            final text = message?['content'] as String?;
            if (text != null && text.isNotEmpty) {
              fullResponse.write(text);
              yield text;
            }
            if (data['done'] == true) break;
          }
        } catch (e) {
          debugPrint('   ⚠️ Error parseando chunk: $e');
        }
      }

      _conversationHistory.add(ChatMessage(role: 'assistant', content: fullResponse.toString()));

      debugPrint('✅ [OllamaService] Stream completado: ${fullResponse.length} chars');
    } catch (e) {
      hasError = true;
      debugPrint('❌ [OllamaService] Error en stream: $e');
      rethrow;
    } finally {
      client.close();
      if (hasError && _conversationHistory.isNotEmpty) {
        _conversationHistory.removeLast();
      }
    }
  }

  Future<void> reconnect() async {
    debugPrint('🔄 [OllamaService] Reconectando...');
    await _detectBestConnection();
  }

  Future<void> setCustomUrl(String url) async {
    debugPrint('🔧 [OllamaService] Configurando URL personalizada: $url');
    _baseUrl = url;
    await _detectBestConnection();
  }

  void dispose() {
    debugPrint('🔴 [OllamaService] Cerrando conexión...');
    _connectionController.close();
  }
}