import '../services/gemini_service.dart';
import '../services/openai_service.dart';
import '../services/ollama_service.dart';
import '../services/local_ollama_service.dart';
import '../../domain/usecases/command_processor.dart';

/// Adaptador para GeminiService
class GeminiServiceAdapter implements AIServiceBase {
  final GeminiService _service;

  GeminiServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    return await _service.generateContent(prompt);
  }
}

/// Adaptador para OpenAIService
class OpenAIServiceAdapter implements AIServiceBase {
  final OpenAIService _service;

  OpenAIServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    return await _service.generateContent(prompt);
  }
}

/// Adaptador para OllamaService (servidor remoto)
class OllamaServiceAdapter implements AIServiceBase {
  final OllamaService _service;
  String _currentModel;

  OllamaServiceAdapter(this._service, String initialModel)
      : _currentModel = initialModel;

  void updateModel(String modelName) {
    _currentModel = modelName;
  }

  @override
  Future<String> generateContent(String prompt) async {
    return await _service.generateContent(
      prompt,
      model: _currentModel,
    );
  }
}

/// Adaptador para OllamaManagedService (Ollama Local Gestionado)
class LocalOllamaServiceAdapter implements AIServiceBase {
  final OllamaManagedService _service;

  LocalOllamaServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    return await _service.generateContent(prompt);
  }
  
  OllamaManagedService get service => _service;
}