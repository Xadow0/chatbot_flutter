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
    
    // Obtener argumentos de navegación para determinar si es una conversación nueva
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isNewConversation = args?['newConversation'] as bool? ?? false;
    
    // Simplemente renderizamos el _ChatBody, que consumirá
    // el provider global existente.
    return _ChatBody(
      preloadedConversationFile: preloadedConversationFile,
      isNewConversation: isNewConversation,
    );
  }
}

class _ChatBody extends StatefulWidget {
  final File? preloadedConversationFile;
  final bool isNewConversation;
  
  const _ChatBody({
    this.preloadedConversationFile,
    this.isNewConversation = false,
  });

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> {
  // GlobalKey para acceder al estado del MessageInput
  final GlobalKey<MessageInputState> _messageInputKey = GlobalKey<MessageInputState>();

  @override
  void initState() {
    super.initState();
    
    // Esta lógica ahora funcionará correctamente, porque
    // context.read<ChatProvider>() encontrará el provider
    // global inyectado en main.dart.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatProvider = context.read<ChatProvider>();
      
      if (widget.preloadedConversationFile != null) {
        // Si viene con un archivo preloadedConversationFile (desde History),
        // cargar esa conversación sin añadir mensajes extra
        await chatProvider.loadConversation(widget.preloadedConversationFile!);
      } else if (widget.isNewConversation) {
        // Si navegamos desde el menú con newConversation=true,
        // limpiar la conversación anterior y comenzar de cero con welcome message
        await chatProvider.clearMessages(saveBeforeClear: true);
      }
      // Si no cumple ninguna condición, simplemente se muestra
      // el estado actual del provider (última conversación o vacío)
    });
  }

  /// Maneja la selección de una quick response
  /// Si el texto comienza con '/', lo inserta en el campo de entrada
  /// Si no, lo envía directamente como mensaje
  void _handleQuickResponseSelected(String text) {
    if (text.startsWith('/')) {
      // Es un comando: insertar en el campo de entrada
      _messageInputKey.currentState?.insertTextAtStart(text);
    } else {
      // Es una respuesta normal: enviar directamente
      final chatProvider = context.read<ChatProvider>();
      chatProvider.sendMessage(text);
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
                  onResponseSelected: _handleQuickResponseSelected,
                ),
                
                // Campo de entrada
                MessageInput(
                  key: _messageInputKey,
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