import 'package:flutter/foundation.dart';
import '../../data/models/message_model.dart';
import '../../data/models/quick_response_model.dart';

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  List<QuickResponse> _quickResponses = QuickResponseProvider.defaultResponses;

  List<Message> get messages => List.unmodifiable(_messages);
  List<QuickResponse> get quickResponses => _quickResponses;

  void sendMessage(String content) {
    if (content.trim().isEmpty) return;

    // Añadir mensaje del usuario
    final userMessage = Message.user(content);
    _messages.add(userMessage);

    // Simular respuesta del bot
    _simulateBotResponse(content);

    // Actualizar respuestas rápidas según contexto
    _updateQuickResponses();

    notifyListeners();
  }

  void _simulateBotResponse(String userMessage) {
    // Simular un pequeño delay
    Future.delayed(const Duration(milliseconds: 500), () {
      final botMessage = Message.bot(
        '¡Hola! Recibí tu mensaje: $userMessage',
      );
      _messages.add(botMessage);
      notifyListeners();
    });
  }

  void _updateQuickResponses() {
    // TODO: Implementar lógica dinámica
    _quickResponses = QuickResponseProvider.getContextualResponses(_messages);
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}