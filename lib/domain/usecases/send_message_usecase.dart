import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart'; 
import 'command_processor.dart';

class SendMessageUseCase {
  final CommandProcessor _commandProcessor;
  final ChatRepository _chatRepository; 

  SendMessageUseCase({
    required CommandProcessor commandProcessor,
    required ChatRepository chatRepository, 
  })  : _commandProcessor = commandProcessor,
        _chatRepository = chatRepository;

  Future<MessageEntity> execute(String userMessage) async {
    // 1. Delegar al procesador para ver si es un comando
    final commandResult = await _commandProcessor.processMessage(userMessage);

    if (commandResult.isCommand) {
      String responseContent;

      if (commandResult.error != null) {
        // Mensaje de error formateado (ej: "❌ Error en /traducir: Falta texto")
        responseContent = '⚠️ ${commandResult.error}';
      } else if (commandResult.processedMessage != null) {
        // Respuesta exitosa de la IA
        responseContent = commandResult.processedMessage!;
      } else {
        responseContent = '⚠️ Comando ejecutado sin respuesta.';
      }
      
      // Retornamos mensaje del BOT inmediatamente
      return MessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: responseContent,
        type: MessageTypeEntity.bot,
        timestamp: DateTime.now(),
      );

    } else {
      // 2. Si no es comando, flujo normal de chat (historial + contexto)
      return _chatRepository.sendMessage(userMessage);
    }
  }
}