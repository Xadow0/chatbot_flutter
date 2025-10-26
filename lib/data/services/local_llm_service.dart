import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ollama_local_models.dart';

/// Servicio para ejecutar modelos LLM localmente usando Ollama
/// 
/// Este servicio se conecta a una instancia de Ollama ejecutándose localmente
/// en la máquina del usuario (http://localhost:11434)
/// 
/// Requisitos:
/// - Ollama instalado en la máquina local
/// - Ejecutar 'ollama serve' antes de usar
/// - Descargar modelos con 'ollama pull phi3' (u otros modelos)
class LocalLLMService {
  OllamaLocalStatus _status = OllamaLocalStatus.stopped;
  String? _errorMessage;
  
  final OllamaLocalConfig _config;
  String _currentModel;
  List<String> _availableModels = [];
  
  final List<ValueChanged<OllamaLocalStatus>> _statusListeners = [];
  
  /// Constructor con configuración opcional
  LocalLLMService({
    OllamaLocalConfig? config,
    String? initialModel,
  }) : _config = config ?? const OllamaLocalConfig(),
       _currentModel = initialModel ?? const OllamaLocalConfig().defaultModel {
    debugPrint('🤖 [LocalLLMService] Servicio Ollama Local inicializado');
    debugPrint('   🌐 URL base: ${_config.baseUrl}');
    debugPrint('   📦 Modelo por defecto: $_currentModel');
  }

  // Getters
  OllamaLocalStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => _status == OllamaLocalStatus.ready;
  bool get isConnecting => _status == OllamaLocalStatus.connecting;
  String get currentModel => _currentModel;
  List<String> get availableModels => _availableModels;
  OllamaLocalConfig get config => _config;

  // Listeners
  void addStatusListener(ValueChanged<OllamaLocalStatus> listener) {
    _statusListeners.add(listener);
  }

  void removeStatusListener(ValueChanged<OllamaLocalStatus> listener) {
    _statusListeners.remove(listener);
  }

  void _notifyStatusChange(OllamaLocalStatus newStatus) {
    _status = newStatus;
    for (var listener in _statusListeners) {
      listener(newStatus);
    }
  }

  /// Inicializar conexión con Ollama Local
  Future<OllamaLocalInitResult> initializeModel({
    String? modelName,
  }) async {
    try {
      debugPrint('🚀 [LocalLLMService] === INICIANDO CONEXIÓN CON OLLAMA LOCAL ===');
      _notifyStatusChange(OllamaLocalStatus.connecting);
      _errorMessage = null;

      // Usar modelo especificado o el actual
      final targetModel = modelName ?? _currentModel;

      // 1. Verificar que Ollama esté ejecutándose
      debugPrint('   💓 Verificando servidor Ollama...');
      final isRunning = await _checkOllamaRunning();
      if (!isRunning) {
        throw OllamaLocalException(
          'Ollama no está ejecutándose',
          details: 'Ejecuta "ollama serve" en tu terminal',
        );
      }
      debugPrint('   ✅ Servidor Ollama activo');

      // 2. Obtener lista de modelos disponibles
      debugPrint('   📋 Cargando modelos disponibles...');
      _availableModels = await _getAvailableModels();
      debugPrint('   ✅ Modelos encontrados: ${_availableModels.join(", ")}');

      // 3. Verificar que el modelo objetivo esté disponible
      if (!_availableModels.contains(targetModel)) {
        // Si no está disponible y hay otros modelos, usar el primero
        if (_availableModels.isNotEmpty) {
          debugPrint('   ⚠️ Modelo "$targetModel" no encontrado, usando "${_availableModels.first}"');
          _currentModel = _availableModels.first;
        } else {
          throw OllamaLocalException(
            'Modelo no encontrado',
            details: targetModel,
          );
        }
      } else {
        _currentModel = targetModel;
        debugPrint('   ✅ Modelo "$_currentModel" disponible');
      }

      // 4. Hacer una prueba rápida de inferencia
      debugPrint('   🧪 Realizando test de inferencia...');
      final testSuccess = await _testInference();
      if (!testSuccess) {
        throw OllamaLocalException(
          'Error en test de inferencia',
          details: 'El modelo no responde correctamente',
        );
      }
      debugPrint('   ✅ Test de inferencia exitoso');

      debugPrint('🟢 [LocalLLMService] === OLLAMA LOCAL LISTO ===\n');
      _notifyStatusChange(OllamaLocalStatus.ready);
      
      return OllamaLocalInitResult(
        success: true,
        modelName: _currentModel,
        availableModels: _availableModels,
      );

    } on OllamaLocalException catch (e) {
      debugPrint('❌ [LocalLLMService] Error conocido: ${e.message}');
      debugPrint('   💡 Detalles: ${e.details}');
      _errorMessage = e.userFriendlyMessage;
      _notifyStatusChange(OllamaLocalStatus.error);
      
      return OllamaLocalInitResult(
        success: false,
        error: e.userFriendlyMessage,
      );

    } catch (e) {
      debugPrint('❌ [LocalLLMService] Error inesperado: $e');
      _errorMessage = 'Error al inicializar: $e';
      _notifyStatusChange(OllamaLocalStatus.error);
      
      return OllamaLocalInitResult(
        success: false,
        error: 'Error al conectar con Ollama: $e',
      );
    }
  }

  /// Generar contenido usando el modelo actual
  Future<String> generateContent(
    String prompt, {
    double temperature = 0.7,
    int maxTokens = 2048,
    String? systemPrompt,
  }) async {
    if (_status != OllamaLocalStatus.ready) {
      throw OllamaLocalException(
        'Ollama no está listo',
        details: 'Estado actual: ${_status.displayText}',
      );
    }

    try {
      debugPrint('🔵 [LocalLLMService] === GENERANDO RESPUESTA ===');
      debugPrint('   🤖 Modelo: $_currentModel');
      debugPrint('   💬 Prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}');
      debugPrint('   🌡️ Temperature: $temperature');
      debugPrint('   📊 Max tokens: $maxTokens');

      final url = Uri.parse('${_config.baseUrl}/api/generate');
      
      final requestBody = {
        'model': _currentModel,
        'prompt': prompt,
        'stream': false,
        'options': {
          'temperature': temperature,
          'num_predict': maxTokens,
        },
      };

      // Agregar system prompt si se proporciona
      if (systemPrompt != null) {
        requestBody['system'] = systemPrompt;
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['response'] != null) {
          final content = data['response'] as String;
          debugPrint('   ✅ Respuesta generada: ${content.length} caracteres');
          debugPrint('🟢 [LocalLLMService] === GENERACIÓN EXITOSA ===\n');
          return content;
        } else {
          throw OllamaLocalException(
            'Respuesta inválida',
            details: 'No se encontró el campo "response" en la respuesta',
          );
        }
      } else {
        throw OllamaLocalException(
          'Error HTTP ${response.statusCode}',
          details: response.body,
        );
      }

    } on TimeoutException {
      debugPrint('⏱️ [LocalLLMService] Timeout');
      throw OllamaLocalException('Timeout');
    } catch (e) {
      debugPrint('❌ [LocalLLMService] Error en generación: $e');
      if (e is OllamaLocalException) rethrow;
      throw OllamaLocalException(
        'Error al generar respuesta',
        details: e.toString(),
      );
    }
  }

  /// Generar contenido con historial de chat
  Future<String> chatWithHistory({
    required String prompt,
    required List<Map<String, String>> history,
    double temperature = 0.7,
    int maxTokens = 2048,
  }) async {
    if (_status != OllamaLocalStatus.ready) {
      throw OllamaLocalException(
        'Ollama no está listo',
        details: 'Estado actual: ${_status.displayText}',
      );
    }

    try {
      debugPrint('💬 [LocalLLMService] === CHAT CON HISTORIAL ===');
      debugPrint('   🤖 Modelo: $_currentModel');
      debugPrint('   📝 Mensajes en historial: ${history.length}');

      final url = Uri.parse('${_config.baseUrl}/api/chat');

      // Construir mensajes en formato Ollama
      final messages = <Map<String, String>>[];
      
      // Agregar historial
      messages.addAll(history);
      
      // Agregar mensaje actual
      messages.add({'role': 'user', 'content': prompt});

      final requestBody = {
        'model': _currentModel,
        'messages': messages,
        'stream': false,
        'options': {
          'temperature': temperature,
          'num_predict': maxTokens,
        },
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['message'] != null && data['message']['content'] != null) {
          final content = data['message']['content'] as String;
          debugPrint('   ✅ Chat exitoso: ${content.length} caracteres');
          debugPrint('🟢 [LocalLLMService] === CHAT EXITOSO ===\n');
          return content;
        } else {
          throw OllamaLocalException(
            'Respuesta inválida en chat',
            details: 'Formato de respuesta desconocido',
          );
        }
      } else {
        throw OllamaLocalException(
          'Error HTTP ${response.statusCode}',
          details: response.body,
        );
      }

    } on TimeoutException {
      debugPrint('⏱️ [LocalLLMService] Timeout en chat');
      throw OllamaLocalException('Timeout');
    } catch (e) {
      debugPrint('❌ [LocalLLMService] Error en chat: $e');
      if (e is OllamaLocalException) rethrow;
      throw OllamaLocalException(
        'Error en chat',
        details: e.toString(),
      );
    }
  }

  /// Cambiar el modelo actual
  Future<bool> changeModel(String modelName) async {
    try {
      debugPrint('🔄 [LocalLLMService] Cambiando modelo a: $modelName');
      
      // Verificar que el modelo esté disponible
      if (!_availableModels.contains(modelName)) {
        debugPrint('   ❌ Modelo no disponible');
        throw OllamaLocalException(
          'Modelo no encontrado',
          details: modelName,
        );
      }

      _currentModel = modelName;
      debugPrint('   ✅ Modelo cambiado a: $_currentModel');
      
      // Hacer un test rápido
      final testSuccess = await _testInference();
      if (!testSuccess) {
        throw OllamaLocalException(
          'Error al cambiar modelo',
          details: 'El modelo no responde',
        );
      }

      return true;
    } catch (e) {
      debugPrint('❌ [LocalLLMService] Error cambiando modelo: $e');
      return false;
    }
  }

  /// Detener el servicio (liberar recursos)
  Future<void> stopModel() async {
    try {
      debugPrint('🛑 [LocalLLMService] Deteniendo servicio...');
      
      _notifyStatusChange(OllamaLocalStatus.stopped);
      _errorMessage = null;
      
      debugPrint('   ✅ Servicio detenido');
      
    } catch (e) {
      debugPrint('⚠️ [LocalLLMService] Error al detener: $e');
      _errorMessage = 'Error al detener el servicio';
      _notifyStatusChange(OllamaLocalStatus.error);
    }
  }

  /// Reintentar inicialización
  Future<OllamaLocalInitResult> retry() async {
    debugPrint('🔄 [LocalLLMService] Reintentando inicialización...');
    return await initializeModel();
  }

  // ==================== MÉTODOS PRIVADOS ====================

  /// Verificar si Ollama está ejecutándose
  Future<bool> _checkOllamaRunning() async {
    try {
      final url = Uri.parse('${_config.baseUrl}/api/version');
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('   ❌ Error verificando Ollama: $e');
      return false;
    }
  }

  /// Obtener lista de modelos disponibles
  Future<List<String>> _getAvailableModels() async {
    try {
      final url = Uri.parse('${_config.baseUrl}/api/tags');
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['models'] != null) {
          final models = (data['models'] as List)
              .map((model) => model['name'] as String)
              .toList();
          return models;
        }
      }
      return [];
    } catch (e) {
      debugPrint('   ⚠️ Error obteniendo modelos: $e');
      return [];
    }
  }

  /// Test rápido de inferencia
  Future<bool> _testInference() async {
    try {
      final url = Uri.parse('${_config.baseUrl}/api/generate');
      
      final requestBody = {
        'model': _currentModel,
        'prompt': 'Hi',
        'stream': false,
        'options': {
          'num_predict': 10, // Solo 10 tokens para ser rápido
        },
      };

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('   ❌ Test de inferencia falló: $e');
      return false;
    }
  }

  /// Liberar recursos
  void dispose() {
    debugPrint('🧹 [LocalLLMService] Liberando recursos...');
    _statusListeners.clear();
    unawaited(stopModel());
  }
}