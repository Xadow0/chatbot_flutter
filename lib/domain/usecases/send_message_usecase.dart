import '../../data/models/message_model.dart';
import 'command_processor.dart';

/// Caso de uso que decide cómo procesar un mensaje:
/// - Si contiene un comando válido (ej: /tryprompt), lo procesa con el CommandProcessor usando la IA seleccionada.
/// - Si NO contiene un comando, devuelve un eco del mensaje (respuesta local sin usar IA).
class SendMessageUseCase {
  final CommandProcessor _commandProcessor;

  SendMessageUseCase({
    required CommandProcessor commandProcessor,
  }) : _commandProcessor = commandProcessor;

  /// Procesa un mensaje del usuario y devuelve un [Message] del bot.
  Future<Message> execute(String userMessage) async {
    // Primero verificamos si el mensaje es un comando
    final commandResult = await _commandProcessor.processMessage(userMessage);

    if (commandResult.isCommand) {
      // Si hay un error en el comando
      if (commandResult.error != null) {
        return Message.bot('❌ ${commandResult.error}');
      } 
      // Si el comando se procesó exitosamente
      else if (commandResult.processedMessage != null) {
        return Message.bot(commandResult.processedMessage!);
      } 
      // Comando sin resultado (caso inusual)
      else {
        return Message.bot('⚠️ Comando sin resultado.');
      }
    }

    // Si NO es comando, devolver eco del mensaje (respuesta local sin IA)
    return Message.bot(_generateLocalResponse(userMessage));
  }

  /// Genera una respuesta local sin usar IA
  String _generateLocalResponse(String userMessage) {
    return '''📝 **Eco del mensaje:**
"$userMessage"

💡 **Tip:** Para usar la IA, utiliza comandos como:
• `/tryprompt [tu pregunta]` - Mejora y evalúa tu prompt

🔜 Próximamente: Modo chat directo con IA''';
  }
}