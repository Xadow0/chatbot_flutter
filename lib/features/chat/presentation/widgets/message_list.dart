import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:markdown_widget/markdown_widget.dart';
import '../../data/models/message_model.dart';

class MessageList extends StatefulWidget {
  final List<Message> messages;
  final bool isProcessing;

  const MessageList({
    super.key,
    required this.messages,
    this.isProcessing = false,
  });

  @override
  State<MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<MessageList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Scroll inicial al fondo si hay mensajes al cargar
    if (widget.messages.isNotEmpty) {
      _scrollToBottom();
    }
  }

  @override
  void didUpdateWidget(covariant MessageList oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Detectar si se han añadido mensajes nuevos
    if (widget.messages.length > oldWidget.messages.length) {
      _scrollToBottom();
    }
    
    // Opcional: Si quieres que scrollee también mientras el bot escribe (stream)
    // podrias verificar si el último mensaje cambió de contenido, 
    // pero a veces es molesto si el usuario quiere leer arriba.
    // Por ahora lo dejamos solo al "añadir" mensaje nuevo.
  }

  void _scrollToBottom() {
    // Usamos addPostFrameCallback para esperar a que la lista se renderice
    // y calcule su nuevo tamaño antes de hacer scroll.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              '¡Empieza una conversación!',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    // SOLUCIÓN PRINCIPAL: SelectionArea
    // Envuelve la lista completa para permitir selección continua y auto-scroll
    return SelectionArea(
      child: ListView.builder(
        controller: _scrollController, // Vinculamos el controlador aquí
        padding: const EdgeInsets.all(8),
        itemCount: widget.messages.length,
        itemBuilder: (context, index) {
          final message = widget.messages[index];
          // Añadimos un padding extra al último elemento para que no quede pegado
          // y asegure visibilidad total tras el scroll
          final isLast = index == widget.messages.length - 1;
          
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 10.0 : 0.0),
            child: _MessageBubble(
              key: ValueKey(message.id),
              message: message,
            ),
          );
        },
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({super.key, required this.message});

  String _cleanMarkdownText(String text) {
    String cleaned = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    cleaned = cleaned.trim();
    return cleaned;
  }

  // Lógica para copiar al portapapeles
  void _copyToClipboard(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Mensaje copiado al portapapeles'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = message.type == MessageType.user;
    final colorScheme = Theme.of(context).colorScheme;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: isUser
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Prefijo (Icono/Nombre)
                SelectionContainer.disabled(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      message.displayPrefix,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // Contenido del Mensaje
                Flexible(
                  child: isUser
                      ? Text( 
                          message.content,
                          style: TextStyle(
                            color: colorScheme.onPrimary,
                            fontSize: 15,
                          ),
                          selectionColor: colorScheme.onPrimary.withValues(alpha: 0.4),
                        )
                      : MarkdownWidget(
                          data: _cleanMarkdownText(message.content),
                          shrinkWrap: true,
                          selectable: false, 
                          config: MarkdownConfig(
                            configs: [
                              PConfig(
                                textStyle: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 15,
                                  height: 1.4,
                                ),
                              ),
                              H1Config(
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                              H2Config(
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                              H3Config(
                                style: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  height: 1.3,
                                ),
                              ),
                              CodeConfig(
                                style: TextStyle(
                                  backgroundColor: colorScheme.surfaceContainer,
                                  color: colorScheme.primary,
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                              ),
                              PreConfig(
                                textStyle: TextStyle(
                                  color: colorScheme.onSurface,
                                  fontFamily: 'monospace',
                                  fontSize: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: colorScheme.surfaceContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.all(12),
                              ),
                              ListConfig(
                                marker: (bool isOrdered, int depth, int index) {
                                  if (isOrdered) {
                                    return Text(
                                      '${index + 1}. ',
                                      style: TextStyle(
                                        color: colorScheme.onSurface,
                                        fontSize: 15,
                                      ),
                                    );
                                  }
                                  return Text(
                                    '• ',
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: 15,
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            // Botón de Copiar
            SelectionContainer.disabled(
              child: InkWell(
                  onTap: () => _copyToClipboard(context, message.content),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 14,
                      color: isUser 
                          ? colorScheme.onPrimary.withValues(alpha: 0.7) 
                          : colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}