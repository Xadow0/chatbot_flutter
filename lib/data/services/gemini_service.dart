import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
// 🔐 MODIFICADO: Importar ApiKeysManager en lugar de dotenv
import 'api_keys_manager.dart';

class GeminiService {
  // Cambia la versión de la API a v1 (no v1beta)
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1';
  // Puedes usar 'gemini-2.5-flash' o 'gemini-pro' según disponibilidad
  static const String _model = 'gemini-2.5-flash';
  
  // 🔐 MODIFICADO: Ya no cargamos la key en el constructor
  final ApiKeysManager _apiKeysManager = ApiKeysManager();
  String? _cachedApiKey;

  GeminiService() {
    debugPrint('🔵 [GeminiService] Servicio inicializado');
  }

  /// 🔐 NUEVO: Obtener la API key desde el almacenamiento seguro
  Future<String> _getApiKey() async {
    // Usar caché si está disponible
    if (_cachedApiKey != null && _cachedApiKey!.isNotEmpty) {
      return _cachedApiKey!;
    }

    // Cargar desde storage seguro
    final key = await _apiKeysManager.getApiKey(ApiKeysManager.geminiApiKeyName);
    
    if (key == null || key.isEmpty) {
      throw Exception(
        'GEMINI_API_KEY no configurada. '
        'Por favor, configura tu API key en Ajustes.'
      );
    }

    // Cachear la key
    _cachedApiKey = key;
    debugPrint('✅ [GeminiService] API key cargada correctamente');
    return key;
  }

  /// 🔐 NUEVO: Limpiar caché de API key (útil después de cambiar la key)
  void clearApiKeyCache() {
    _cachedApiKey = null;
    debugPrint('🗑️ [GeminiService] Caché de API key limpiada');
  }

  /// 🔐 NUEVO: Verificar si el servicio está disponible
  Future<bool> isAvailable() async {
    try {
      final key = await _apiKeysManager.getApiKey(ApiKeysManager.geminiApiKeyName);
      return key != null && key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Genera contenido usando Gemini
  Future<String> generateContent(String prompt) async {
    try {
      // 🔐 MODIFICADO: Obtener la API key desde storage seguro
      final apiKey = await _getApiKey();
      
      final url = Uri.parse(
        '$_baseUrl/models/$_model:generateContent?key=$apiKey',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
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
        debugPrint('Respuesta cruda de Gemini: $data');
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];
          if (candidate['content'] != null && 
              candidate['content']['parts'] != null &&
              candidate['content']['parts'].isNotEmpty) {
            return candidate['content']['parts'][0]['text'] ?? 'Sin respuesta';
          }
        }
        
        return 'No se pudo obtener una respuesta válida';
      } else if (response.statusCode == 401) {
        // 🔐 NUEVO: Error de autenticación específico
        throw Exception(
          'API Key de Gemini inválida o expirada. '
          'Por favor, verifica tu clave en Ajustes.'
        );
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Error de API: ${error['error']['message']}');
      }
    } catch (e) {
      debugPrint('❌ [GeminiService] Error: $e');
      throw Exception('Error al conectar con Gemini: $e');
    }
  }

  /// Genera contenido en streaming (para futuras implementaciones)
  Stream<String> generateContentStream(String prompt) async* {
    // TODO: Implementar streaming para respuestas en tiempo real
    final response = await generateContent(prompt);
    yield response;
  }
}