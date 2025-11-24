import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Necesario para LogicalKeyboardKey y HardwareKeyboard

class MessageInput extends StatefulWidget {
  final Function(String) onSendMessage;
  final bool isBlocked;

  const MessageInput({
    super.key,
    required this.onSendMessage,
    this.isBlocked = false,
  });

  @override
  State<MessageInput> createState() => MessageInputState();
}

class MessageInputState extends State<MessageInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // Nodo para interceptar teclas

  @override
  void initState() {
    super.initState();
    // Configurar la intercepción de teclas directamente en el FocusNode
    _focusNode.onKeyEvent = (node, event) {
      // Solo nos interesa cuando la tecla se "baja" (KeyDown)
      if (event is KeyDownEvent) {
        // Si es la tecla ENTER
        if (event.logicalKey == LogicalKeyboardKey.enter) {
          // Verificamos si SHIFT está presionado
          if (HardwareKeyboard.instance.isShiftPressed) {
            // Shift + Enter: Dejar pasar el evento para que haga el salto de línea normal
            return KeyEventResult.ignored;
          } else {
            // Solo Enter: Enviar mensaje y detener la propagación (para no insertar \n)
            // Solo enviamos si no está bloqueado
            if (!widget.isBlocked) {
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
    if (_controller.text.trim().isEmpty || widget.isBlocked) return;
    widget.onSendMessage(_controller.text.trim());
    _controller.clear();
    // Opcional: Mantener el foco en el input después de enviar
    _focusNode.requestFocus(); 
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose(); // Importante limpiar el nodo
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
        crossAxisAlignment: CrossAxisAlignment.end, // Alinea el botón abajo si el texto crece
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode, // Vinculamos el FocusNode aquí
              enabled: !widget.isBlocked,
              
              // --- CONFIGURACIÓN DINÁMICA ---
              keyboardType: TextInputType.multiline,
              minLines: 1,
              maxLines: 8, // Crece hasta 8 líneas
              textInputAction: TextInputAction.newline, // Mantiene el botón de 'Enter' visualmente
              // ------------------------------

              decoration: InputDecoration(
                hintText: widget.isBlocked
                    ? 'Procesando respuesta...'
                    : 'Escribe un mensaje...',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              // Ya no usamos onSubmitted porque lo manejamos manualmente en el FocusNode
            ),
          ),
          const SizedBox(width: 8),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: widget.isBlocked ? null : _handleSend,
              tooltip: 'Enviar',
            ),
          ),
        ],
      ),
    );
  }
}