import 'package:flutter/foundation.dart';
import '../services/gemini_service.dart';
import '../services/openai_service.dart';
import '../services/ollama_service.dart';
import '../services/local_ollama_service.dart';
import '../../domain/usecases/command_processor.dart';

/// ============================================================================
/// ADAPTADOR PARA GEMINI SERVICE
/// ============================================================================
class GeminiServiceAdapter implements AIServiceBase {
  final GeminiService _service;

  GeminiServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🔵 [GeminiAdapter] generateContent llamado (con HISTORIAL)');
    return await _service.generateContentContext(prompt);
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🔵 [GeminiAdapter] generateContentWithoutHistory llamado (sin historial)');
    return await _service.generateContent(prompt);
  }
}


/// ============================================================================
/// ADAPTADOR PARA OPENAI SERVICE
/// ============================================================================
/// 
/// Este adaptador gestiona la comunicación con OpenAI, diferenciando entre
/// generación con historial (chat) y sin historial (comandos).
class OpenAIServiceAdapter implements AIServiceBase {
  final OpenAIService _service;

  OpenAIServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🟢 [OpenAIAdapter] generateContent llamado (con posible historial)');
    
    // Para chat normal, usar el método estándar
    return await _service.generateContentContext(prompt);
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🟢 [OpenAIAdapter] generateContentWithoutHistory llamado');
    debugPrint('   ⚡ Enviando prompt SIN historial a OpenAI');
    
    // Para OpenAI, el método generateContent ya funciona sin historial
    // ya que solo recibe el prompt actual sin contexto previo.
    // Si se necesitara historial, se usaría chatWithHistory.
    return await _service.generateContent(prompt);
  }
}

/// ============================================================================
/// ADAPTADOR PARA OLLAMA SERVICE (REMOTO)
/// ============================================================================
class OllamaServiceAdapter implements AIServiceBase {
  final OllamaService _service;
  String _currentModel;

  OllamaServiceAdapter(this._service, String initialModel)
      : _currentModel = initialModel;

  /// Actualizar el modelo actual
  void updateModel(String modelName) {
    debugPrint('🟪 [OllamaAdapter] Actualizando modelo: $_currentModel -> $modelName');
    _currentModel = modelName;
  }

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🟪 [OllamaAdapter] generateContent llamado (CON historial)');
    debugPrint('   🤖 Modelo: $_currentModel');

    return await _service.generateContentContext(
      prompt,
      model: _currentModel,
    );
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🟪 [OllamaAdapter] generateContentWithoutHistory llamado (SIN historial)');
    debugPrint('   🤖 Modelo: $_currentModel');
    
    return await _service.generateResponse(
      model: _currentModel,
      prompt: prompt,
    );
  }

  /// Permite limpiar la conversación
  void clearConversation() {
    _service.clearConversation();
  }
}


/// ============================================================================
/// ADAPTADOR PARA LOCAL OLLAMA SERVICE
/// ============================================================================
/// 
/// Este adaptador gestiona Ollama embebido/local con soporte para
/// generación con/sin historial.
class LocalOllamaServiceAdapter implements AIServiceBase {
  final OllamaManagedService _service;

  LocalOllamaServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🟠 [LocalOllamaAdapter] generateContent llamado (con posible historial)');
    debugPrint('   🤖 Modelo: ${_service.currentModel}');
    
    return await _service.generateContentContext(prompt);
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🟠 [LocalOllamaAdapter] generateContentWithoutHistory llamado');
    debugPrint('   🤖 Modelo: ${_service.currentModel}');
    debugPrint('   ⚡ Enviando prompt SIN historial a Local Ollama');
    
    // Para Local Ollama, el método generateContent ya funciona sin historial
    // por defecto. El método usa /api/generate que NO mantiene estado.
    // Si se quisiera usar historial, se usaría chatWithHistory con el endpoint /api/chat.
    return await _service.generateContent(prompt);
  }
  /// Permite limpiar la conversación
  void clearConversation() {
    _service.clearConversation();
  }

  /// Getter para acceder al servicio subyacente si es necesario
  OllamaManagedService get service => _service;
}