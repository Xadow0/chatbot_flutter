/// ============================================================================
/// LOCAL CHAT REPOSITORY - IMPLEMENTACIÓN (DATA LAYER)
/// ============================================================================
/// 
/// Implementación del repositorio de chat que gestiona los mensajes
/// localmente y delega la generación de respuestas a AIChatService.
/// 
/// UBICACIÓN: lib/data/repositories/chat_repository.dart
/// ============================================================================

import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../data/services/ai_chat_service.dart';
import '../models/message_model.dart';

class LocalChatRepository implements ChatRepository {
  final List<Message> _localMessages = [];
  final AIChatService _aiChatService;

  LocalChatRepository(this._aiChatService);

  // ============================================================================
  // MÉTODO TRADICIONAL (sin streaming)
  // ============================================================================

  @override
  Future<MessageEntity> sendMessage(String content) async {
    // Pequeño delay para UX (opcional)
    await Future.delayed(const Duration(milliseconds: 100));

    final botResponseContent = await _aiChatService.generateResponse(content);

    final botMessage = Message.bot(botResponseContent);
    _localMessages.add(botMessage);
    
    return botMessage.toEntity();
  }

  // ============================================================================
  // MÉTODO CON STREAMING 🚀
  // ============================================================================

  /// Envía un mensaje y recibe la respuesta con streaming
  /// 
  /// El Stream emite MessageEntity actualizados con el texto acumulado.
  /// Cada emisión representa el estado actual del mensaje (parcial o completo).
  @override
  Stream<MessageEntity> sendMessageStream(String content) async* {
    // Crear ID único para este mensaje
    final messageId = DateTime.now().millisecondsSinceEpoch.toString();
    final timestamp = DateTime.now();
    
    // Buffer para acumular la respuesta
    final buffer = StringBuffer();
    
    try {
      // Obtener el stream de la respuesta
      await for (final chunk in _aiChatService.generateResponseStream(content)) {
        buffer.write(chunk);
        
        // Emitir mensaje actualizado con cada chunk
        yield MessageEntity(
          id: messageId,
          content: buffer.toString(),
          type: MessageTypeEntity.bot,
          timestamp: timestamp,
        );
      }
      
      // Guardar mensaje completo en el historial local
      final finalMessage = Message.bot(buffer.toString());
      _localMessages.add(finalMessage);
      
    } catch (e) {
      // En caso de error, emitir mensaje de error
      yield MessageEntity(
        id: messageId,
        content: '❌ Error: ${e.toString()}',
        type: MessageTypeEntity.bot,
        timestamp: timestamp,
      );
      rethrow;
    }
  }

  // ============================================================================
  // MÉTODOS DE HISTORIAL
  // ============================================================================

  @override
  Future<List<MessageEntity>> getMessageHistory() async {
    return _localMessages.map((model) => model.toEntity()).toList();
  }

  @override
  Future<void> clearHistory() async {
    _localMessages.clear();
  }
}