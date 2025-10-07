import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/custom_drawer.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input.dart';
import 'widgets/quick_responses.dart';

class ChatPage extends StatelessWidget {
  final File? preloadedConversationFile;

  const ChatPage({super.key, this.preloadedConversationFile});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ChatProvider(),
      child: _ChatBody(preloadedConversationFile: preloadedConversationFile),
    );
  }
}

class _ChatBody extends StatefulWidget {
  final File? preloadedConversationFile;
  const _ChatBody({this.preloadedConversationFile});

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  @override
  void initState() {
    super.initState();
    // Si hay una conversación preexistente, cargarla al iniciar
    if (widget.preloadedConversationFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.loadConversation(widget.preloadedConversationFile!);
      });
    }
  }

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

