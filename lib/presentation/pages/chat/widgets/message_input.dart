import 'package:flutter/material.dart';

class MessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isBlocked;

  const MessageInput({
    super.key,
    required this.onSendMessage,
    this.isBlocked = false,
  });

  @override
  State<MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();

  void _handleSend() {
    if (_controller.text.trim().isEmpty || widget.isBlocked) return;
    widget.onSendMessage(_controller.text.trim());
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !widget.isBlocked,
              decoration: InputDecoration(
                hintText: widget.isBlocked
                    ? 'Procesando respuesta...'
                    : 'Escribe un mensaje...',
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            icon: const Icon(Icons.send),
            onPressed: widget.isBlocked ? null : _handleSend,
            tooltip: 'Enviar',
          ),
        ],
      ),
    );
  }
}
