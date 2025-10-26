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

/// Interfaz base que todos los servicios de IA deben implementar
/// Esto permite que CommandProcessor funcione con cualquier servicio
abstract class AIServiceBase {
  Future<String> generateContent(String prompt);
}

class CommandProcessor {
  // Ya no tiene una dependencia fija de GeminiService
  // Ahora recibe cualquier servicio que implemente AIServiceBase
  final AIServiceBase _aiService;

  CommandProcessor(this._aiService);

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

  /// Procesa el comando "/tryprompt" usando la IA seleccionada
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

      // Construir el prompt modificado
      final enhancedPrompt = _buildEnhancedPrompt(content);

  // Normalizar espacios al inicio/final antes de enviar a la IA
  final trimmedPrompt = enhancedPrompt.trim();
  // Llamar a la IA seleccionada (podría ser Gemini, OpenAI, Ollama o Local)
  final response = await _aiService.generateContent(trimmedPrompt);

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

  /// Construye el prompt mejorado para la IA
  String _buildEnhancedPrompt(String userContent) {
    return '''
      Actúa como un evaluador y mejorador de prompts para el prompt que adjunto como "Mensaje del usuario". No repitas tu función ni el mensaje del usuario, céntrate en mejorar el prompt. 
      El usuario mandará un prompt para que lo evalúes y mejores, para cada caso, debes identificar los tres pasos que cualquier prompt debería tener:
      1. Task 
      2. Context
      3. Referencias
      Si cualquiera de las tres partes es faltante o deficiente, debes indicar al usuario como mejorarlo, haciendo las preguntas generales para que el usuario las conteste en el tema en específico del que trate el prompt.
      Estos son los pasos que debes cumplir para evaluar y mejorar el prompt:

      Instrucciones
      **Identifica el objetivo principal** cuál es el objetivo que este prompt busca que tú (la IA) cumplas.
      **Tamaño y complejidad del objetivo:** ¿Es el objetivo que el prompt propone grande y complicado para la IA?  Si es así, ¿como desglosarlo en objetivos mas pequeños?
      **Estructura y expresión del prompt:** ¿Está este prompt bien estructurado y expresado para lograr su objetivo de manera efectiva?    
      **Necesidades de un prompt complejo:** Si el objetivo es grande y/o complicado, ¿incluye este prompt un contexto completo, instrucciones claras y por pasos, ejemplos relevantes y un formato de respuesta adecuado para la IA?
      **Añade una referencias adecuadas para el resultado:** ¿Que tipo de estructura quieres que tenga la respuesta (lista, tabla, párrafos)? ¿Que tono, longitud y estilo? Es necesario un ejemplo claro de respuesta?
      **Reescribe el prompt mejorado** incorporando todas las mejoras que hayas señalado. Asegúrate de que el prompt resultante sea claro y completo. Proporciona este prompt mejorado en un formato markdown. Todas las partes que deban ser reemplazadas o completadas por el usuario estaran entre corchetes [].


      Restricciones:
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