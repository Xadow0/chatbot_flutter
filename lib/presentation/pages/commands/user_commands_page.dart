import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/command_entity.dart';
import '../../providers/command_management_provider.dart';
import '../../providers/auth_provider.dart';

class UserCommandsPage extends StatefulWidget {
  const UserCommandsPage({super.key});

  @override
  State<UserCommandsPage> createState() => _UserCommandsPageState();
}

class _UserCommandsPageState extends State<UserCommandsPage> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final authProvider = context.read<AuthProvider>();
      final commandProvider = context.read<CommandManagementProvider>();
      
      await commandProvider.loadCommands(
        autoSync: authProvider.isCloudSyncEnabled,
      );
    });
  }

  void _showCommandDialog(BuildContext context, {CommandEntity? command}) {
    final commandProvider = context.read<CommandManagementProvider>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return ChangeNotifierProvider.value(
          value: commandProvider,
          child: _CommandEditorDialog(existingCommand: command),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommandManagementProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Comandos'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.purple, Colors.deepPurple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCommandDialog(context),
        backgroundColor: Colors.purple,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo Comando'),
      ),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (provider.userCommands.isEmpty)
                  _buildEmptyState(theme)
                else
                  ...provider.userCommands.map((cmd) => _buildCommandCard(context, cmd, isEditable: true)),

                const SizedBox(height: 24),
                
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text('Comandos del Sistema', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ...provider.systemCommands.map((cmd) => _buildCommandCard(context, cmd, isEditable: false)),
                
                const SizedBox(height: 80),
              ],
            ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.touch_app_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No has creado comandos personalizados',
              style: theme.textTheme.bodyLarge?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommandCard(BuildContext context, CommandEntity command, {required bool isEditable}) {
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
              color: isEditable ? Colors.purple.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isEditable ? Icons.bolt : Icons.lock_outline,
              color: isEditable ? Colors.purple : Colors.grey,
            ),
          ),
          title: Row(
            children: [
              Text(
                command.trigger,
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Monospace', color: Colors.purple),
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
          trailing: isEditable
              ? PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert),
                  onSelected: (value) {
                    if (value == 'edit') _showCommandDialog(context, command: command);
                    if (value == 'delete') _confirmDelete(context, command);
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(children: [Icon(Icons.edit, size: 20), SizedBox(width: 8), Text('Editar')]),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Eliminar', style: TextStyle(color: Colors.red))]),
                    ),
                  ],
                )
              : null,
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CommandEntity command) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar comando?'),
        content: Text('Se eliminará ${command.trigger} permanentemente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<CommandManagementProvider>().deleteCommand(command.id);
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CommandEditorDialog extends StatefulWidget {
  final CommandEntity? existingCommand;

  const _CommandEditorDialog({this.existingCommand});

  @override
  State<_CommandEditorDialog> createState() => _CommandEditorDialogState();
}

class _CommandEditorDialogState extends State<_CommandEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _triggerCtrl;
  late TextEditingController _titleCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _promptCtrl;

  @override
  void initState() {
    super.initState();
    _triggerCtrl = TextEditingController(text: widget.existingCommand?.trigger ?? '/');
    _titleCtrl = TextEditingController(text: widget.existingCommand?.title ?? '');
    _descriptionCtrl = TextEditingController(text: widget.existingCommand?.description ?? ''); 
    _promptCtrl = TextEditingController(text: widget.existingCommand?.promptTemplate ?? '');
  }

  @override
  void dispose() {
    _triggerCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      final isEditing = widget.existingCommand != null;
      
      final newCommand = CommandEntity(
        id: isEditing ? widget.existingCommand!.id : const Uuid().v4(),
        trigger: _triggerCtrl.text.trim(),
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        promptTemplate: _promptCtrl.text.trim(),
        systemType: SystemCommandType.none,
      );

      context.read<CommandManagementProvider>().saveCommand(newCommand);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingCommand == null ? 'Nuevo Comando' : 'Editar Comando'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _triggerCtrl,
                      decoration: const InputDecoration(labelText: 'Comando', hintText: '/cmd'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (!v.startsWith('/')) return 'Usa /';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(labelText: 'Nombre', hintText: 'Ej: Resumir'),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)', 
                  hintText: 'Breve explicación de lo que hace...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _promptCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Prompt (Template)', 
                  hintText: 'Escribe tu prompt aquí...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 8),
              
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.blue),
                    SizedBox(width: 8),
                    Expanded(child: Text('Usa {{content}} para insertar el texto que escribas después del comando.', style: TextStyle(fontSize: 11))),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}