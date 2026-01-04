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
  bool _isLoadingHistory = false;

  @override
  void initState() {
    super.initState();
    
    // Registrar el observer para el ciclo de vida de la app
    WidgetsBinding.instance.addObserver(this);
    
    // Guardamos la referencia al inicio
    _chatProviderRef = context.read<ChatProvider>();

    if (widget.preloadedConversationFile != null) {
      _isLoadingHistory = true;
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Si hay un archivo precargado (viene del historial), lo cargamos
      if (widget.preloadedConversationFile != null) {
        await _chatProviderRef.loadConversation(widget.preloadedConversationFile!);
        
        // Una vez cargado, quitamos el loading y actualizamos la UI
        if (mounted) {
          setState(() {
            _isLoadingHistory = false;
          });
        }
      }
      // Si NO hay archivo precargado y NO hay sesión activa, mostramos bienvenida
      else if (!_chatProviderRef.hasActiveSession && _chatProviderRef.messages.isEmpty) {
        // El provider maneja la bienvenida
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chatProviderRef = context.read<ChatProvider>();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
        debugPrint('📱 [ChatPage] App pausada - guardando conversación...');
        _chatProviderRef.onAppPaused();
        break;
      case AppLifecycleState.detached:
        debugPrint('📱 [ChatPage] App detached - guardando conversación...');
        _chatProviderRef.onAppDetached();
        break;
      case AppLifecycleState.inactive:
        debugPrint('📱 [ChatPage] App inactiva');
        break;
      case AppLifecycleState.resumed:
        debugPrint('📱 [ChatPage] App resumed');
        break;
      case AppLifecycleState.hidden:
        debugPrint('📱 [ChatPage] App hidden - guardando conversación...');
        _chatProviderRef.onAppPaused();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_chatProviderRef.hasUnsavedChanges) {
       debugPrint('🚨 [ChatPage] Detectada salida sin guardar en dispose. Guardando ahora...');
       _chatProviderRef.endSession();
    }
    super.dispose();
  }

  Future<void> _onWillPop() async {
    await _chatProviderRef.endSession();
    if (mounted) {
      setState(() {
        _canExit = true;
      });
      Navigator.of(context).pop();
    }
  }

  Future<void> _showNewConversationDialog() async {
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
      final promptToInsert = response.promptTemplate ?? '';
      if (promptToInsert.isNotEmpty) {
        _messageInputKey.currentState?.insertTextAtStart(promptToInsert);
      }
    } else {
      String commandText = response.text;
      if (!commandText.endsWith(' ')) {
        commandText += ' ';
      }
      _messageInputKey.currentState?.insertTextAtStart(commandText);
    }
  }

  void _handleEditRequested(QuickResponse response) {
    final promptToInsert = response.promptTemplate ?? '';
    if (promptToInsert.isNotEmpty) {
      _messageInputKey.currentState?.insertTextAtStart(promptToInsert);
    }
  }

  Future<void> _showClearChatDialog(ChatProvider chatProvider) async {
    if (!chatProvider.hasSignificantContent) {
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

  @override
  Widget build(BuildContext context) {
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
                    icon: const Icon(Icons.add_comment_outlined),
                    tooltip: 'Nueva conversación',
                    onPressed: chatProvider.isProcessing 
                        ? null 
                        : _showNewConversationDialog,
                  ),
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
                  
                  // 4. NUEVO: Lógica condicional para el cuerpo del chat
                  Expanded(
                    child: _isLoadingHistory
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Cargando historial...'),
                            ],
                          ),
                        )
                      : MessageList(
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
                    isBlocked: chatProvider.isProcessing || _isLoadingHistory, // Bloqueamos input si carga
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
