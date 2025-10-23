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

  // Compatibility getters used across the codebase
  bool get isUser => type == MessageType.user;
  String get text => content;

  Map<String, dynamic> toJson() => {
        'id': id,
        'content': content,
        'type': type.name,
        'timestamp': timestamp.toIso8601String(),
      };

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      content: json['content'],
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.bot,
      ),
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}

