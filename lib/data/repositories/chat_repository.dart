// lib/data/repositories/chat_repository.dart
import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart'; // <- Importar la interfaz del DOMINIO
import '../models/message_model.dart';

/// Repositorio para manejar operaciones de chat
/// Esta implementación local genera respuestas predefinidas
/// sin comunicación con IA o red.
class LocalChatRepository implements ChatRepository { // <- Implementar la interfaz
  final List<Message> _localMessages = [];

  @override
  Future<MessageEntity> sendMessage(String content) async {
    // Simular pequeña latencia local
    await Future.delayed(const Duration(milliseconds: 300));

    // Generar la respuesta local (eco)
    final botResponseContent = _generateLocalResponse(content);

    // Crear el modelo para almacenamiento (opcional si no se persiste)
    final botMessage = Message.bot(botResponseContent);
    _localMessages.add(botMessage);
    
    // Retornar la entidad de dominio
    return botMessage.toEntity();
  }

  /// Genera una respuesta local sin usar IA (movida desde el UseCase)
  String _generateLocalResponse(String userMessage) {
    return '''📝 **Eco del mensaje:**
"$userMessage"

💡 **Tip:** Para usar la IA, utiliza comandos como:
• `/tryprompt [tu pregunta]` - Mejora y evalúa tu prompt

📜 Próximamente: Modo chat directo con IA''';
  }

  @override
  Future<List<MessageEntity>> getMessageHistory() async {
    // Convertir todos los modelos almacenados a entidades
    return _localMessages.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> clearHistory() async {
    _localMessages.clear();
  }
}