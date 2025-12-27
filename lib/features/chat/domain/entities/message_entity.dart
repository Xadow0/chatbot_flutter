/// Entidad de dominio para un mensaje en el chat
/// 
/// Esta es una clase de dominio pura que no depende de ningún framework
/// o implementación específica. Representa el concepto de mensaje en el negocio.
class MessageEntity {
  final String id;
  final String content;
  final MessageTypeEntity type;
  final DateTime timestamp;

  const MessageEntity({
    required this.id,
    required this.content,
    required this.type,
    required this.timestamp,
  });

  /// Crea una copia del mensaje con algunos campos modificados
  MessageEntity copyWith({
    String? id,
    String? content,
    MessageTypeEntity? type,
    DateTime? timestamp,
  }) {
    return MessageEntity(
      id: id ?? this.id,
      content: content ?? this.content,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Verifica si el mensaje es del usuario
  bool get isUser => type == MessageTypeEntity.user;

  /// Verifica si el mensaje es del bot
  bool get isBot => type == MessageTypeEntity.bot;

  /// Obtiene el prefijo visual del mensaje
  String get displayPrefix => type == MessageTypeEntity.user ? '👤' : '🤖';

  /// Obtiene el nombre a mostrar del remitente
  String get displayName => type == MessageTypeEntity.user ? 'Usuario' : 'Bot';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MessageEntity &&
        other.id == id &&
        other.content == content &&
        other.type == type &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode {
    return Object.hash(id, content, type, timestamp);
  }

  @override
  String toString() {
    return 'MessageEntity(id: $id, content: ${content.length > 30 ? '${content.substring(0, 30)}...' : content}, type: $type, timestamp: $timestamp)';
  }
}

/// Tipo de mensaje en la entidad de dominio
enum MessageTypeEntity {
  user,
  bot,
}