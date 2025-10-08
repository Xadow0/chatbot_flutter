import '../../data/services/gemini_service.dart';

enum CommandType {
  probarPrompt,
  none,
}

class CommandResult {
  final bool isCommand;
  final CommandType type;
  final String? processedMessage;
  final String? error;

  CommandResult({
    required this.isCommand,
    required this.type,
    this.processedMessage,
    this.error,
  });

  factory CommandResult.notCommand() {
    return CommandResult(
      isCommand: false,
      type: CommandType.none,
    );
  }

  factory CommandResult.success(CommandType type, String message) {
    return CommandResult(
      isCommand: true,
      type: type,
      processedMessage: message,
    );
  }

  factory CommandResult.error(CommandType type, String error) {
    return CommandResult(
      isCommand: true,
      type: type,
      error: error,
    );
  }
}

class CommandProcessor {
  final GeminiService _geminiService;

  CommandProcessor(this._geminiService);

  /// Detecta si el mensaje es un comando y lo procesa
  Future<CommandResult> processMessage(String message) async {
    final normalizedMessage = message.trim().toLowerCase();

    // Detectar comando "/tryprompt"
    if (normalizedMessage.startsWith('/tryprompt')) {
      return await _processProbarPrompt(message);
    }

    // No es un comando
    return CommandResult.notCommand();
  }

  /// Procesa el comando "/tryprompt"
  Future<CommandResult> _processProbarPrompt(String message) async {
    try {
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/tryprompt');
      
      if (content.isEmpty) {
        return CommandResult.error(
          CommandType.probarPrompt,
          'Por favor, escribe algo después de "/tryprompt".\nEjemplo: /tryprompt ¿Qué es Flutter?',
        );
      }

      // Construir el prompt modificado para Gemini
      final enhancedPrompt = _buildEnhancedPrompt(content);

      // Llamar a la API de Gemini
      final response = await _geminiService.generateContent(enhancedPrompt);

      return CommandResult.success(CommandType.probarPrompt, response);
    } catch (e) {
      return CommandResult.error(
        CommandType.probarPrompt,
        'Error al procesar el comando: ${e.toString()}',
      );
    }
  }

  /// Extrae el contenido después del comando
  String _extractContentAfterCommand(String message, String command) {
    final startIndex = message.toLowerCase().indexOf(command.toLowerCase());
    if (startIndex == -1) return '';
    
    final contentStart = startIndex + command.length;
    return message.substring(contentStart).trim();
  }

  /// Construye el prompt mejorado para Gemini
  String _buildEnhancedPrompt(String userContent) {
    return '''
      Actúa como un evaluador y mejorador de prompts sobre el prompt que adjunto como "Mensaje del usuario".

      Instrucciones
      1.  **Identifica el objetivo principal** que este prompt busca que tú (la IA) cumplas. Indícalo claramente al inicio de tu respuesta.
      2.  **Evalúa la eficiencia de este prompt** con una valoración del 1 al 100 (donde 1 es muy deficiente y 100 es perfecto). Para esta valoración, considera los siguientes aspectos:   
      2.1.   **Tamaño y complejidad del objetivo:** ¿Es el objetivo que el prompt propone grande y complicado para la IA?   
      2.2.   **Estructura y expresión del prompt:** ¿Está este prompt bien estructurado y expresado para lograr su objetivo de manera efectiva?    
      2.3.   **Necesidades de un prompt complejo:** Si el objetivo es grande y/o complicado, ¿incluye este prompt un contexto completo, instrucciones claras y por pasos, ejemplos relevantes y un formato de respuesta adecuado para la IA?
      3.  **Señala los posibles errores o carencias** de este prompt y explica detalladamente cómo cada uno podría mejorarse.
      4.  **Reescribe el prompt mejorado**, incorporando todas las mejoras que hayas señalado. Asegúrate de que el prompt resultante sea claro, completo y específico.
      Señala los posibles errores o carencias del prompt, y explica como mejorarlo.

      Reestricciones:
      *   Tu respuesta no debe superar los 4000 tokens.
      *   Céntrate en la explicación de las mejoras y en la generación del prompt mejorado, sin dar rodeos o información superflua en el formato de la explicación.

      Mensaje del usuario:
      $userContent


      Fin del mensaje del usuario.
      ''';
    }
}

// Comandos adicionales que puedes implementar en el futuro:
class FutureCommands {
  // Ejemplo: /traductor [idioma] [texto]
  // Ejemplo: /resumen [texto largo]
  // Ejemplo: /codigo [descripción]
  // Ejemplo: /corregir [texto]
}