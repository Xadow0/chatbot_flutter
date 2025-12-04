import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../../../domain/entities/command_folder_entity.dart';

class FolderEditorDialog extends StatefulWidget {
  final CommandFolderEntity? existingFolder;

  const FolderEditorDialog({super.key, this.existingFolder});

  @override
  State<FolderEditorDialog> createState() => _FolderEditorDialogState();
}

class _FolderEditorDialogState extends State<FolderEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  String? _selectedIcon;

  static const List<String> _availableIcons = [
    '📁', '📂', '🗂️', '💼', '🏠', '⭐', '❤️', '🔥',
    '💡', '🎯', '🚀', '💻', '📝', '📊', '🔧', '⚡',
    '🎨', '📚', '🔬', '🌐', '🛠️', '📌', '🏷️', '✨',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existingFolder?.name ?? '');
    _selectedIcon = widget.existingFolder?.icon ?? '📁';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final folder = CommandFolderEntity(
        id: widget.existingFolder?.id ?? const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        icon: _selectedIcon,
        order: widget.existingFolder?.order ?? 0,
        createdAt: widget.existingFolder?.createdAt ?? DateTime.now(),
      );

      Navigator.pop(context, folder);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingFolder != null;

    return AlertDialog(
      title: Text(isEditing ? 'Editar Carpeta' : 'Nueva Carpeta'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Campo de nombre
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nombre de la carpeta',
                  hintText: 'Ej: Trabajo, Personal...',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'El nombre es requerido';
                  }
                  if (v.trim().length > 30) {
                    return 'Máximo 30 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Selector de icono
              Text(
                'Icono',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: _availableIcons.map((icon) {
                    final isSelected = icon == _selectedIcon;
                    return InkWell(
                      onTap: () => setState(() => _selectedIcon = icon),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.purple.withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: isSelected
                              ? Border.all(color: Colors.purple, width: 2)
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            icon,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(isEditing ? 'Guardar' : 'Crear'),
        ),
      ],
    );
  }
}