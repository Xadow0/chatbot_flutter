import 'package:flutter/foundation.dart';
import '../../data/services/ai_service_selector.dart';

class AIChatService {
  final AIServiceSelector _aiServiceSelector;

  AIChatService(this._aiServiceSelector);

  Future<String> generateResponse(String prompt) async {
    debugPrint('💬 [AIChatService] Generando respuesta con contexto');
    debugPrint('   🎯 Proveedor actual en selector: ${_aiServiceSelector.currentProvider}');
    
    try {
      final adapter = _aiServiceSelector.getCurrentAdapter();
      return await adapter.generateContent(prompt);
    } catch (e) {
      debugPrint('❌ [AIChatService] Error generando respuesta: $e');
      rethrow;
    }
  }

  Future<String> generateResponseWithoutHistory(String prompt) async {
    debugPrint('💬 [AIChatService] Generando respuesta sin contexto');
    debugPrint('   🎯 Proveedor actual en selector: ${_aiServiceSelector.currentProvider}');
    
    try {
      final adapter = _aiServiceSelector.getCurrentAdapter();
      return await adapter.generateContentWithoutHistory(prompt);
    } catch (e) {
      debugPrint('❌ [AIChatService] Error generando respuesta: $e');
      rethrow;
    }
  }
}