import '../../domain/entities/message_entity.dart';
import 'command_processor.dart';

/// Caso de uso que decide cómo procesar un mensaje:
/// - Si contiene un comando válido (ej: /tryprompt), lo procesa con el CommandProcessor usando la IA seleccionada.
/// - Si NO contiene un comando, devuelve un eco del mensaje (respuesta local sin usar IA).
/// 
/// IMPORTANTE: Este caso de uso trabaja con ENTIDADES (domain layer),
/// no con modelos de datos.
class SendMessageUseCase {
  final CommandProcessor _commandProcessor;

  SendMessageUseCase({
    required CommandProcessor commandProcessor,
  }) : _commandProcessor = commandProcessor;

  /// Procesa un mensaje del usuario y devuelve una [MessageEntity] del bot.
  Future<MessageEntity> execute(String userMessage) async {
    // Primero verificamos si el mensaje es un comando
    final commandResult = await _commandProcessor.processMessage(userMessage);

    String responseContent;

    if (commandResult.isCommand) {
      // Si hay un error en el comando
      if (commandResult.error != null) {
        responseContent = '❌ ${commandResult.error}';
      } 
      // Si el comando se procesó exitosamente
      else if (commandResult.processedMessage != null) {
        responseContent = commandResult.processedMessage!;
      } 
      // Comando sin resultado (caso inusual)
      else {
        responseContent = '⚠️ Comando sin resultado.';
      }
    } else {
      // Si NO es comando, devolver eco del mensaje (respuesta local sin IA)
      responseContent = _generateLocalResponse(userMessage);
    }

    // Crear y retornar la entidad de mensaje del bot
    return MessageEntity(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: responseContent,
      type: MessageTypeEntity.bot,
      timestamp: DateTime.now(),
    );
  }

  /// Genera una respuesta local sin usar IA
  String _generateLocalResponse(String userMessage) {
    return '''📝 **Eco del mensaje:**
"$userMessage"

💡 **Tip:** Para usar la IA, utiliza comandos como:
• `/tryprompt [tu pregunta]` - Mejora y evalúa tu prompt

📜 Próximamente: Modo chat directo con IA''';
  }
}