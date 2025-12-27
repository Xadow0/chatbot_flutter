// ============================================================================
// LOCAL CHAT REPOSITORY - IMPLEMENTACIÓN (DATA LAYER)
// ============================================================================
// 
// Implementación del repositorio de chat que gestiona los mensajes
// localmente y delega la generación de respuestas a AIChatService.
// 
// UBICACIÓN: lib/data/repositories/chat_repository.dart
// ============================================================================

import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../shared/widgets/ai_chat_wrapper.dart';
import '../models/message_model.dart';

class LocalChatRepository implements IChatRepository {
  final List<Message> _localMessages = [];
  final AIChatService _aiChatService;

  LocalChatRepository(this._aiChatService);

  @override
  Stream<MessageEntity> sendMessageStream(String content) async* {
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now();
    final buffer = StringBuffer();

    try {
      await for (final chunk in _aiChatService.generateResponseStream(content)) {
        buffer.write(chunk);

        yield MessageEntity(
          id: messageId,
          content: buffer.toString(),
          type: MessageTypeEntity.bot,
          timestamp: timestamp,
        );
      }

      final finalMessage = Message.bot(buffer.toString());
      _localMessages.add(finalMessage);
    } catch (e) {
      yield MessageEntity(
        id: messageId,
        content: '❌ Error: ${e.toString()}',
        type: MessageTypeEntity.bot,
        timestamp: timestamp,
      );
      rethrow;
    }
  }

  @override
  Future<List<MessageEntity>> getMessageHistory() async {
    return _localMessages.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> clearHistory() async {
    _localMessages.clear();
  }
}