import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';
import '../../../../data/models/message_model.dart';

class MessageList extends StatelessWidget {
  final List<Message> messages;
  final bool isProcessing;

  const MessageList({
    super.key,
    required this.messages,
    this.isProcessing = false,
  });

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
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

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _MessageBubble(message: message);
      },
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Message message;

  const _MessageBubble({required this.message});

  String _cleanMarkdownText(String text) {
    // Eliminar múltiples saltos de línea consecutivos (más de uno)
    String cleaned = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    
    // Limpiar espacios en blanco al inicio y final
    cleaned = cleaned.trim();
    
    return cleaned;
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                message.displayPrefix,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: isUser
                  ? Text(
                      message.content,
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 15,
                      ),
                    )
                  : MarkdownWidget(
                      data: _cleanMarkdownText(message.content),
                      shrinkWrap: true,
                      selectable: true,
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
      ),
    );
  }
}