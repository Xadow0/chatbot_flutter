import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_keys_manager.dart';

class GeminiService {
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1';
  static const String _model = 'gemini-2.5-flash';
  
  final ApiKeysManager _apiKeysManager = ApiKeysManager();
  String? _cachedApiKey;

  /// Historial de conversación (contexto persistente por sesión)
  final List<Map<String, dynamic>> _conversationHistory = [];

  GeminiService() {
    debugPrint('🔵 [GeminiService] Servicio inicializado');
  }

  Future<String> _getApiKey() async {
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    final key = await _apiKeysManager.getApiKey(ApiKeysManager.geminiApiKeyName);
    if (key == null || key.isEmpty) {
      throw Exception('GEMINI_API_KEY no configurada. Configúrala en Ajustes.');
    }

    _cachedApiKey = key;
    return key;
  }

  void clearApiKeyCache() {
    _cachedApiKey = null;
  }

  Future<bool> isAvailable() async {
    try {
      final key = await _apiKeysManager.getApiKey(ApiKeysManager.geminiApiKeyName);
      return key != null && key.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Petición SIN historial (prompt aislado)
  Future<String> generateContent(String prompt) async {
    return _sendRequest(
      contents: [
        {
          'role': 'user',
          'parts': [{'text': prompt}]
        }
      ],
    );
  }

  /// NUEVO: Petición CON historial (mantiene contexto)
  Future<String> generateContentContext(String prompt) async {
    debugPrint('💬 [GeminiService] generateContentContext llamado');

    // Añadimos el nuevo turno del usuario al historial
    _conversationHistory.add({
      'role': 'user',
      'parts': [{'text': prompt}],
    });

    // Enviamos todo el historial (hasta ahora)
    final responseText = await _sendRequest(contents: _conversationHistory);

    // Añadimos la respuesta del modelo al historial
    _conversationHistory.add({
      'role': 'model',
      'parts': [{'text': responseText}],
    });

    return responseText;
  }

  /// Limpiar historial de conversación
  void clearConversation() {
    _conversationHistory.clear();
    debugPrint('🧹 [GeminiService] Historial de conversación limpiado');
  }

  /// --- MÉTODO INTERNO COMÚN PARA ENVIAR A LA API ---
  Future<String> _sendRequest({required List<Map<String, dynamic>> contents}) async {
    try {
      final apiKey = await _getApiKey();
      final url = Uri.parse('$_baseUrl/models/$_model:generateContent?key=$apiKey');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': contents,
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 4096,
          },
          'safetySettings': [
            {
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_SEXUALLY_EXPLICIT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
            {
              'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
              'threshold': 'BLOCK_MEDIUM_AND_ABOVE'
            },
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null) {
          final parts = data['candidates'][0]['content']['parts'];
          if (parts != null && parts.isNotEmpty) {
            return parts[0]['text'] ?? 'Sin respuesta';
          }
        }
        return 'No se pudo obtener una respuesta válida';
      } else if (response.statusCode == 401) {
        throw Exception('API Key de Gemini inválida o expirada.');
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Error de API: ${error['error']['message']}');
      }
    } catch (e) {
      debugPrint('❌ [GeminiService] Error: $e');
      throw Exception('Error al conectar con Gemini: $e');
    }
  }

  /// Placeholder para streaming
  Stream<String> generateContentStream(String prompt) async* {
    yield await generateContent(prompt);
  }
}
