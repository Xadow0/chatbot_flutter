import 'package:flutter/material.dart';
import '../../domain/entities/command_entity.dart';
import '../../domain/entities/command_folder_entity.dart';

class CommandFolderWidget extends StatefulWidget {
  final CommandFolderEntity folder;
  final List<CommandEntity> commands;
  final Function(CommandEntity) onEditCommand;
  final Function(CommandEntity) onDeleteCommand;
  final Function() onEditFolder;
  final Function() onDeleteFolder;
  final Function(String commandId, String? folderId) onMoveCommand;
  final bool initiallyExpanded;

  const CommandFolderWidget({
    super.key,
    required this.folder,
    required this.commands,
    required this.onEditCommand,
    required this.onDeleteCommand,
    required this.onEditFolder,
    required this.onDeleteFolder,
    required this.onMoveCommand,
    this.initiallyExpanded = false,
  });

  @override
  State<CommandFolderWidget> createState() => _CommandFolderWidgetState();
}

class _CommandFolderWidgetState extends State<CommandFolderWidget> {
  late bool _isExpanded;
  bool _isDragOver = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded || widget.commands.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final commandCount = widget.commands.length;

    return DragTarget<CommandEntity>(
      onWillAcceptWithDetails: (details) {
        // Aceptar si el comando no está ya en esta carpeta
        final command = details.data;
        if (command.folderId != widget.folder.id && !command.isSystem) {
          setState(() => _isDragOver = true);
          return true;
        }
        return false;
      },
      onLeave: (_) => setState(() => _isDragOver = false),
      onAcceptWithDetails: (details) {
        setState(() => _isDragOver = false);
        widget.onMoveCommand(details.data.id, widget.folder.id);
      },
      builder: (context, candidateData, rejectedData) {
        return Card(
          elevation: _isDragOver ? 4 : 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: _isDragOver
                ? const BorderSide(color: Colors.purple, width: 2)
                : BorderSide.none,
          ),
          color: _isDragOver ? Colors.purple.withValues(alpha: 0.05) : null,
          child: Column(
            children: [
              // Header de la carpeta
              InkWell(
                onTap: () => setState(() => _isExpanded = !_isExpanded),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      // Icono de expansión
                      AnimatedRotation(
                        turns: _isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.chevron_right, size: 24),
                      ),
                      const SizedBox(width: 4),
                      
                      // Icono de carpeta
                      Text(
                        widget.folder.icon ?? '📁',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 10),
                      
                      // Nombre de carpeta
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.folder.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '$commandCount comando${commandCount != 1 ? 's' : ''}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Menú de opciones
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 20),
                        onSelected: (value) {
                          if (value == 'edit') widget.onEditFolder();
                          if (value == 'delete') widget.onDeleteFolder();
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 20),
                                SizedBox(width: 8),
                                Text('Editar carpeta'),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Eliminar carpeta',
                                  style: TextStyle(color: Colors.red[700]),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              
              // Contenido expandible (comandos)
              AnimatedCrossFade(
                firstChild: const SizedBox.shrink(),
                secondChild: _buildCommandsList(),
                crossFadeState: _isExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommandsList() {
    if (widget.commands.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: Text(
            'Arrastra comandos aquí',
            style: TextStyle(
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Column(
        children: widget.commands.map((command) {
          return _DraggableCommandTile(
            command: command,
            onEdit: () => widget.onEditCommand(command),
            onDelete: () => widget.onDeleteCommand(command),
            onRemoveFromFolder: () => widget.onMoveCommand(command.id, null),
          );
        }).toList(),
      ),
    );
  }
}

class _DraggableCommandTile extends StatelessWidget {
  final CommandEntity command;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onRemoveFromFolder;

  const _DraggableCommandTile({
    required this.command,
    required this.onEdit,
    required this.onDelete,
    required this.onRemoveFromFolder,
  });

  @override
  Widget build(BuildContext context) {
    return Draggable<CommandEntity>(
      data: command,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.purple),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator, size: 18, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                command.trigger,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Monospace',
                  color: Colors.purple,
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: _buildTile(context),
      ),
      child: _buildTile(context),
    );
  }

  Widget _buildTile(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 48, right: 8),
      leading: const Icon(Icons.bolt, color: Colors.purple, size: 20),
      title: Row(
        children: [
          Text(
            command.trigger,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontFamily: 'Monospace',
              color: Colors.purple,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 8),
          // Badge editable/auto
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: command.isEditable
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              command.isEditable ? 'Editable' : 'Auto',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: command.isEditable ? Colors.green[700] : Colors.blue[700],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              command.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert, size: 18),
        onSelected: (value) {
          if (value == 'edit') onEdit();
          if (value == 'delete') onDelete();
          if (value == 'remove') onRemoveFromFolder();
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 18),
                SizedBox(width: 8),
                Text('Editar'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.drive_file_move_outline, size: 18),
                SizedBox(width: 8),
                Text('Sacar de carpeta'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, color: Colors.red[400], size: 18),
                const SizedBox(width: 8),
                Text('Eliminar', style: TextStyle(color: Colors.red[400])),
              ],
            ),
          ),
        ],
      ),
    );
  }
}