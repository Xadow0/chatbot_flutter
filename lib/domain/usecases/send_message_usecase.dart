import '../../domain/entities/message_entity.dart';
import '../../domain/repositories/chat_repository.dart'; 
import 'command_processor.dart';

/// Caso de uso que decide cómo procesar un mensaje:
/// - Si contiene un comando válido (ej: /tryprompt), lo procesa con el CommandProcessor.
/// - Si NO contiene un comando, delega al ChatRepository para una respuesta (ej: eco local).
class SendMessageUseCase {
  final CommandProcessor _commandProcessor;
  final ChatRepository _chatRepository; 

  SendMessageUseCase({
    required CommandProcessor commandProcessor,
    required ChatRepository chatRepository, 
  })  : _commandProcessor = commandProcessor,
        _chatRepository = chatRepository;

  /// Procesa un mensaje del usuario y devuelve una [MessageEntity] del bot.
  Future<MessageEntity> execute(String userMessage) async {
    // Primero verificamos si el mensaje es un comando
    final commandResult = await _commandProcessor.processMessage(userMessage);

    if (commandResult.isCommand) {
      // Si es un comando, procesar como antes
      String responseContent;

      if (commandResult.error != null) {
        responseContent = '❌ ${commandResult.error}';
      } else if (commandResult.processedMessage != null) {
        responseContent = commandResult.processedMessage!;
      } else {
        responseContent = '⚠️ Comando sin resultado.';
      }
      
      // Crear y retornar la entidad de mensaje del bot
      return MessageEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        content: responseContent,
        type: MessageTypeEntity.bot,
        timestamp: DateTime.now(),
      );

    } else {
      // Si NO es comando, delegar al ChatRepository
      // (que implementará la lógica de "eco" en LocalChatRepository)
      return _chatRepository.sendMessage(userMessage);
    }
  }

}