/// ============================================================================
/// CHAT REPOSITORY - INTERFAZ (DOMAIN LAYER)
/// ============================================================================
/// 
/// Define el contrato que la capa de datos debe implementar.
/// Incluye métodos tanto para envío tradicional como con streaming.
/// 
/// UBICACIÓN: lib/domain/repositories/chat_repository.dart
/// ============================================================================

import '../entities/message_entity.dart';

/// Interfaz del repositorio para manejar operaciones de chat.
abstract class ChatRepository {
  /// Envía un mensaje y recibe la respuesta completa del bot.
  /// 
  /// Método tradicional que espera a que la respuesta esté completa.
  Future<MessageEntity> sendMessage(String content);

  /// Envía un mensaje y recibe la respuesta con streaming.
  /// 
  /// El Stream emite MessageEntity actualizados conforme llegan
  /// los fragmentos de la respuesta.
  /// 
  /// Cada emisión contiene el texto acumulado hasta ese momento.
  Stream<MessageEntity> sendMessageStream(String content);

  /// Obtiene el historial de mensajes (si aplica).
  Future<List<MessageEntity>> getMessageHistory();

  /// Limpia el historial (si aplica).
  Future<void> clearHistory();
}