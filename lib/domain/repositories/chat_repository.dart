// lib/domain/repositories/chat_repository.dart
import '../entities/message_entity.dart';

/// Interfaz del repositorio para manejar operaciones de chat.
/// Define el contrato que la capa de datos debe implementar.
abstract class ChatRepository {
  /// Envía un mensaje y recibe la respuesta del bot.
  Future<MessageEntity> sendMessage(String content);

  /// Obtiene el historial de mensajes (si aplica).
  Future<List<MessageEntity>> getMessageHistory();

  /// Limpia el historial (si aplica).
  Future<void> clearHistory();
}