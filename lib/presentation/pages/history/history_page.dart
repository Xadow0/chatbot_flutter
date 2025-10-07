import 'dart:io';
import 'package:flutter/material.dart';
import '../../../data/repositories/conversation_repository.dart';
import '../../../presentation/pages/chat/chat_page.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  List<File> _conversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
  }

  Future<void> _loadConversations() async {
    final conversations = await ConversationRepository.listConversations();
    setState(() {
      _conversations = conversations.cast<File>();
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversación eliminada')),
        );
        await _loadConversations(); // Actualiza la lista
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar: $e')),
        );
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
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de conversaciones')),
      body: _conversations.isEmpty
          ? const Center(child: Text('No hay conversaciones guardadas'))
          : ListView.builder(
              itemCount: _conversations.length,
              itemBuilder: (context, index) {
                final file = _conversations[index];
                final name = file.path.split(Platform.pathSeparator).last;
                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
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
    );
  }
}

