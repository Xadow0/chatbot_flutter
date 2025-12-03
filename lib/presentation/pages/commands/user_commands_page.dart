import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/command_entity.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/command_entity.dart';
import '../../providers/command_management_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/custom_drawer.dart';

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
                  ...provider.userCommands.map((cmd) => _buildCommandCard(context, cmd, isUserCommand: true)),

                const SizedBox(height: 24),
                
                const Padding(
                  padding: EdgeInsets.only(left: 8, bottom: 8),
                  child: Text('Comandos del Sistema', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ...provider.systemCommands.map((cmd) => _buildCommandCard(context, cmd, isUserCommand: false)),
                
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

  Widget _buildCommandCard(BuildContext context, CommandEntity command, {required bool isUserCommand}) {
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
              color: isUserCommand ? Colors.purple.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
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
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Monospace', color: Colors.purple),
              ),
              const SizedBox(width: 8),
              // Indicador de tipo de comando (Editable / No Editable)
              if (isUserCommand)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: command.isEditable 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    command.isEditable ? 'Editable' : 'Auto',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: command.isEditable ? Colors.green[700] : Colors.blue[700],
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
              
              // Refrescar quick responses en ChatProvider si está disponible
              try {
                await context.read<ChatProvider>().refreshQuickResponses();
              } catch (e) {
                // ChatProvider podría no estar disponible en todos los contextos
                debugPrint('⚠️ No se pudo refrescar quick responses: $e');
              }
            },
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
  
  /// Controla si el comando es editable o no
  /// - true: Al seleccionar desde quick_responses, se inserta el prompt completo
  /// - false: Al seleccionar, se inserta "/comando " (comportamiento tradicional)
  bool _isEditable = false;

  @override
  void initState() {
    super.initState();
    
    // Remover espacio final del trigger al editar
    String triggerText = widget.existingCommand?.trigger ?? '/';
    if (triggerText.endsWith(' ')) {
      triggerText = triggerText.substring(0, triggerText.length - 1);
    }
    
    _triggerCtrl = TextEditingController(text: triggerText);
    _titleCtrl = TextEditingController(text: widget.existingCommand?.title ?? '');
    _descriptionCtrl = TextEditingController(text: widget.existingCommand?.description ?? ''); 
    _promptCtrl = TextEditingController(text: widget.existingCommand?.promptTemplate ?? '');
    
    _hasContentPlaceholder = _promptCtrl.text.contains('{{content}}');
    
    // Inicializar el estado de isEditable desde el comando existente
    _isEditable = widget.existingCommand?.isEditable ?? false;
    
    // Listener para detectar cambios en el prompt
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
      // Si NO es editable y no tiene {{content}}, mostrar diálogo de confirmación
      // (Para comandos editables, el usuario edita el prompt directamente, 
      // así que {{content}} no es necesario)
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
      
      // Añadir espacio al final del trigger automáticamente
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
        isEditable: _isEditable, // ← NUEVO: Guardar el estado de editable
      );

      await context.read<CommandManagementProvider>().saveCommand(newCommand);
      
      // Refrescar quick responses en ChatProvider si está disponible
      try {
        await context.read<ChatProvider>().refreshQuickResponses();
      } catch (e) {
        // ChatProvider podría no estar disponible en todos los contextos
        debugPrint('⚠️ No se pudo refrescar quick responses: $e');
      }
      
      if (mounted) {
        Navigator.pop(context);
      }
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
                        // Eliminar espacios y enters automáticamente
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
              _buildPromptField(),
              const SizedBox(height: 12),
              
              // =================================================================
              // NUEVO: Switch para Editable / No Editable
              // =================================================================
              Container(
                decoration: BoxDecoration(
                  color: _isEditable 
                      ? Colors.green.withOpacity(0.05) 
                      : Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isEditable 
                        ? Colors.green.withOpacity(0.3) 
                        : Colors.blue.withOpacity(0.3),
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
                  activeColor: Colors.green,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                ),
              ),
              const SizedBox(height: 12),
              
              // =================================================================
              // Mensaje informativo sobre {{content}} - SOLO para modo Automático
              // =================================================================
              if (!_isEditable) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1), 
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
                
                // Mensaje de advertencia si no tiene {{content}} (solo en modo automático)
                if (!_hasContentPlaceholder) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1), 
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
              
              // Mensaje informativo para modo Editable
              if (_isEditable)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1), 
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
  
  Widget _buildPromptField() {
    return TextFormField(
      controller: _promptCtrl,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: 'Prompt (Template)', 
        hintText: 'Escribe tu prompt aquí...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
      validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
      // Usar el buildCounter para resaltar {{content}}
      buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
        return null; // No mostrar contador
      },
    );
  }
}

// Widget personalizado para el campo de prompt con highlight de {{content}}
// (Se mantiene por si se quiere usar en el futuro)
class _HighlightedPromptField extends StatelessWidget {
  final TextEditingController controller;
  final String? Function(String?)? validator;

  const _HighlightedPromptField({
    required this.controller,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      maxLines: 5,
      decoration: const InputDecoration(
        labelText: 'Prompt (Template)', 
        hintText: 'Escribe tu prompt aquí...',
        alignLabelWithHint: true,
        border: OutlineInputBorder(),
      ),
      validator: validator,
    );
  }
}