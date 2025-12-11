import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'api_keys_manager.dart';

class GeminiService {
  static const String _modelName = 'gemini-2.5-flash';

  final ApiKeysManager _apiKeysManager = ApiKeysManager();
  GenerativeModel? _model;
  String? _cachedApiKey;
  final List<Content> _conversationHistory = [];

  GeminiService() {
    debugPrint('🔵 [GeminiService] Servicio inicializado (SDK oficial)');
  }

  Future<void> _ensureInitialized() async {
    if (_model != null) return;

    final apiKey = await _getApiKey();

    _model = GenerativeModel(
      model: _modelName,
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 4096,
      ),
      safetySettings: [
        SafetySetting(HarmCategory.harassment, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.sexuallyExplicit, HarmBlockThreshold.medium),
        SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.medium),
      ],
    );

    debugPrint('✅ [GeminiService] Modelo inicializado: $_modelName');
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
    _model = null;
  }

  Future<bool> isAvailable() async {
    try {
      final key = await _apiKeysManager.getApiKey(ApiKeysManager.geminiApiKeyName);
      return key != null && key.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Stream<String> generateContentStream(String prompt) async* {
    await _ensureInitialized();

    debugPrint('🌊 [GeminiService] generateContentStream (sin historial)');

    try {
      final responses = _model!.generateContentStream([Content.text(prompt)]);

      await for (final response in responses) {
        final text = response.text;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      }

      debugPrint('✅ [GeminiService] Stream completado');
    } catch (e) {
      debugPrint('❌ [GeminiService] Error en stream: $e');
      throw Exception('Error en streaming de Gemini: $e');
    }
  }

  Stream<String> generateContentStreamContext(String prompt) async* {
    await _ensureInitialized();

    debugPrint('🌊 [GeminiService] generateContentStreamContext');
    debugPrint('   📚 Historial: ${_conversationHistory.length} mensajes');

    _conversationHistory.add(Content.text(prompt));

    final fullResponse = StringBuffer();
    bool hasError = false;

    try {
      final responses = _model!.generateContentStream(_conversationHistory);

      await for (final response in responses) {
        final text = response.text;
        if (text != null && text.isNotEmpty) {
          fullResponse.write(text);
          yield text;
        }
      }

      _conversationHistory.add(Content.model([TextPart(fullResponse.toString())]));
      debugPrint('✅ [GeminiService] Stream completado: ${fullResponse.length} caracteres');
    } catch (e) {
      hasError = true;
      debugPrint('❌ [GeminiService] Error en stream: $e');
      throw Exception('Error en streaming de Gemini: $e');
    } finally {
      if (hasError && _conversationHistory.isNotEmpty) {
        _conversationHistory.removeLast();
      }
    }
  }

  void clearConversation() {
    _conversationHistory.clear();
    debugPrint('🧹 [GeminiService] Historial limpiado');
  }

  void addUserMessage(String content) {
    _conversationHistory.add(Content.text(content));
    debugPrint('📝 [GeminiService] Mensaje de usuario añadido al historial');
  }

  void addBotMessage(String content) {
    _conversationHistory.add(Content.model([TextPart(content)]));
    debugPrint('📝 [GeminiService] Mensaje del bot añadido al historial');
  }
}