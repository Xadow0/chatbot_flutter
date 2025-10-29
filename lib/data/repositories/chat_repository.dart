import '../../domain/entities/message_entity.dart';
import '../models/message_model.dart';

/// Repositorio para manejar operaciones de chat
/// Esta implementación local genera respuestas predefinidas
/// sin comunicación con IA o red.
/// 
/// IMPORTANTE: Este repositorio trabaja con ENTIDADES (domain layer)
/// y usa modelos (data layer) solo para persistencia.
abstract class ChatRepository {
  Future<MessageEntity> sendMessage(String content);
  Future<List<MessageEntity>> getMessageHistory();
  Future<void> clearHistory();
}

class LocalChatRepository implements ChatRepository {
  final List<Message> _localMessages = [];

  @override
  Future<MessageEntity> sendMessage(String content) async {
    // Simular pequeña latencia local
    await Future.delayed(const Duration(milliseconds: 300));

    // Crear el modelo para almacenamiento
    final botMessage = Message.bot('¡Hola! Recibí tu mensaje: $content');
    _localMessages.add(botMessage);
    
    // Retornar la entidad de dominio
    return botMessage.toEntity();
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