import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class GeminiService {
  // Cambia la versión de la API a v1 (no v1beta)
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1';
  // Puedes usar 'gemini-1.5-flash' o 'gemini-pro' según disponibilidad
  static const String _model = 'gemini-2.5-flash';
  
  late final String _apiKey;

  GeminiService() {
    _apiKey = dotenv.env['GEMINI_API_KEY'] ?? '';
    if (_apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file');
    }
  }

  /// Genera contenido usando Gemini
  Future<String> generateContent(String prompt) async {
    try {
      final url = Uri.parse(
        '$_baseUrl/models/$_model:generateContent?key=$_apiKey',
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
        print('Respuesta cruda de Gemini: $data');
        
        if (data['candidates'] != null && data['candidates'].isNotEmpty) {
          final candidate = data['candidates'][0];
          if (candidate['content'] != null && 
              candidate['content']['parts'] != null &&
              candidate['content']['parts'].isNotEmpty) {
            return candidate['content']['parts'][0]['text'] ?? 'Sin respuesta';
          }
        }
        
        return 'No se pudo obtener una respuesta válida';
      } else {
        final error = jsonDecode(response.body);
        throw Exception('Error de API: ${error['error']['message']}');
      }
    } catch (e) {
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