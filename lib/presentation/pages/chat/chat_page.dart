import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/custom_drawer.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input.dart';
import 'widgets/quick_responses.dart';

class ChatPage extends StatelessWidget {
  const ChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: const _ChatBody(),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Chatbot Demo'),
            actions: [
              if (chatProvider.isProcessing)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                tooltip: 'Limpiar conversación',
                onPressed: chatProvider.clearMessages,
              ),
            ],
          ),
          drawer: const CustomDrawer(),
          body: Column(
            children: [
              Expanded(
                child: MessageList(messages: chatProvider.messages),
              ),
              QuickResponsesWidget(
                responses: chatProvider.quickResponses,
                onResponseSelected: (response) =>
                    chatProvider.sendMessage(response),
              ),
              MessageInput(
                onSendMessage: chatProvider.sendMessage,
                isBlocked: chatProvider.isProcessing,
              ),
            ],
          ),
        );
      },
    );
  }
}
