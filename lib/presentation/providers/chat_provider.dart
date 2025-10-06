import 'package:flutter/foundation.dart';
import '../../data/models/message_model.dart';
import '../../data/models/quick_response_model.dart';
import '../../data/services/gemini_service.dart';
import '../../data/repositories/chat_repository.dart';
import '../../domain/usecases/command_processor.dart';
import '../../domain/usecases/send_message_usecase.dart';

class ChatProvider extends ChangeNotifier {
  final List<Message> _messages = [];
  List<QuickResponse> _quickResponses = QuickResponseProvider.defaultResponses;
  bool _isProcessing = false;

  late final SendMessageUseCase _sendMessageUseCase;

  ChatProvider() {
    final geminiService = GeminiService();
    final commandProcessor = CommandProcessor(geminiService);
    final localRepository = LocalChatRepository();

    _sendMessageUseCase = SendMessageUseCase(
      commandProcessor: commandProcessor,
      chatRepository: localRepository,
    );
  }

  List<Message> get messages => List.unmodifiable(_messages);
  List<QuickResponse> get quickResponses => _quickResponses;
  bool get isProcessing => _isProcessing;

  Future<void> sendMessage(String content) async {
    if (content.trim().isEmpty || _isProcessing) return;

    final userMessage = Message.user(content);
    _messages.add(userMessage);
    _isProcessing = true;
    notifyListeners();

    try {
      final botResponse = await _sendMessageUseCase.execute(content);
      _messages.add(botResponse);
    } catch (e) {
      _messages.add(Message.bot('❌ Error inesperado: ${e.toString()}'));
    } finally {
      _isProcessing = false;
      _updateQuickResponses();
      notifyListeners();
    }
  }

  void _updateQuickResponses() {
    _quickResponses = QuickResponseProvider.getContextualResponses(_messages);
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
