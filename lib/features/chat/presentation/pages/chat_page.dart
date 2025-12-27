import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../logic/chat_provider.dart';
import '../../../../shared/widgets/custom_drawer.dart';
import '../widgets/message_list.dart';
import '../widgets/message_input.dart';
import '../widgets/quick_responses.dart';
import '../widgets/model_selector_bubble.dart';
import '../../data/models/message_model.dart'; 
import '../../data/models/quick_response_model.dart'; 

class ChatPage extends StatelessWidget {
  final File? preloadedConversationFile;

  const ChatPage({super.key, this.preloadedConversationFile});

  @override
  Widget build(BuildContext context) {
    return _ChatBody(
      preloadedConversationFile: preloadedConversationFile,
    );
  }
}

class _ChatBody extends StatefulWidget {
  final File? preloadedConversationFile;
  
  const _ChatBody({
    this.preloadedConversationFile,
  });

  @override
  State<_ChatBody> createState() => _ChatBodyState();
}

class _ChatBodyState extends State<_ChatBody> with WidgetsBindingObserver {
  final GlobalKey<MessageInputState> _messageInputKey = GlobalKey<MessageInputState>();
  
  // Referencia local para usar en dispose() y lifecycle
  late ChatProvider _chatProviderRef;
  bool _canExit = false;

  @override
  void initState() {
    super.initState();
    
    // Registrar el observer para el ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);
    
    // Guardamos la referencia al inicio
    _chatProviderRef = context.read<ChatProvider>();
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Si hay un archivo precargado (viene del historial), lo cargamos
      if (widget.preloadedConversationFile != null) {
        await _chatProviderRef.loadConversation(widget.preloadedConversationFile!);
      }
      // Si NO hay archivo precargado y NO hay sesión activa, mostramos bienvenida
      // Pero NO limpiamos si ya hay una sesión activa (el usuario vuelve de otra pantalla)
      else if (!_chatProviderRef.hasActiveSession && _chatProviderRef.messages.isEmpty) {
        // Esto añadirá el mensaje de bienvenida si es necesario
        // pero el provider ya lo maneja internamente
      }
    });
  }

  // Mantener referencia actualizada si el widget se reconstruye
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProviderRef = context.read<ChatProvider>();
  }

  // ============================================================================
  // NUEVO: Manejo del ciclo de vida de la app
  // ============================================================================
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        // App va a segundo plano - guardar conversación
        debugPrint('📱 [ChatPage] App pausada - guardando conversación...');
        _chatProviderRef.onAppPaused();
        break;
        
      case AppLifecycleState.detached:
        // App se va a cerrar - guardar conversación
        debugPrint('📱 [ChatPage] App detached - guardando conversación...');
        _chatProviderRef.onAppDetached();
        break;
        
      case AppLifecycleState.inactive:
        // App inactiva (puede pasar antes de paused)
        debugPrint('📱 [ChatPage] App inactiva');
        break;
        
      case AppLifecycleState.resumed:
        // App vuelve a primer plano
        debugPrint('📱 [ChatPage] App resumed');
        break;
        
      case AppLifecycleState.hidden:
        // App oculta (iOS)
        debugPrint('📱 [ChatPage] App hidden - guardando conversación...');
        _chatProviderRef.onAppPaused();
        break;
    }
  }

  /// EL SALVAVIDAS: Se ejecuta SIEMPRE al destruir la pantalla.
  @override
  void dispose() {
    // Remover el observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Si por alguna razón salimos y aún hay cambios pendientes (el PopScope falló o fue bypass),
    // forzamos el guardado aquí. No podemos hacer 'await', pero lanzamos el proceso.
    if (_chatProviderRef.hasUnsavedChanges) {
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

  // ============================================================================
  // NUEVO: Diálogo de confirmación para nueva conversación
  // ============================================================================
  Future<void> _showNewConversationDialog() async {
    // Si no hay contenido significativo, crear nueva directamente
    if (!_chatProviderRef.hasSignificantContent) {
      await _chatProviderRef.startNewConversation();
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nueva conversación'),
        content: const Text(
          '¿Deseas iniciar una nueva conversación?\n\n'
          'La conversación actual se guardará automáticamente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Nueva conversación'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _chatProviderRef.startNewConversation();
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
                actions: [
                  // Indicador de procesamiento
                  if (chatProvider.isProcessing)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  
                  // NUEVO: Botón de nueva conversación
                  IconButton(
                    icon: const Icon(Icons.add_comment_outlined),
                    tooltip: 'Nueva conversación',
                    onPressed: chatProvider.isProcessing 
                        ? null 
                        : _showNewConversationDialog,
                  ),
                  
                  // Botón de limpiar (ahora solo limpia sin guardar)
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Limpiar chat',
                    onPressed: chatProvider.isProcessing
                        ? null
                        : () => _showClearChatDialog(chatProvider),
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

  // ============================================================================
  // NUEVO: Diálogo para limpiar chat (sin guardar)
  // ============================================================================
  Future<void> _showClearChatDialog(ChatProvider chatProvider) async {
    if (!chatProvider.hasSignificantContent) {
      // No hay nada que limpiar
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limpiar chat'),
        content: const Text(
          '¿Deseas limpiar el chat actual?\n\n'
          'Esto eliminará todos los mensajes de la pantalla '
          'pero NO guardará la conversación.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Limpiar'),
          ),
        ],
      ),
    );

    if (result == true) {
      await chatProvider.clearMessages();
    }
  }
}