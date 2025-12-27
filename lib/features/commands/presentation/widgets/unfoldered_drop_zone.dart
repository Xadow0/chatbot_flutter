import 'package:flutter/material.dart';
import '../../domain/entities/command_entity.dart';

class UnfolderedDropZone extends StatefulWidget {
  final List<CommandEntity> commands;
  final Function(CommandEntity) onEditCommand;
  final Function(CommandEntity) onDeleteCommand;
  final Function(String commandId) onDropCommand;
  final Widget Function(CommandEntity command) commandBuilder;

  const UnfolderedDropZone({
    super.key,
    required this.commands,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onDropCommand,
    required this.commandBuilder,
  });

  @override
  State<UnfolderedDropZone> createState() => _UnfolderedDropZoneState();
}

class _UnfolderedDropZoneState extends State<UnfolderedDropZone> {
  bool _isDragOver = false;

  @override
  Widget build(BuildContext context) {
    return DragTarget<CommandEntity>(
      onWillAcceptWithDetails: (details) {
        // Aceptar si el comando tiene carpeta asignada y no es de sistema
        final command = details.data;
        if (command.folderId != null && !command.isSystem) {
          setState(() => _isDragOver = true);
          return true;
        }
        return false;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        widget.onDropCommand(details.data.id);
      },
      builder: (context, candidateData, rejectedData) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: _isDragOver
              ? BoxDecoration(
                  color: Colors.purple.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.purple,
                    width: 2,
                    strokeAlign: BorderSide.strokeAlignOutside,
                  ),
                )
              : null,
          padding: _isDragOver ? const EdgeInsets.all(8) : EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 8, top: 8),
                child: Row(
                  children: [
                    Icon(
                      Icons.folder_off_outlined,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sin Carpeta',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (_isDragOver) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Soltar aquí',
                          style: TextStyle(
                            color: Colors.purple,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Lista de comandos o mensaje vacío
              if (widget.commands.isEmpty)
                _buildEmptyState()
              else
                ...widget.commands.map((cmd) => widget.commandBuilder(cmd)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No hay comandos sin carpeta',
              style: TextStyle(
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}