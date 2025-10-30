// lib/domain/repositories/conversation_repository.dart
import 'dart:io';
import '../entities/message_entity.dart';

/// Interfaz del repositorio para gestionar el guardado y carga de conversaciones.
abstract class ConversationRepository {
  /// Guarda una conversación completa (lista de entidades)
  Future<void> saveConversation(List<MessageEntity> messages);

  /// Lista todas las conversaciones guardadas
  Future<List<FileSystemEntity>> listConversations();

  /// Carga una conversación específica (retorna entidades)
  Future<List<MessageEntity>> loadConversation(File file);

  /// Elimina todas las conversaciones
  Future<void> deleteAllConversations();
  
  /// Elimina múltiples conversaciones
  Future<void> deleteConversations(List<File> files);
}