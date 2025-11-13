import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_keys_manager.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _defaultModel = 'gpt-4o-mini'; 
  
  // Ya no cargamos la key en el constructor
  final ApiKeysManager _apiKeysManager = ApiKeysManager();
  String? _cachedApiKey;

  OpenAIService() {
    debugPrint('🔵 [OpenAIService] Servicio inicializado');
  }

  /// Obtener la API key desde el almacenamiento seguro
  Future<String> _getApiKey() async {
    // Usar caché si está disponible
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    // Cargar desde storage seguro
    final key = await _apiKeysManager.getApiKey(ApiKeysManager.openaiApiKeyName);
    
    if (key == null || key.isEmpty) {
      throw Exception(
        'OPENAI_API_KEY no configurada. '
        'Por favor, configura tu API key en Ajustes.'
      );
    }

    // Cachear la key
    _cachedApiKey = key;
    debugPrint('✅ [OpenAIService] API key cargada correctamente');
    return key;
  }

  /// Limpiar caché de API key (útil después de cambiar la key)
  void clearApiKeyCache() {
    _cachedApiKey = null;
    debugPrint('🗑️ [OpenAIService] Caché de API key limpiada');
  }

  /// Verificar si el servicio está disponible
  Future<bool> isAvailable() async {
    try {
      final key = await _apiKeysManager.getApiKey(ApiKeysManager.openaiApiKeyName);
      return key != null && key.isNotEmpty && key.startsWith('sk-');
    } catch (e) {
      return false;
    }
  }

  /// Modelos disponibles de OpenAI
  static const List<String> availableModels = [
    'gpt-4o',           // Más potente, más caro
    'gpt-4o-mini',      // Balance precio/calidad (recomendado)
    'gpt-4-turbo',      // Versión turbo de GPT-4
    'gpt-3.5-turbo',    // Más económico
  ];

  /// Genera contenido usando ChatGPT
  Future<String> generateContent(
    String prompt, {
    String? model,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    try {
      // Obtener la API key desde storage seguro
      final apiKey = await _getApiKey();

      debugPrint('🔵 [OpenAIService] === INICIANDO GENERACIÓN ===');
      debugPrint('   📍 URL: $_baseUrl/chat/completions');
      debugPrint('   🤖 Modelo: ${model ?? _defaultModel}');
      debugPrint('   💬 Prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}');
      debugPrint('   🌡️ Temperature: $temperature');
      debugPrint('   📊 Max tokens: $maxTokens');

      final url = Uri.parse('$_baseUrl/chat/completions');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model ?? _defaultModel,
          'messages': [
            {
              'role': 'system',
              'content': 'Eres un asistente de IA útil y educativo especializado en enseñar sobre inteligencia artificial y prompting. Responde de manera clara, educativa y práctica.',
            },
            {
              'role': 'user',
              'content': prompt,
            }
          ],
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('   🔥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        debugPrint('   📄 Response keys: ${data.keys.join(", ")}');

        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final content = data['choices'][0]['message']['content'] as String;
          
          // Información de uso (opcional, para debugging)
          if (data['usage'] != null) {
            final usage = data['usage'];
            debugPrint('   📊 Tokens usados:');
            debugPrint('      • Prompt: ${usage['prompt_tokens']}');
            debugPrint('      • Completion: ${usage['completion_tokens']}');
            debugPrint('      • Total: ${usage['total_tokens']}');
          }

          debugPrint('   ✅ Respuesta extraída: ${content.length} caracteres');
          debugPrint('🟢 [OpenAIService] === GENERACIÓN EXITOSA ===\n');
          return content;
        }

        debugPrint('   ❌ No se encontró contenido en la respuesta');
        throw Exception('No se pudo obtener una respuesta válida de OpenAI');
      } else if (response.statusCode == 401) {
        debugPrint('   ❌ Error 401: API Key inválida');
        // Error de autenticación específico
        throw Exception(
          'API Key de OpenAI inválida o expirada. '
          'Por favor, verifica tu clave en Ajustes.'
        );
      } else if (response.statusCode == 429) {
        debugPrint('   ❌ Error 429: Límite de rate excedido');
        debugPrint('   💡 SOLUCIÓN: Espera unos segundos antes de reintentar');
        throw Exception('Límite de solicitudes excedido. Intenta de nuevo en unos segundos.');
      } else if (response.statusCode == 500 || response.statusCode == 503) {
        debugPrint('   ❌ Error ${response.statusCode}: Servidor de OpenAI no disponible');
        throw Exception('Servidor de OpenAI temporalmente no disponible');
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Error desconocido';
        debugPrint('   ❌ Error ${response.statusCode}: $errorMessage');
        debugPrint('🔴 [OpenAIService] === ERROR HTTP ===\n');
        throw Exception('Error de API OpenAI: $errorMessage');
      }
    } on http.ClientException catch (e) {
      debugPrint('🔌 [OpenAIService] Error de conexión: $e');
      debugPrint('💡 SOLUCIÓN: Verifica tu conexión a internet');
      throw Exception('Error de conexión: Verifica tu conexión a internet');
    } catch (e) {
      debugPrint('❌ [OpenAIService] Error inesperado: $e');
      debugPrint('🔴 [OpenAIService] === ERROR INESPERADO ===\n');
      if (e is Exception) rethrow;
      throw Exception('Error al conectar con OpenAI: $e');
    }
  }

  /// Genera contenido con historial de conversación
  Future<String> chatWithHistory({
    required List<Map<String, String>> messages,
    String? model,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    try {
      // Obtener la API key desde storage seguro
      final apiKey = await _getApiKey();

      debugPrint('💬 [OpenAIService] === INICIANDO CHAT ===');
      debugPrint('   📍 URL: $_baseUrl/chat/completions');
      debugPrint('   🤖 Modelo: ${model ?? _defaultModel}');
      debugPrint('   📝 Mensajes: ${messages.length}');

      final url = Uri.parse('$_baseUrl/chat/completions');

      // Agregar mensaje de sistema al inicio si no existe
      final messagesWithSystem = [
        if (messages.isEmpty || messages.first['role'] != 'system')
          {
            'role': 'system',
            'content': 'Eres un asistente de IA útil y educativo especializado en enseñar sobre inteligencia artificial y prompting. Responde de manera clara, educativa y práctica.',
          },
        ...messages,
      ];

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model ?? _defaultModel,
          'messages': messagesWithSystem,
          'temperature': temperature,
          'max_tokens': maxTokens,
        }),
      ).timeout(const Duration(seconds: 60));

      debugPrint('   🔥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['choices'] != null && data['choices'].isNotEmpty) {
          final content = data['choices'][0]['message']['content'] as String;
          
          if (data['usage'] != null) {
            final usage = data['usage'];
            debugPrint('   📊 Total tokens: ${usage['total_tokens']}');
          }

          debugPrint('   ✅ Respuesta de chat: ${content.length} caracteres');
          debugPrint('🟢 [OpenAIService] === CHAT EXITOSO ===\n');
          return content;
        }

        throw Exception('No se pudo obtener una respuesta válida de OpenAI');
      } else if (response.statusCode == 401) {
        throw Exception(
          'API Key de OpenAI inválida o expirada. '
          'Por favor, verifica tu clave en Ajustes.'
        );
      } else {
        final errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Error desconocido';
        debugPrint('   ❌ Error ${response.statusCode}: $errorMessage');
        throw Exception('Error de API OpenAI: $errorMessage');
      }
    } catch (e) {
      debugPrint('❌ [OpenAIService] Error en chat: $e');
      if (e is Exception) rethrow;
      throw Exception('Error en chat con OpenAI: $e');
    }
  }

  /// Genera contenido en streaming (para futuras implementaciones)
  Stream<String> generateContentStream(String prompt) async* {
    // TODO: Implementar streaming para respuestas en tiempo real
    // Por ahora, devolver la respuesta completa
    final response = await generateContent(prompt);
    yield response;
  }

  /// Verificar si un modelo específico está disponible
  bool isModelAvailable(String modelName) {
    return availableModels.contains(modelName);
  }

  /// Obtener información sobre el uso de la API (opcional)
  Future<Map<String, dynamic>?> getUsageInfo() async {
    try {
      await isAvailable();
      // Nota: Este endpoint requiere permisos especiales en OpenAI
      // Por ahora, solo retornamos null
      // En el futuro se puede implementar para mostrar estadísticas de uso
      return null;
    } catch (e) {
      debugPrint('⚠️ [OpenAIService] No se pudo obtener info de uso: $e');
      return null;
    }
  }

  /// Historial de conversación para mantener contexto
  final List<Map<String, String>> _conversationHistory = [];

  /// Genera contenido manteniendo el contexto conversacional.
  /// Usa internamente chatWithHistory() pero persiste el historial entre llamadas.
  Future<String> generateContentContext(
    String prompt, {
    String? model,
    double temperature = 0.7,
    int maxTokens = 4096,
  }) async {
    debugPrint('💬 [OpenAIService] generateContentContext llamado');

    // Añadimos el turno del usuario al historial
    _conversationHistory.add({
      'role': 'user',
      'content': prompt,
    });

    // Enviamos todo el historial acumulado
    final responseText = await chatWithHistory(
      messages: List<Map<String, String>>.from(_conversationHistory),
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
    );

    // Guardamos la respuesta del asistente en el historial
    _conversationHistory.add({
      'role': 'assistant',
      'content': responseText,
    });

    return responseText;
  }

  /// Limpiar historial de conversación (como en Gemini)
  void clearConversation() {
    _conversationHistory.clear();
    debugPrint('🧹 [OpenAIService] Historial de conversación limpiado');
  }

  /// Añadir mensaje del usuario al historial (sin enviar request)
void addUserMessage(String content) {
  _conversationHistory.add({
    'role': 'user',
    'content': content,
  });
  debugPrint('📝 [OpenAIService] Mensaje de usuario añadido al historial');
}

/// Añadir mensaje del bot al historial (sin enviar request)
void addBotMessage(String content) {
  _conversationHistory.add({
    'role': 'assistant',
    'content': content,
  });
  debugPrint('📝 [OpenAIService] Mensaje del bot añadido al historial');
}
}