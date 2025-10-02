enum MessageType { user, bot }

class Message {
  final String id;
  final String content;
  final MessageType type;
  final DateTime timestamp;

  Message({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
  });

  factory Message.user(String content) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: MessageType.user,
      timestamp: DateTime.now(),
    );
  }

  factory Message.bot(String content) {
    return Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      type: MessageType.bot,
      timestamp: DateTime.now(),
    );
  }

  String get displayPrefix => type == MessageType.user ? '👤' : '🤖';
  
  String get displayName => type == MessageType.user ? 'Usuario' : 'Bot';
}