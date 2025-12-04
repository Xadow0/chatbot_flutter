import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../../../../data/models/quick_response_model.dart';

class QuickResponsesWidget extends StatefulWidget {
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
  State<QuickResponsesWidget> createState() => _QuickResponsesWidgetState();
}

class _QuickResponsesWidgetState extends State<QuickResponsesWidget> {
  /// Carpeta actualmente expandida (null = vista principal)
  String? _expandedFolderId;
  
  /// Nombre de la carpeta expandida para el breadcrumb
  String? _expandedFolderName;
  String? _expandedFolderIcon;

  void _openFolder(QuickResponse folder) {
    setState(() {
      _expandedFolderId = folder.folderId;
      _expandedFolderName = folder.text;
      _expandedFolderIcon = folder.folderIcon;
    });
  }

  void _closeFolder() {
    setState(() {
      _expandedFolderId = null;
      _expandedFolderName = null;
      _expandedFolderIcon = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.responses.isEmpty) return const SizedBox.shrink();

    // Si hay una carpeta expandida, mostrar sus comandos
    if (_expandedFolderId != null) {
      final folder = widget.responses.firstWhere(
        (r) => r.folderId == _expandedFolderId,
        orElse: () {
          // Si no se encuentra, cerrar la carpeta
          Future.microtask(() => _closeFolder());
          return widget.responses.first;
        },
      );
      
      if (folder.isFolder && folder.children != null) {
        return _buildFolderContent(folder);
      }
    }

    return _buildMainView();
  }

  Widget _buildMainView() {
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
                ...widget.responses.map((response) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: response.isFolder
                        ? _FolderChip(
                            response: response,
                            onTap: () => _openFolder(response),
                          )
                        : _QuickResponseChip(
                            response: response,
                            onTap: () => widget.onResponseSelected(response),
                            onEditTap: widget.onEditRequested != null
                                ? () => widget.onEditRequested!(response)
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

  Widget _buildFolderContent(QuickResponse folder) {
    final children = folder.children ?? [];

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
          // Breadcrumb / Header con botón volver
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                // Botón volver
                InkWell(
                  onTap: _closeFolder,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_back,
                          size: 14,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Volver',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Nombre de la carpeta
                Text(
                  _expandedFolderIcon ?? '📁',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _expandedFolderName ?? '',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Contador de comandos
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${children.length}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Lista de comandos
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                const SizedBox(width: 12),
                if (children.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Carpeta vacía',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontStyle: FontStyle.italic,
                        fontSize: 13,
                      ),
                    ),
                  )
                else
                  ...children.map((child) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _QuickResponseChip(
                        response: child,
                        onTap: () => widget.onResponseSelected(child),
                        onEditTap: widget.onEditRequested != null
                            ? () => widget.onEditRequested!(child)
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

// =============================================================================
// CHIP DE CARPETA
// =============================================================================

class _FolderChip extends StatelessWidget {
  final QuickResponse response;
  final VoidCallback onTap;

  const _FolderChip({
    required this.response,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final childCount = response.children?.length ?? 0;

    return Tooltip(
      message: '$childCount comando${childCount != 1 ? 's' : ''} - Click para abrir',
      preferBelow: false,
      child: ActionChip(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              response.folderIcon ?? '📁',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(width: 4),
            Text(
              response.text,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            // Badge con cantidad
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$childCount',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.chevron_right,
              size: 16,
              color: Theme.of(context).colorScheme.onSecondaryContainer.withValues(alpha: 0.7),
            ),
          ],
        ),
        onPressed: onTap,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}

// =============================================================================
// CHIP DE COMANDO
// =============================================================================

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
    } else if (widget.response.isSystem) {
      return 'Click: Insertar comando\nClick derecho: Editar prompt';
    } else {
      return 'Click: Insertar comando\nClick derecho: Editar prompt';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditable = widget.response.isEditable;
    final isSystem = widget.response.isSystem;

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
                    isSystem 
                        ? Icons.lock_outline 
                        : (isEditable ? Icons.edit_note : Icons.bolt),
                    size: 14,
                    color: isSystem
                        ? Colors.grey[600]
                        : (isEditable
                            ? Colors.green[700]
                            : Theme.of(context).colorScheme.onSecondaryContainer),
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
              backgroundColor: isSystem
                  ? Colors.grey.withValues(alpha: 0.15)
                  : (isEditable
                      ? Colors.green.withValues(alpha: 0.1)
                      : Theme.of(context).colorScheme.secondaryContainer),
              side: isEditable
                  ? BorderSide(color: Colors.green.withValues(alpha: 0.3))
                  : (isSystem 
                      ? BorderSide(color: Colors.grey.withValues(alpha: 0.3))
                      : BorderSide.none),
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