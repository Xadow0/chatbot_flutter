import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'command_processor.dart';

/// Caso de uso que decide cómo procesar un mensaje:
/// - Si contiene un comando válido, lo procesa con el CommandProcessor usando la IA seleccionada.
/// - Si NO contiene un comando, devuelve una respuesta local directa (sin usar IA).
class SendMessageUseCase {
  final CommandProcessor _commandProcessor;
  final ChatRepository _chatRepository;

  SendMessageUseCase({
    required CommandProcessor commandProcessor,
    required ChatRepository chatRepository,
  })  : _commandProcessor = commandProcessor,
        _chatRepository = chatRepository;

  /// Procesa un mensaje del usuario y devuelve un [Message] del bot.
  Future<Message> execute(String userMessage) async {
    // Primero verificamos si el mensaje es un comando
    final commandResult = await _commandProcessor.processMessage(userMessage);

    if (commandResult.isCommand) {
      if (commandResult.error != null) {
        return Message.bot('❌ ${commandResult.error}');
      } else if (commandResult.processedMessage != null) {
        return Message.bot(commandResult.processedMessage!);
      } else {
        return Message.bot('⚠️ Comando sin resultado.');
      }
    }

    // Si NO es comando, generar respuesta local
    return await _chatRepository.sendMessage(userMessage);
  }
}