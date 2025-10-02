import 'package:flutter/material.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/custom_drawer.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input.dart';
import 'widgets/quick_responses.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ChatProvider _chatProvider = ChatProvider();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatbot Demo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Limpiar conversación',
            onPressed: () {
              setState(() {
                _chatProvider.clearMessages();
              });
            },
          ),
        ],
      ),
      drawer: const CustomDrawer(),
      body: Column(
        children: [
          // Lista de mensajes
          Expanded(
            child: MessageList(
              messages: _chatProvider.messages,
            ),
          ),
          
          // Respuestas rápidas
          QuickResponsesWidget(
            responses: _chatProvider.quickResponses,
            onResponseSelected: (response) {
              setState(() {
                _chatProvider.sendMessage(response);
              });
            },
          ),
          
          // Input de mensaje
          MessageInput(
            onSendMessage: (message) {
              setState(() {
                _chatProvider.sendMessage(message);
              });
            },
          ),
        ],
      ),
    );
  }
}