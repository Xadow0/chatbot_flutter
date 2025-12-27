import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final VoidCallback? onStopStreaming;
  final bool isBlocked;
  final bool isStreaming;

  const MessageInput({
    super.key,
    required this.onSendMessage,
    this.onStopStreaming,
    this.isBlocked = false,
    this.isStreaming = false,
  });

  @override
  State<MessageInput> createState() => MessageInputState();
}

class MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    
    _controller.addListener(() {
      final hasText = _controller.text.trim().isNotEmpty;
      if (hasText != _hasText) {
        setState(() {
          _hasText = hasText;
        });
      }
    });
    
    _focusNode.onKeyEvent = (node, event) {
      if (event is KeyDownEvent) {
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          if (HardwareKeyboard.instance.isShiftPressed) {
            return KeyEventResult.ignored;
          } else {
            if (!widget.isBlocked && !widget.isStreaming) {
              _handleSend();
            }
            return KeyEventResult.handled;
          }
        }
      }
      return KeyEventResult.ignored;
    };
  }

  void insertTextAtStart(String text) {
    final currentText = _controller.text;
    _controller.text = text + currentText;
    _controller.selection = TextSelection.collapsed(offset: text.length);
  }

  void _handleSend() {
    if (_controller.text.trim().isEmpty || widget.isBlocked || widget.isStreaming) return;
    widget.onSendMessage(_controller.text.trim());
    _controller.clear();
    _focusNode.requestFocus();
  }

  void _handleStop() {
    widget.onStopStreaming?.call();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: !widget.isBlocked || widget.isStreaming,
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 8,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: widget.isStreaming
                    ? 'Generando respuesta...'
                    : widget.isBlocked
                        ? 'Procesando...'
                        : 'Escribe un mensaje...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: widget.isStreaming
                ? IconButton.filled(
                    icon: const Icon(Icons.stop),
                    onPressed: _handleStop,
                    tooltip: 'Detener generación',
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.error,
                      foregroundColor: colorScheme.onError,
                    ),
                  )
                : IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: (widget.isBlocked || !_hasText) ? null : _handleSend,
                    tooltip: 'Enviar',
                  ),
          ),
        ],
      ),
    );
  }
}