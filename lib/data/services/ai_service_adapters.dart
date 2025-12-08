import 'package:flutter/foundation.dart';
import 'gemini_service.dart';
import 'openai_service.dart';
import 'ollama_service.dart';
import 'local_ollama_service.dart';
import '../../domain/usecases/command_processor.dart';

/// Adaptador para Gemini (streaming nativo)
class GeminiServiceAdapter implements AIServiceBase {
  final GeminiService _service;

  GeminiServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🔵 [GeminiAdapter] generateContent (CON historial)');
    return await _service.generateContentContext(prompt);
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🔵 [GeminiAdapter] generateContentWithoutHistory');
    return await _service.generateContent(prompt);
  }

  @override
  Stream<String> generateContentStream(String prompt) {
    debugPrint('🌊 [GeminiAdapter] generateContentStream (CON historial)');
    return _service.generateContentStreamContext(prompt);
  }

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) {
    debugPrint('🌊 [GeminiAdapter] generateContentStreamWithoutHistory');
    return _service.generateContentStream(prompt);
  }

  void clearConversation() {
    _service.clearConversation();
  }
}

/// Adaptador para OpenAI (fallback sin streaming real por ahora)
class OpenAIServiceAdapter implements AIServiceBase {
  final OpenAIService _service;

  OpenAIServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🟢 [OpenAIAdapter] generateContent (con historial)');
    return await _service.generateContentContext(prompt);
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🟢 [OpenAIAdapter] generateContentWithoutHistory');
    return await _service.generateContent(prompt);
  }

  @override
  Stream<String> generateContentStream(String prompt) async* {
    debugPrint('🟢 [OpenAIAdapter] generateContentStream (fallback)');
    final response = await _service.generateContentContext(prompt);
    yield response;
  }

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) async* {
    debugPrint('🟢 [OpenAIAdapter] generateContentStreamWithoutHistory (fallback)');
    final response = await _service.generateContent(prompt);
    yield response;
  }

  void clearConversation() {
    _service.clearConversation();
  }
}

/// Adaptador para Ollama remoto (fallback sin streaming real por ahora)
class OllamaServiceAdapter implements AIServiceBase {
  final OllamaService _service;
  String _currentModel;

  OllamaServiceAdapter(this._service, String initialModel)
      : _currentModel = initialModel;

  void updateModel(String modelName) {
    debugPrint('🟪 [OllamaAdapter] Actualizando modelo: $_currentModel -> $modelName');
    _currentModel = modelName;
  }

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🟪 [OllamaAdapter] generateContent (CON historial)');
    debugPrint('   🤖 Modelo: $_currentModel');
    return await _service.generateContentContext(prompt, model: _currentModel);
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🟪 [OllamaAdapter] generateContentWithoutHistory');
    debugPrint('   🤖 Modelo: $_currentModel');
    return await _service.generateResponse(model: _currentModel, prompt: prompt);
  }

  @override
  Stream<String> generateContentStream(String prompt) {
    debugPrint('🌊 [OllamaAdapter] generateContentStream (CON historial)');
    debugPrint('   🤖 Modelo: $_currentModel');
    return _service.generateContentStreamContext(
      model: _currentModel,
      prompt: prompt,
    );
  }

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) {
    debugPrint('🌊 [OllamaAdapter] generateContentStreamWithoutHistory');
    debugPrint('   🤖 Modelo: $_currentModel');
    return _service.generateContentStream(
      model: _currentModel,
      prompt: prompt,
    );
  }

  void clearConversation() {
    _service.clearConversation();
  }
}

/// Adaptador para Ollama local (fallback sin streaming real por ahora)
class LocalOllamaServiceAdapter implements AIServiceBase {
  final OllamaManagedService _service;

  LocalOllamaServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🟠 [LocalOllamaAdapter] generateContent (con historial)');
    debugPrint('   🤖 Modelo: ${_service.currentModel}');
    return await _service.generateContentContext(prompt);
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🟠 [LocalOllamaAdapter] generateContentWithoutHistory');
    debugPrint('   🤖 Modelo: ${_service.currentModel}');
    return await _service.generateContent(prompt);
  }

  @override
  Stream<String> generateContentStream(String prompt) {
    debugPrint('🌊 [LocalOllamaAdapter] generateContentStream (CON historial)');
    debugPrint('   🤖 Modelo: ${_service.currentModel}');
    return _service.generateContentStreamContext(prompt);
  }

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) {
    debugPrint('🌊 [LocalOllamaAdapter] generateContentStreamWithoutHistory');
    debugPrint('   🤖 Modelo: ${_service.currentModel}');
    return _service.generateContentStream(prompt);
  }

  void clearConversation() {
    _service.clearConversation();
  }

  OllamaManagedService get service => _service;
}