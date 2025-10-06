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

    // Detectar comando "probar prompt"
    if (normalizedMessage.startsWith('probar prompt')) {
      return await _processProbarPrompt(message);
    }

    // No es un comando
    return CommandResult.notCommand();
  }

  /// Procesa el comando "probar prompt"
  Future<CommandResult> _processProbarPrompt(String message) async {
    try {
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, 'probar prompt');
      
      if (content.isEmpty) {
        return CommandResult.error(
          CommandType.probarPrompt,
          'Por favor, escribe algo después de "probar prompt".\nEjemplo: probar prompt ¿Qué es Flutter?',
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
Haz de un entrenador de prompts. Identifica en el siguiente mensaje del usuario, cual es el objetivo que quiere cumplir. Una vez tengas claro el
objetivo, indícaselo al inicio de la respuesta. 
Luego, analiza el resto del prompt y evalúa su eficiencia en una valoración del 1 al 100, donde el 1 es muy deficiente y 100 es perfecto. Para esta
valoración se deberá tener en cuenta cuanto de grande y complicado es el objetivo a cumplir, y como de bien estructurado y expresado esta el prompt para lograr ese objetivo.
Cuanto más complicado y grande sea el objetivo, será más necesario: un contexto completo, instrucciones claras y por pasos, ejemplos, y un formato de respuesta adecuado.

Señala los posibles errores o carencias del prompt, y explica como mejorarlo.

Finalmente, reescribe el prompt mejorado, teniendo en cuenta las mejoras que has señalado. Asegúrate de que el prompt mejorado es claro, completo y específico.

Mensaje del usuario:
$userContent

Tu respuesta:
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