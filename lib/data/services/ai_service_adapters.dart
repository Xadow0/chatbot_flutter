import 'package:flutter/foundation.dart';
import 'gemini_service.dart';
import 'openai_service.dart';
import 'ollama_service.dart';
import 'local_ollama_service.dart';
import '../../domain/usecases/command_processor.dart';

class GeminiServiceAdapter implements AIServiceBase {
  final GeminiService _service;

  GeminiServiceAdapter(this._service);

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

class OpenAIServiceAdapter implements AIServiceBase {
  final OpenAIService _service;

  OpenAIServiceAdapter(this._service);

  @override
  Stream<String> generateContentStream(String prompt) {
    debugPrint('🌊 [OpenAIAdapter] generateContentStream (CON historial)');
    return _service.generateContentStreamContext(prompt);
  }

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) {
    debugPrint('🌊 [OpenAIAdapter] generateContentStreamWithoutHistory');
    return _service.generateContentStream(prompt);
  }

  void clearConversation() {
    _service.clearConversation();
  }
}

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

class LocalOllamaServiceAdapter implements AIServiceBase {
  final OllamaManagedService _service;

  LocalOllamaServiceAdapter(this._service);

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