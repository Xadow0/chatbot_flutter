import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/services/ai_chat_service.dart';
import '../models/message_model.dart';

class LocalChatRepository implements ChatRepository {
  final List<Message> _localMessages = [];
  final AIChatService _aiChatService;

  LocalChatRepository(this._aiChatService);

  @override
  Future<MessageEntity> sendMessage(String content) async {
    await Future.delayed(const Duration(milliseconds: 300));

    final botResponseContent = await _generateLocalResponse(content);

    final botMessage = Message.bot(botResponseContent);
    _localMessages.add(botMessage);
    
    return botMessage.toEntity();
  }

  Future<String> _generateLocalResponse(String userMessage) async {
    return await _aiChatService.generateResponse(userMessage);
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