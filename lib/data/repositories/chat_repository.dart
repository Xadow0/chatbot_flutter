import '../models/message_model.dart';

/// Repositorio para manejar operaciones de chat
/// Esta implementación local genera respuestas predefinidas
/// sin comunicación con IA o red.
abstract class ChatRepository {
  Future<Message> sendMessage(String content);
  Future<List<Message>> getMessageHistory();
  Future<void> clearHistory();
}

class LocalChatRepository implements ChatRepository {
  final List<Message> _localMessages = [];

  @override
  Future<Message> sendMessage(String content) async {
    // Simular pequeña latencia local
    await Future.delayed(const Duration(milliseconds: 300));

    final botMessage = Message.bot('¡Hola! Recibí tu mensaje: $content');
    _localMessages.add(botMessage);
    return botMessage;
  }

  @override
  Future<List<Message>> getMessageHistory() async {
    return List.unmodifiable(_localMessages);
  }

  @override
  Future<void> clearHistory() async {
    _localMessages.clear();
  }
}
