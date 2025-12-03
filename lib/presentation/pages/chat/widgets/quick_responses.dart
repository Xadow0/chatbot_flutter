import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../../data/models/quick_response_model.dart';

class QuickResponsesWidget extends StatelessWidget {
  final List<QuickResponse> responses;
  
  /// Callback cuando se selecciona una respuesta (click izquierdo normal)
  final Function(QuickResponse) onResponseSelected;
  
  /// Callback cuando se solicita editar un comando no editable (click derecho → "Editar")
  final Function(QuickResponse)? onEditRequested;

  const QuickResponsesWidget({
    super.key,
    required this.responses,
    required this.onResponseSelected,
    this.onEditRequested,
  });

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((0.5 * 255).round()),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Comandos Rápidos',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                const SizedBox(width: 12),
                ...responses.map((response) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _QuickResponseChip(
                      response: response,
                      onTap: () => onResponseSelected(response),
                      onEditTap: onEditRequested != null 
                          ? () => onEditRequested!(response)
                          : null,
                    ),
                  );
                }),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickResponseChip extends StatefulWidget {
  final QuickResponse response;
  final VoidCallback onTap;
  final VoidCallback? onEditTap;

  const _QuickResponseChip({
    required this.response,
    required this.onTap,
    this.onEditTap,
  });

  @override
  State<_QuickResponseChip> createState() => _QuickResponseChipState();
}

class _QuickResponseChipState extends State<_QuickResponseChip> {
  OverlayEntry? _overlayEntry;
  final LayerLink _layerLink = LayerLink();

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showContextMenu(BuildContext context, Offset globalPosition) {
    // Solo mostrar menú contextual si NO es editable
    if (widget.response.isEditable) return;
    if (widget.onEditTap == null) return;

    _removeOverlay();

    final overlay = Overlay.of(context);
    final renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Área táctil para cerrar el menú
          Positioned.fill(
            child: GestureDetector(
              onTap: _removeOverlay,
              behavior: HitTestBehavior.opaque,
              child: Container(color: Colors.transparent),
            ),
          ),
          // Menú contextual
          Positioned(
            left: globalPosition.dx - 50,
            top: globalPosition.dy - 60,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  _removeOverlay();
                  widget.onEditTap?.call();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.edit_note,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Editar prompt',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_overlayEntry!);
  }

  String _getTooltipText() {
    if (widget.response.isEditable) {
      return 'Click: Insertar prompt para editar';
    } else {
      return 'Click: Insertar comando\nClick derecho: Editar prompt';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditable = widget.response.isEditable;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Listener(
        // Detectar click derecho (botón secundario del mouse)
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons == kSecondaryMouseButton) {
            _showContextMenu(context, event.position);
          }
        },
        child: GestureDetector(
          // Click izquierdo normal
          onTap: widget.onTap,
          // Long press en móviles para mostrar menú contextual
          onLongPress: (!isEditable && widget.onEditTap != null)
              ? () {
                  final renderBox = context.findRenderObject() as RenderBox;
                  final position = renderBox.localToGlobal(Offset.zero);
                  _showContextMenu(
                    context,
                    Offset(position.dx + renderBox.size.width / 2, position.dy),
                  );
                }
              : null,
          child: Tooltip(
            message: _getTooltipText(),
            preferBelow: false,
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isEditable ? Icons.edit_note : Icons.bolt,
                    size: 14,
                    color: isEditable
                        ? Colors.green[700]
                        : Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    widget.response.text,
                    style: TextStyle(
                      fontSize: 13,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Indicador visual para comandos editables
                  if (isEditable) ...[
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ],
              ),
              onPressed: widget.onTap,
              backgroundColor: isEditable
                  ? Colors.green.withOpacity(0.1)
                  : Theme.of(context).colorScheme.secondaryContainer,
              side: isEditable
                  ? BorderSide(color: Colors.green.withOpacity(0.3))
                  : BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}