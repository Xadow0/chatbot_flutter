import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/command_entity.dart';
import '../../../domain/entities/command_folder_entity.dart';
import '../../providers/command_management_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/custom_drawer.dart';
import 'widgets/folder_editor_dialog.dart';
import 'widgets/command_folder_widget.dart';
import 'widgets/draggable_command_card.dart';
import 'widgets/unfoldered_drop_zone.dart';

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

  // ============================================================================
  // DIÁLOGOS
  // ============================================================================

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

  void _showFolderDialog(BuildContext context, {CommandFolderEntity? folder}) async {
    final result = await showDialog<CommandFolderEntity>(
      context: context,
      builder: (dialogContext) => FolderEditorDialog(existingFolder: folder),
    );

    if (result != null && mounted) {
      await context.read<CommandManagementProvider>().saveFolder(result);
    }
  }

  void _confirmDeleteCommand(BuildContext context, CommandEntity command) {
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
              _refreshQuickResponses();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteFolder(BuildContext context, CommandFolderEntity folder, int commandCount) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Eliminar carpeta?'),
        content: Text(
          commandCount > 0
              ? 'Se eliminará "${folder.name}" y sus $commandCount comando(s) se moverán a "Sin Carpeta".'
              : 'Se eliminará la carpeta "${folder.name}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await context.read<CommandManagementProvider>().deleteFolder(folder.id);
              _refreshQuickResponses();
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _refreshQuickResponses() {
    try {
      context.read<ChatProvider>().refreshQuickResponses();
    } catch (e) {
      debugPrint('⚠️ No se pudo refrescar quick responses: $e');
    }
  }

  // ============================================================================
  // BUILD
  // ============================================================================

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommandManagementProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      drawer: const CustomDrawer(),
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
      floatingActionButton: _buildFAB(context),
      body: provider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, provider, theme),
    );
  }

  Widget _buildFAB(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Botón Nueva Carpeta
        FloatingActionButton.small(
          heroTag: 'newFolder',
          onPressed: () => _showFolderDialog(context),
          backgroundColor: Colors.deepPurple.shade300,
          child: const Icon(Icons.create_new_folder),
        ),
        const SizedBox(height: 12),
        // Botón Nuevo Comando
        FloatingActionButton.extended(
          heroTag: 'newCommand',
          onPressed: () => _showCommandDialog(context),
          backgroundColor: Colors.purple,
          icon: const Icon(Icons.add),
          label: const Text('Nuevo Comando'),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, CommandManagementProvider provider, ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Checkbox para agrupar comandos del sistema
        _buildGroupSystemSwitch(provider),
        const SizedBox(height: 16),

        // Carpetas del usuario
        if (provider.folders.isNotEmpty) ...[
          ...provider.folders.map((folder) {
            final commandsInFolder = provider.getCommandsInFolder(folder.id);
            return CommandFolderWidget(
              folder: folder,
              commands: commandsInFolder,
              onEditCommand: (cmd) => _showCommandDialog(context, command: cmd),
              onDeleteCommand: (cmd) => _confirmDeleteCommand(context, cmd),
              onEditFolder: () => _showFolderDialog(context, folder: folder),
              onDeleteFolder: () => _confirmDeleteFolder(context, folder, commandsInFolder.length),
              onMoveCommand: (cmdId, folderId) async {
                await provider.moveCommandToFolder(cmdId, folderId);
                _refreshQuickResponses();
              },
            );
          }),
          const SizedBox(height: 8),
        ],

        // Comandos sin carpeta
        if (provider.userCommands.isNotEmpty || provider.folders.isEmpty)
          UnfolderedDropZone(
            commands: provider.commandsWithoutFolder,
            onEditCommand: (cmd) => _showCommandDialog(context, command: cmd),
            onDeleteCommand: (cmd) => _confirmDeleteCommand(context, cmd),
            onDropCommand: (cmdId) async {
              await provider.moveCommandToFolder(cmdId, null);
              _refreshQuickResponses();
            },
            commandBuilder: (cmd) => DraggableCommandCard(
              command: cmd,
              isUserCommand: true,
              onEdit: () => _showCommandDialog(context, command: cmd),
              onDelete: () => _confirmDeleteCommand(context, cmd),
            ),
          ),

        // Estado vacío si no hay comandos de usuario
        if (provider.userCommands.isEmpty && provider.folders.isEmpty)
          _buildEmptyState(theme),

        const SizedBox(height: 24),

        // Comandos del sistema
        _buildSystemCommandsSection(provider),

        const SizedBox(height: 80), // Espacio para el FAB
      ],
    );
  }

  Widget _buildGroupSystemSwitch(CommandManagementProvider provider) {
    return Card(
      child: SwitchListTile(
        title: const Text('Agrupar comandos del sistema'),
        subtitle: Text(
          provider.groupSystemCommands
              ? 'Los comandos del sistema se muestran en una carpeta'
              : 'Los comandos del sistema se muestran individualmente',
          style: const TextStyle(fontSize: 12),
        ),
        secondary: Icon(
          provider.groupSystemCommands ? Icons.folder : Icons.folder_off_outlined,
          color: Colors.grey,
        ),
        value: provider.groupSystemCommands,
        onChanged: (value) => provider.setGroupSystemCommands(value),
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
            const SizedBox(height: 8),
            Text(
              'Pulsa el botón "Nuevo Comando" para empezar',
              style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemCommandsSection(CommandManagementProvider provider) {
    final systemCommands = provider.systemCommands;

    if (provider.groupSystemCommands) {
      // Mostrar como carpeta colapsable
      return Card(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ExpansionTile(
          leading: const Text('🔒', style: TextStyle(fontSize: 20)),
          title: const Text(
            'Comandos del Sistema',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${systemCommands.length} comandos',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          children: systemCommands
              .map((cmd) => _buildSystemCommandTile(cmd))
              .toList(),
        ),
      );
    } else {
      // Mostrar individualmente
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Comandos del Sistema',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          ...systemCommands.map(
            (cmd) => DraggableCommandCard(
              command: cmd,
              isUserCommand: false,
            ),
          ),
        ],
      );
    }
  }

  Widget _buildSystemCommandTile(CommandEntity command) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
      title: Row(
        children: [
          Text(
            command.trigger,
            style: const TextStyle(
              fontFamily: 'Monospace',
              fontWeight: FontWeight.bold,
              color: Colors.purple,
              fontSize: 13,
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
      subtitle: command.description.isNotEmpty
          ? Text(
              command.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            )
          : null,
    );
  }
}

// =============================================================================
// DIÁLOGO DE EDICIÓN DE COMANDOS
// =============================================================================

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

  bool _hasContentPlaceholder = false;
  bool _isEditable = false;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();

    String triggerText = widget.existingCommand?.trigger ?? '/';
    if (triggerText.endsWith(' ')) {
      triggerText = triggerText.substring(0, triggerText.length - 1);
    }

    _triggerCtrl = TextEditingController(text: triggerText);
    _titleCtrl = TextEditingController(text: widget.existingCommand?.title ?? '');
    _descriptionCtrl = TextEditingController(text: widget.existingCommand?.description ?? '');
    _promptCtrl = TextEditingController(text: widget.existingCommand?.promptTemplate ?? '');

    _hasContentPlaceholder = _promptCtrl.text.contains('{{content}}');
    _isEditable = widget.existingCommand?.isEditable ?? false;
    _selectedFolderId = widget.existingCommand?.folderId;

    _promptCtrl.addListener(() {
      final newHasContent = _promptCtrl.text.contains('{{content}}');
      if (newHasContent != _hasContentPlaceholder) {
        setState(() {
          _hasContentPlaceholder = newHasContent;
        });
      }
    });
  }

  @override
  void dispose() {
    _triggerCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _promptCtrl.dispose();
    super.dispose();
  }

  void _save() async {
    if (_formKey.currentState!.validate()) {
      if (!_isEditable && !_hasContentPlaceholder) {
        final shouldContinue = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange),
                SizedBox(width: 8),
                Text('Comando sin {{content}}'),
              ],
            ),
            content: const Text(
              'El prompt no contiene {{content}}, por lo que el comando no podrá usar texto personalizado.\n\n¿Deseas guardar el comando de todas formas?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Guardar sin {{content}}'),
              ),
            ],
          ),
        );

        if (shouldContinue != true) return;
      }

      final isEditing = widget.existingCommand != null;

      String finalTrigger = _triggerCtrl.text.trim();
      if (!finalTrigger.endsWith(' ')) {
        finalTrigger += ' ';
      }

      final newCommand = CommandEntity(
        id: isEditing ? widget.existingCommand!.id : const Uuid().v4(),
        trigger: finalTrigger,
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim(),
        promptTemplate: _promptCtrl.text.trim(),
        systemType: SystemCommandType.none,
        isEditable: _isEditable,
        folderId: _selectedFolderId,
      );

      await context.read<CommandManagementProvider>().saveCommand(newCommand);

      try {
        await context.read<ChatProvider>().refreshQuickResponses();
      } catch (e) {
        debugPrint('⚠️ No se pudo refrescar quick responses: $e');
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<CommandManagementProvider>();
    final folders = provider.folders;

    return AlertDialog(
      title: Text(widget.existingCommand == null ? 'Nuevo Comando' : 'Editar Comando'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Fila: Comando + Nombre ---
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: TextFormField(
                      controller: _triggerCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Comando',
                        hintText: '/cmd',
                      ),
                      onChanged: (value) {
                        final cleanValue = value.replaceAll(RegExp(r'[\s\n\r]'), '');
                        if (value != cleanValue) {
                          _triggerCtrl.value = TextEditingValue(
                            text: cleanValue,
                            selection: TextSelection.collapsed(offset: cleanValue.length),
                          );
                        }
                      },
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Requerido';
                        if (!v.startsWith('/')) return 'Debe comenzar con /';
                        if (v.contains(RegExp(r'[\s\n\r]'))) return 'No debe contener espacios';
                        if (v.length <= 1) return 'Muy corto';
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
                      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // --- Selector de Carpeta ---
              DropdownButtonFormField<String?>(
                initialValue: _selectedFolderId,
                decoration: const InputDecoration(
                  labelText: 'Carpeta',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Row(
                      children: [
                        Icon(Icons.folder_off_outlined, size: 18),
                        SizedBox(width: 8),
                        Text('Sin carpeta'),
                      ],
                    ),
                  ),
                  ...folders.map((folder) => DropdownMenuItem<String?>(
                        value: folder.id,
                        child: Row(
                          children: [
                            Text(folder.icon ?? '📁', style: const TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(folder.name),
                          ],
                        ),
                      )),
                ],
                onChanged: (value) => setState(() => _selectedFolderId = value),
              ),
              const SizedBox(height: 16),

              // --- Descripción ---
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

              // --- Prompt ---
              TextFormField(
                controller: _promptCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Prompt (Template)',
                  hintText: 'Escribe tu prompt aquí...',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              ),
              const SizedBox(height: 12),

              // --- Switch Editable/Automático ---
              Container(
                decoration: BoxDecoration(
                  // CAMBIO: withOpacity -> withValues
                  color: _isEditable ? Colors.green.withValues(alpha: 0.05) : Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    // CAMBIO: withOpacity -> withValues
                    color: _isEditable ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3),
                  ),
                ),
                child: SwitchListTile(
                  title: Text(
                    _isEditable ? 'Modo: Editable' : 'Modo: Automático',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: _isEditable ? Colors.green[700] : Colors.blue[700],
                    ),
                  ),
                  subtitle: Text(
                    _isEditable
                        ? 'Al seleccionar, se insertará el prompt completo para que puedas editarlo antes de enviar.'
                        : 'Al seleccionar, se insertará "/comando" y se procesará automáticamente con el texto que escribas.',
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: _isEditable,
                  onChanged: (value) => setState(() => _isEditable = value),
                  activeThumbColor: Colors.green,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
              const SizedBox(height: 12),

              // --- Mensajes informativos ---
              if (!_isEditable) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // CAMBIO: withOpacity -> withValues
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Usa {{content}} para insertar el texto que escribas después del comando.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
                if (!_hasContentPlaceholder) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      // CAMBIO: withOpacity -> withValues
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_outlined, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Sin {{content}}, el comando no podrá usar texto adicional.',
                            style: TextStyle(fontSize: 11, color: Colors.orange[800]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
              if (_isEditable)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    // CAMBIO: withOpacity -> withValues
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.edit_note, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'El prompt se insertará completo en el chat para que puedas modificarlo antes de enviarlo.',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
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