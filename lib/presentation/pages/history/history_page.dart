import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../presentation/providers/chat_provider.dart';
import '../../../presentation/pages/chat/chat_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<File> _conversations = [];
  final Set<int> _selectedIndices = {};

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final provider = context.read<ChatProvider>();
    final conversations = await provider.listConversations();
    
    setState(() {
      _conversations = conversations.cast<File>();
      _selectedIndices.clear();
    });
  }

  void _toggleSelection(int index) {
    setState(() {
      if (_selectedIndices.contains(index)) {
        _selectedIndices.remove(index);
      } else {
        _selectedIndices.add(index);
      }
    });
  }

  Future<void> _deleteConversation(File file) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar conversación'),
        content: const Text('¿Seguro que deseas eliminar esta conversación?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Conversación eliminada')),
          );
          await _loadConversations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIndices.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar conversaciones'),
        content: Text(
          '¿Deseas eliminar ${_selectedIndices.length} conversación${_selectedIndices.length > 1 ? 'es' : ''}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final provider = context.read<ChatProvider>();
        final filesToDelete = _selectedIndices
            .map((i) => _conversations[i])
            .toList();
        
        await provider.deleteConversations(filesToDelete);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${_selectedIndices.length} conversación${_selectedIndices.length > 1 ? 'es' : ''} eliminada${_selectedIndices.length > 1 ? 's' : ''}'
              ),
            ),
          );
          await _loadConversations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteAll() async {
    if (_conversations.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar todo el historial'),
        content: const Text(
          '¿Estás seguro de que deseas eliminar TODAS las conversaciones?\n\nEsta acción no se puede deshacer.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Eliminar todo',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final provider = context.read<ChatProvider>();
        await provider.deleteAllConversations();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Todo el historial ha sido eliminado')),
          );
          await _loadConversations();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al eliminar historial: $e')),
          );
        }
      }
    }
  }

  void _openConversation(File file) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatPage(preloadedConversationFile: file),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSelections = _selectedIndices.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial de conversaciones'),
      ),
      body: Column(
        children: [
          // Barra de opciones
          if (_conversations.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _deleteAll,
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    label: const Text(
                      'Eliminar historial',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          
          // Botón de eliminar seleccionadas (aparece cuando hay selecciones)
          if (hasSelections)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red.withOpacity(0.1),
              child: ElevatedButton.icon(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete),
                label: Text(
                  'Borrar ${_selectedIndices.length} seleccionada${_selectedIndices.length > 1 ? 's' : ''}',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),

          // Lista de conversaciones
          Expanded(
            child: _conversations.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No hay conversaciones guardadas',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _conversations.length,
                    itemBuilder: (context, index) {
                      final file = _conversations[index];
                      final name = file.path.split(Platform.pathSeparator).last;
                      final isSelected = _selectedIndices.contains(index);

                      return ListTile(
                        leading: IconButton(
                          icon: Icon(
                            isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                            color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
                          ),
                          onPressed: () => _toggleSelection(index),
                          tooltip: 'Seleccionar',
                        ),
                        title: Text(name),
                        onTap: () => _openConversation(file),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          tooltip: 'Eliminar conversación',
                          onPressed: () => _deleteConversation(file),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}