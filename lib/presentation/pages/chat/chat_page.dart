import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/custom_drawer.dart';
import 'widgets/message_list.dart';
import 'widgets/message_input.dart';
import 'widgets/quick_responses.dart';
import 'widgets/model_selector_bubble.dart';
import '../../../data/models/message_model.dart'; 
import '../../../data/models/quick_response_model.dart'; 

class ChatPage extends StatelessWidget {
  final File? preloadedConversationFile;

  const ChatPage({super.key, this.preloadedConversationFile});

  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final isNewConversation = args?['newConversation'] as bool? ?? false;
    
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
  final GlobalKey<MessageInputState> _messageInputKey = GlobalKey<MessageInputState>();
  
  // Referencia local para usar en dispose()
  late ChatProvider _chatProviderRef;
  bool _canExit = false;

  @override
  void initState() {
    super.initState();
    
    // Guardamos la referencia al inicio
    _chatProviderRef = context.read<ChatProvider>();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.preloadedConversationFile != null) {
        await _chatProviderRef.loadConversation(widget.preloadedConversationFile!);
      } else if (widget.isNewConversation) {
        await _chatProviderRef.clearMessages(); 
      }
    });
  }

  // Mantener referencia actualizada si el widget se reconstruye
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProviderRef = context.read<ChatProvider>();
  }

  /// EL SALVAVIDAS: Se ejecuta SIEMPRE al destruir la pantalla.
  @override
  void dispose() {
    // Si por alguna razón salimos y aún hay cambios pendientes (el PopScope falló o fue bypass),
    // forzamos el guardado aquí. No podemos hacer 'await', pero lanzamos el proceso.
    if (_chatProviderRef.hasUnsavedChanges) { // Asegúrate de tener un getter para _hasUnsavedChanges en el provider
       debugPrint('🚨 [ChatPage] Detectada salida sin guardar en dispose. Guardando ahora...');
       _chatProviderRef.endSession();
    }
    super.dispose();
  }

  Future<void> _onWillPop() async {
    // Intentamos guardar de forma ordenada esperando el resultado
    await _chatProviderRef.endSession();
    
    if (mounted) {
      setState(() {
        _canExit = true;
      });
      Navigator.of(context).pop();
    }
  }

  void _handleQuickResponseSelected(QuickResponse response) {
  if (response.isEditable) {
    // Comando EDITABLE: Insertar el prompt completo para que el usuario lo edite
    final promptToInsert = response.promptTemplate ?? '';
    if (promptToInsert.isNotEmpty) {
      _messageInputKey.currentState?.insertTextAtStart(promptToInsert);
    }
  } else {
    // Comando NO EDITABLE: Comportamiento tradicional (insertar "/comando ")
    String commandText = response.text;
    if (!commandText.endsWith(' ')) {
      commandText += ' ';
    }
    _messageInputKey.currentState?.insertTextAtStart(commandText);
  }
}

/// Maneja la solicitud de "Editar" desde el menú contextual de un comando NO editable.
/// Inserta el prompt completo en el input para edición manual única.
void _handleEditRequested(QuickResponse response) {
  final promptToInsert = response.promptTemplate ?? '';
  if (promptToInsert.isNotEmpty) {
    _messageInputKey.currentState?.insertTextAtStart(promptToInsert);
  }
}

  @override
  Widget build(BuildContext context) {
    // Consumimos el provider para redibujar la UI, pero usamos _chatProviderRef para la lógica
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, _) {
        return PopScope(
          canPop: _canExit,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            await _onWillPop();
          },
          child: GestureDetector(
            onTap: () {
              if (chatProvider.showModelSelector) {
                chatProvider.hideModelSelector();
              }
            },
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Chatbot Demo'),
                // Importante: Si usas el botón de atrás de la AppBar por defecto, Flutter usa maybePop automáticamente.
                // Si añades botones manuales de salida, asegúrate de que llamen a Navigator.maybePop(context) 
                // y NO a Navigator.pop(context) para que el PopScope funcione.
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
                    onPressed: () => chatProvider.clearMessages(),
                  ),
                ],
              ),
              drawer: const CustomDrawer(),
              body: Column(
                children: [
                  const ModelSelectorBubble(),
                  Expanded(
                    child: MessageList(
                      messages: chatProvider.messages
                          .map((e) => Message.fromEntity(e))
                          .toList(),
                    ),
                  ),
                  QuickResponsesWidget(
                    responses: chatProvider.quickResponses
                        .map((e) => QuickResponse.fromEntity(e))
                        .toList(),
                    onResponseSelected: _handleQuickResponseSelected,
                    onEditRequested: _handleEditRequested,
                  ),
                  MessageInput(
                    key: _messageInputKey,
                    onSendMessage: chatProvider.sendMessage,
                    onStopStreaming: chatProvider.cancelStreaming,
                    isBlocked: chatProvider.isProcessing,
                    isStreaming: chatProvider.isStreaming,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}