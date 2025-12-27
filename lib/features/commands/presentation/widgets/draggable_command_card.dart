import 'package:flutter/material.dart';
import '../../domain/entities/command_entity.dart';

class DraggableCommandCard extends StatelessWidget {
  final CommandEntity command;
  final bool isUserCommand;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const DraggableCommandCard({
    super.key,
    required this.command,
    required this.isUserCommand,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final card = _buildCard(context);

    // Solo los comandos de usuario son arrastrables
    if (!isUserCommand) {
      return card;
    }

    return Draggable<CommandEntity>(
      data: command,
      feedback: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.purple.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.purple, width: 2),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.drag_indicator, color: Colors.purple),
              const SizedBox(width: 8),
              Text(
                command.trigger,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Monospace',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  command.title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.4,
        child: card,
      ),
      child: card,
    );
  }

  Widget _buildCard(BuildContext context) {
    final hasDescription = command.description.isNotEmpty;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isUserCommand
                  ? Colors.purple.withValues(alpha: 0.1)
                  : Colors.grey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isUserCommand ? Icons.bolt : Icons.lock_outline,
              color: isUserCommand ? Colors.purple : Colors.grey,
            ),
          ),
          title: Row(
            children: [
              Text(
                command.trigger,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Monospace',
                  color: Colors.purple,
                ),
              ),
              const SizedBox(width: 8),
              // Indicador de tipo de comando (Editable / No Editable)
              if (isUserCommand)
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
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: command.isEditable
                          ? Colors.green[700]
                          : Colors.blue[700],
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  command.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          subtitle: hasDescription
              ? Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    command.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                )
              : null,
          trailing: isUserCommand
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') onEdit?.call();
                    if (value == 'delete') onDelete?.call();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Eliminar', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }
}