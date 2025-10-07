import 'package:flutter/foundation.dart';
import 'dart:io';
import '../../data/models/message_model.dart';
import '../../data/models/quick_response_model.dart';
import '../../data/services/gemini_service.dart';
import '../../data/repositories/chat_repository.dart';
import '../../data/repositories/conversation_repository.dart';
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

  /// Envía un mensaje y guarda la conversación automáticamente
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

      // 🔹 Guarda automáticamente cada vez que cambia la conversación
      await _autoSaveConversation();
    }
  }

  void _updateQuickResponses() {
    _quickResponses = QuickResponseProvider.getContextualResponses(_messages);
  }

  /// Guarda automáticamente la conversación actual
  Future<void> _autoSaveConversation() async {
    if (_messages.isEmpty) return;
    try {
      await ConversationRepository.saveConversation(_messages);
      if (kDebugMode) {
        print("💾 Conversación guardada automáticamente (${_messages.length} mensajes)");
      }
    } catch (e) {
      if (kDebugMode) print("❌ Error al guardar conversación: $e");
    }
  }

  /// Limpia el chat (opcionalmente guardando antes)
  Future<void> clearMessages({bool saveBeforeClear = true}) async {
    if (saveBeforeClear && _messages.isNotEmpty) {
      await ConversationRepository.saveConversation(_messages);
    }
    _messages.clear();
    notifyListeners();
  }

  /// Carga una conversación desde un archivo
  Future<void> loadConversation(File file) async {
    final loadedMessages = await ConversationRepository.loadConversation(file);
    _messages
      ..clear()
      ..addAll(loadedMessages);
    _updateQuickResponses();
    notifyListeners();
  }
}

