import 'package:flutter/foundation.dart';
import 'ai_service_selector.dart';

class AIChatService {
  final AIServiceSelector _aiServiceSelector;

  AIChatService(this._aiServiceSelector);

  Stream<String> generateResponseStream(String prompt) {
    debugPrint('🌊 [AIChatService] Generando respuesta con streaming');
    debugPrint('   🎯 Proveedor actual: ${_aiServiceSelector.currentProvider}');

    final adapter = _aiServiceSelector.getCurrentAdapter();
    return adapter.generateContentStream(prompt);
  }

  Stream<String> generateResponseStreamWithoutHistory(String prompt) {
    debugPrint('🌊 [AIChatService] Streaming sin historial');
    debugPrint('   🎯 Proveedor actual: ${_aiServiceSelector.currentProvider}');

    final adapter = _aiServiceSelector.getCurrentAdapter();
    return adapter.generateContentStreamWithoutHistory(prompt);
  }

  AIProvider get currentProvider => _aiServiceSelector.currentProvider;
}