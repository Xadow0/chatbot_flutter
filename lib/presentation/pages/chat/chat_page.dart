// lib/presentation/pages/chat/chat_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/custom_drawer.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input.dart';
import 'widgets/quick_responses.dart';
import 'widgets/model_selector_bubble.dart';
import '../../../data/models/message_model.dart'; // (Estos imports de 'data' deberían
import '../../../data/models/quick_response_model.dart'; // moverse a los widgets en un futuro)

class ChatPage extends StatelessWidget {
  final File? preloadedConversationFile;

  const ChatPage({super.key, this.preloadedConversationFile});

  @override
  Widget build(BuildContext context) {
    //
    // --- IMPORTANTE: Se elimina el ChangeNotifierProvider ---
    //
    // El ChatProvider ya fue inyectado en main.dart y está disponible
    // en todo el árbol de widgets. Crear uno nuevo aquí es incorrecto
    // y fallaría, ya que el constructor ahora espera dependencias.
    //
    // return ChangeNotifierProvider( <-- ELIMINADO
    //   create: (_) => ChatProvider(), <-- ELIMINADO
    //   child: _ChatBody(preloadedConversationFile: preloadedConversationFile), <-- ELIMINADO
    // );
    
    // Simplemente renderizamos el _ChatBody, que consumirá
    // el provider global existente.
    return _ChatBody(preloadedConversationFile: preloadedConversationFile);
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
    
    // Esta lógica ahora funcionará correctamente, porque
    // context.read<ChatProvider>() encontrará el provider
    // global inyectado en main.dart.
    if (widget.preloadedConversationFile != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final chatProvider = context.read<ChatProvider>();
        await chatProvider.loadConversation(widget.preloadedConversationFile!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // El Consumer<ChatProvider> también encontrará el provider
    // global sin problemas.
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return GestureDetector(
          // Ocultar selector cuando se toca fuera
          onTap: () {
            if (chatProvider.showModelSelector) {
              chatProvider.hideModelSelector();
            }
          },
          child: Scaffold(
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
                // Burbuja de selección de modelos
                const ModelSelectorBubble(),
                
                // Lista de mensajes
                Expanded(
                  child: MessageList(
                    messages: chatProvider.messages
                        .map((e) => Message.fromEntity(e))
                        .toList(),
                  ),
                ),
                
                // Respuestas rápidas
                QuickResponsesWidget(
                  responses: chatProvider.quickResponses
                      .map((e) => QuickResponse.fromEntity(e))
                      .toList(),
                  onResponseSelected: (response) =>
                      chatProvider.sendMessage(response),
                ),
                
                // Campo de entrada
                MessageInput(
                  onSendMessage: chatProvider.sendMessage,
                  isBlocked: chatProvider.isProcessing,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}