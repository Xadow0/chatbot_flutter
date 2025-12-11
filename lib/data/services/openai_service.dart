import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_keys_manager.dart';

class OpenAIService {
  static const String _baseUrl = 'https://api.openai.com/v1';
  static const String _defaultModel = 'gpt-4o-mini';

  final ApiKeysManager _apiKeysManager = ApiKeysManager();
  String? _cachedApiKey;
  final List<Map<String, String>> _conversationHistory = [];

  OpenAIService() {
    debugPrint('🔵 [OpenAIService] Servicio inicializado');
  }

  Future<String> _getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    final key = await _apiKeysManager.getApiKey(ApiKeysManager.openaiApiKeyName);

    if (key == null || key.isEmpty) {
      throw Exception(
        'OPENAI_API_KEY no configurada. '
        'Por favor, configura tu API key en Ajustes.',
      );
    }

    _cachedApiKey = key;
    debugPrint('✅ [OpenAIService] API key cargada correctamente');
    return key;
  }

  void clearApiKeyCache() {
    _cachedApiKey = null;
    debugPrint('🗑️ [OpenAIService] Caché de API key limpiada');
  }

  Future<bool> isAvailable() async {
    try {
      final key = await _apiKeysManager.getApiKey(ApiKeysManager.openaiApiKeyName);
      return key != null && key.isNotEmpty && key.startsWith('sk-');
    } catch (e) {
      return false;
    }
  }

  static const List<String> availableModels = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-3.5-turbo',
  ];

  Stream<String> generateContentStream(String prompt) async* {
    debugPrint('🌊 [OpenAIService] generateContentStream (sin historial)');

    final apiKey = await _getApiKey();
    final client = http.Client();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/chat/completions'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      request.body = jsonEncode({
        'model': _defaultModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'Eres un asistente de IA útil y educativo especializado en enseñar sobre inteligencia artificial y prompting. Responde de manera clara, educativa y práctica.',
          },
          {
            'role': 'user',
            'content': prompt,
          }
        ],
        'stream': true,
        'temperature': 0.7,
        'max_tokens': 4096,
      });

      final response = await client.send(request).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('Error HTTP ${response.statusCode}');
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty || chunk.trim() == 'data: [DONE]') continue;

        final line = chunk.startsWith('data: ') ? chunk.substring(6) : chunk;
        if (line.trim().isEmpty) continue;

        try {
          final data = jsonDecode(line);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              yield content;
            }
          }
        } catch (e) {
          debugPrint('   ⚠️ Error parseando chunk: $e');
        }
      }

      debugPrint('✅ [OpenAIService] Stream completado');
    } finally {
      client.close();
    }
  }

  Stream<String> generateContentStreamContext(String prompt) async* {
    debugPrint('🌊 [OpenAIService] generateContentStreamContext');
    debugPrint('   📚 Historial: ${_conversationHistory.length} mensajes');

    _conversationHistory.add({
      'role': 'user',
      'content': prompt,
    });

    final apiKey = await _getApiKey();
    final client = http.Client();
    final fullResponse = StringBuffer();
    bool hasError = false;

    try {
      final messagesWithSystem = [
        {
          'role': 'system',
          'content':
              'Eres un asistente de IA útil y educativo especializado en enseñar sobre inteligencia artificial y prompting. Responde de manera clara, educativa y práctica.',
        },
        ..._conversationHistory,
      ];

      final request = http.Request(
        'POST',
        Uri.parse('$_baseUrl/chat/completions'),
      );
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      request.body = jsonEncode({
        'model': _defaultModel,
        'messages': messagesWithSystem,
        'stream': true,
        'temperature': 0.7,
        'max_tokens': 4096,
      });

      final response = await client.send(request).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        hasError = true;
        throw Exception('Error HTTP ${response.statusCode}');
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty || chunk.trim() == 'data: [DONE]') continue;

        final line = chunk.startsWith('data: ') ? chunk.substring(6) : chunk;
        if (line.trim().isEmpty) continue;

        try {
          final data = jsonDecode(line);
          final choices = data['choices'] as List?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            final content = delta?['content'] as String?;
            if (content != null && content.isNotEmpty) {
              fullResponse.write(content);
              yield content;
            }
          }
        } catch (e) {
          debugPrint('   ⚠️ Error parseando chunk: $e');
        }
      }

      _conversationHistory.add({
        'role': 'assistant',
        'content': fullResponse.toString(),
      });

      debugPrint('✅ [OpenAIService] Stream completado: ${fullResponse.length} caracteres');
    } catch (e) {
      hasError = true;
      debugPrint('❌ [OpenAIService] Error en stream: $e');
      rethrow;
    } finally {
      client.close();
      if (hasError && _conversationHistory.isNotEmpty) {
        _conversationHistory.removeLast();
      }
    }
  }

  void clearConversation() {
    _conversationHistory.clear();
    debugPrint('🧹 [OpenAIService] Historial de conversación limpiado');
  }

  void addUserMessage(String content) {
    _conversationHistory.add({
      'role': 'user',
      'content': content,
    });
    debugPrint('📝 [OpenAIService] Mensaje de usuario añadido al historial');
  }

  void addBotMessage(String content) {
    _conversationHistory.add({
      'role': 'assistant',
      'content': content,
    });
    debugPrint('📝 [OpenAIService] Mensaje del bot añadido al historial');
  }

  bool isModelAvailable(String modelName) {
    return availableModels.contains(modelName);
  }
}