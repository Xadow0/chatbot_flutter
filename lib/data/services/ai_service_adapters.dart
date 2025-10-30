import 'package:flutter/foundation.dart';
import '../services/gemini_service.dart';
import '../services/openai_service.dart';
import '../services/ollama_service.dart';
import '../services/local_ollama_service.dart';
import '../../domain/usecases/command_processor.dart';

/// ============================================================================
/// ADAPTADOR PARA GEMINI SERVICE
/// ============================================================================
/// 
/// Este adaptador permite que GeminiService implemente la interfaz AIServiceBase
/// requerida por CommandProcessor, con soporte para generación con y sin historial.
class GeminiServiceAdapter implements AIServiceBase {
  final GeminiService _service;

  GeminiServiceAdapter(this._service);

  @override
  Future<String> generateContent(String prompt) async {
    debugPrint('🔵 [GeminiAdapter] generateContent llamado (con posible historial)');
    return await _service.generateContent(prompt);
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🔵 [GeminiAdapter] generateContentWithoutHistory llamado');
    debugPrint('   ⚡ Enviando prompt SIN historial a Gemini');
    
    // Para Gemini, el método generateContent ya funciona sin historial
    // por defecto, ya que no mantiene estado de conversación internamente
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
    return await _service.generateContent(prompt);
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
/// 
/// Este adaptador maneja Ollama remoto con soporte para cambio de modelo
/// y generación con/sin historial.
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
    debugPrint('🟪 [OllamaAdapter] generateContent llamado (con posible historial)');
    debugPrint('   🤖 Modelo: $_currentModel');
    
    return await _service.generateContent(
      prompt,
      model: _currentModel,
    );
  }

  @override
  Future<String> generateContentWithoutHistory(String prompt) async {
    debugPrint('🟪 [OllamaAdapter] generateContentWithoutHistory llamado');
    debugPrint('   🤖 Modelo: $_currentModel');
    debugPrint('   ⚡ Enviando prompt SIN historial a Ollama');
    
    // Para Ollama remoto, usar generateResponse que solo envía el prompt
    // sin ningún historial de conversación.
    // El método generateResponse usa el endpoint /api/generate que NO mantiene historial.
    return await _service.generateResponse(
      model: _currentModel,
      prompt: prompt,
    );
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
    
    return await _service.generateContent(prompt);
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
  
  /// Getter para acceder al servicio subyacente si es necesario
  OllamaManagedService get service => _service;
}