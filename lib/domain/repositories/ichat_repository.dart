/// ============================================================================
/// CHAT REPOSITORY - INTERFAZ (DOMAIN LAYER)
/// ============================================================================
/// 
/// Define el contrato que la capa de datos debe implementar.
/// Solo métodos de streaming para generación de respuestas.
/// 
/// UBICACIÓN: lib/domain/repositories/chat_repository.dart
/// ============================================================================
library;

import '../entities/message_entity.dart';

abstract class IChatRepository {
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