import 'package:flutter/foundation.dart';

/// Tipos de comandos disponibles en el sistema
enum CommandType {
  probarPrompt, // Comando /tryprompt para evaluar y mejorar prompts
  translate,    // Comando /translate para traducir texto al inglés
  none,        // No es un comando
}

/// Resultado del procesamiento de un comando
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

  /// Constructor para cuando el mensaje NO es un comando
  factory CommandResult.notCommand() {
    return CommandResult(
      isCommand: false,
      type: CommandType.none,
    );
  }

  /// Constructor para cuando el comando se procesó exitosamente
  factory CommandResult.success(CommandType type, String message) {
    return CommandResult(
      isCommand: true,
      type: type,
      processedMessage: message,
    );
  }

  /// Constructor para cuando hubo un error al procesar el comando
  factory CommandResult.error(CommandType type, String error) {
    return CommandResult(
      isCommand: true,
      type: type,
      error: error,
    );
  }
}

/// Interfaz base que todos los servicios de IA deben implementar
/// Esto permite que CommandProcessor funcione con cualquier servicio:
/// - GeminiService (a través de GeminiServiceAdapter)
/// - OpenAIService (a través de OpenAIServiceAdapter)
/// - OllamaService (a través de OllamaServiceAdapter)
/// - LocalOllamaService (a través de LocalOllamaServiceAdapter)
abstract class AIServiceBase {
  /// Genera contenido CON historial de conversación (usado para chat normal)
  Future<String> generateContent(String prompt);
  
  /// Genera contenido SIN historial (usado para comandos como /tryprompt y /translate)
  /// Este método debe enviar SOLO el prompt sin contexto adicional
  Future<String> generateContentWithoutHistory(String prompt);
}

/// Procesador de comandos que utiliza el servicio de IA actualmente seleccionado
/// 
/// Este procesador detecta y ejecuta comandos especiales que comienzan con '/'.
/// Cada comando utiliza la IA seleccionada por el usuario (Gemini, OpenAI, Ollama, etc.)
/// para generar respuestas especializadas.
/// 
/// **Flujo de trabajo:**
/// 1. El usuario escribe un mensaje
/// 2. ChatProvider -> SendMessageUseCase -> CommandProcessor
/// 3. Si es un comando, se procesa con la IA activa SIN HISTORIAL
/// 4. Si NO es un comando, se devuelve un eco local (sin IA)
/// 
/// **IMPORTANTE:** Los comandos como /tryprompt y /translate usan `generateContentWithoutHistory`
/// para evitar que el historial de la conversación interfiera con el análisis/traducción.
class CommandProcessor {
  final AIServiceBase _aiService;

  CommandProcessor(this._aiService);

  /// Detecta si el mensaje es un comando y lo procesa
  /// 
  /// Retorna:
  /// - [CommandResult.notCommand()] si no es un comando
  /// - [CommandResult.success()] si el comando se procesó correctamente
  /// 
  /// Lanza:
  /// - [Exception] si hubo un error al procesar el comando (ej. error de red)
  Future<CommandResult> processMessage(String message) async {
    final normalizedMessage = message.trim().toLowerCase();

    debugPrint('🔍 [CommandProcessor] Analizando mensaje...');
    debugPrint('   📝 Contenido: ${message.length > 50 ? "${message.substring(0, 50)}..." : message}');

    // Detectar comando "/tryprompt"
    if (normalizedMessage.startsWith('/tryprompt')) {
      debugPrint('   ✅ Comando detectado: /tryprompt');
      return await _processProbarPrompt(message);
    }

    // Detectar comando "/translate"
    if (normalizedMessage.startsWith('/translate')) {
      debugPrint('   ✅ Comando detectado: /translate');
      return await _processTranslate(message);
    }

    // TODO: Agregar más comandos aquí en el futuro
    // if (normalizedMessage.startsWith('/traducir')) { ... }
    // if (normalizedMessage.startsWith('/resumir')) { ... }

    // No es un comando
    debugPrint('   ℹ️ No es un comando, retornando como mensaje normal');
    return CommandResult.notCommand();
  }

  /// Procesa el comando "/tryprompt" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando evalúa y mejora el prompt proporcionado por el usuario,
  /// utilizando la IA actualmente seleccionada (Gemini, OpenAI, Ollama, etc.)
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con el análisis del prompt.
  Future<CommandResult> _processProbarPrompt(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /tryprompt...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/tryprompt');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.probarPrompt,
          'Por favor, escribe algo después de "/tryprompt".\nEjemplo: /tryprompt ¿Qué es Flutter?',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para evaluación
      final enhancedPrompt = _buildEnhancedPrompt(content);
      debugPrint('   🎯 Prompt especializado creado (${enhancedPrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = enhancedPrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // especializado sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Respuesta recibida de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.probarPrompt, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      
      // ===================================================================
      // ▼▼▼ MODIFICACIÓN CRÍTICA ▼▼▼
      // ===================================================================
      // En lugar de devolver un CommandResult.error, relanzamos la excepción
      // para que ChatProvider pueda capturarla y reaccionar.
      rethrow;
      // ===================================================================
    }
  }

  /// Procesa el comando "/translate" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando traduce el texto proporcionado al inglés manteniendo
  /// la intención, tono y significado original.
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con la traducción.
  Future<CommandResult> _processTranslate(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /translate...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/translate');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.translate,
          'Por favor, escribe algo después de "/translate".\nEjemplo: /translate Hola, ¿cómo estás?',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para traducción
      final translatePrompt = _buildTranslatePrompt(content);
      debugPrint('   🎯 Prompt de traducción creado (${translatePrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = translatePrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // de traducción sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Traducción recibida de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.translate, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      
      // ===================================================================
      // ▼▼▼ MODIFICACIÓN CRÍTICA ▼▼▼
      // ===================================================================
      // Relanzamos la excepción también aquí.
      rethrow;
      // ===================================================================
    }
  }

  /// Extrae el contenido después del comando
  String _extractContentAfterCommand(String message, String command) {
    final startIndex = message.toLowerCase().indexOf(command.toLowerCase());
    if (startIndex == -1) return '';
    
    final contentStart = startIndex + command.length;
    return message.substring(contentStart).trim();
  }

  /// Construye el prompt especializado para evaluación y mejora de prompts
  /// 
  /// Este prompt instruye a la IA para que analice y mejore el prompt del usuario,
  /// identificando los tres componentes clave: Task, Context y Referencias
  String _buildEnhancedPrompt(String userContent) {
    return '''
Actúa como un evaluador y mejorador de prompts para el prompt que adjunto como "Mensaje del usuario". No repitas tu función ni el mensaje del usuario, céntrate en mejorar el prompt. 
El usuario mandará un prompt para que lo evalúes y mejores, para cada caso, debes identificar los tres pasos que cualquier prompt debería tener:
1. Task 
2. Context
3. Referencias

Si cualquiera de las tres partes es faltante o deficiente, debes indicar al usuario como mejorarlo, haciendo las preguntas generales para que el usuario las conteste en el tema en específico del que trate el prompt.

Estos son los pasos que debes cumplir para evaluar y mejorar el prompt:

**Instrucciones:**
1. **Identifica el objetivo principal** cuál es el objetivo que este prompt busca que tú (la IA) cumplas.
2. **Tamaño y complejidad del objetivo:** ¿Es el objetivo que el prompt propone grande y complicado para la IA?  Si es así, ¿como desglosarlo en objetivos mas pequeños?
3. **Estructura y expresión del prompt:** ¿Está este prompt bien estructurado y expresado para lograr su objetivo de manera efectiva?    
4. **Necesidades de un prompt complejo:** Si el objetivo es grande y/o complicado, ¿incluye este prompt un contexto completo, instrucciones claras y por pasos, ejemplos relevantes y un formato de respuesta adecuado para la IA?
5. **Añade una referencias adecuadas para el resultado:** ¿Que tipo de estructura quieres que tenga la respuesta (lista, tabla, párrafos)? ¿Que tono, longitud y estilo? Es necesario un ejemplo claro de respuesta?
6. **Reescribe el prompt mejorado** incorporando todas las mejoras que hayas señalado. Asegúrate de que el prompt resultante sea claro y completo. Proporciona este prompt mejorado en un formato markdown. Todas las partes que deban ser reemplazadas o completadas por el usuario estaran entre corchetes [].

**Restricciones:**
* Tu respuesta no debe superar los 4000 tokens.
* Céntrate en la explicación de las mejoras y en la generación del prompt mejorado, sin dar rodeos o información superflua en el formato de la explicación.

**Mensaje del usuario:**
$userContent

**Fin del mensaje del usuario.**
''';
  }

  /// Construye el prompt especializado para traducción al inglés
  /// 
  /// Este prompt instruye a la IA para que traduzca manteniendo la intención,
  /// tono, registro y significado original del texto
  String _buildTranslatePrompt(String userContent) {
    return '''
Actúa como un traductor experto especializado en lenguaje natural y contexto conversacional.  
Tu tarea es traducir el texto proporcionado por el usuario al inglés, manteniendo **la intención, el tono, el registro, y el significado original**.  
Evita traducciones literales o robóticas: prioriza la **fidelidad semántica y expresiva**.  

**Instrucciones específicas:**
1. Si el texto incluye expresiones idiomáticas, regionalismos o metáforas, tradúcelas a equivalentes naturales en inglés.
2. Si hay ambigüedad, conserva el sentido más probable según el contexto.
3. Mantén el formato del texto original (listas, negritas, comillas, etc.).
4. No expliques tu traducción, simplemente ofrece la versión traducida.
5. Si el texto incluye partes que no deberían traducirse (por ejemplo, nombres propios, comandos o código), déjalos tal cual.

**Mensaje del usuario:**
$userContent

**Fin del mensaje del usuario.**
''';
  }
}

// ============================================================================
// COMANDOS FUTUROS
// ============================================================================
// Esta sección documenta comandos que se pueden implementar en el futuro

/// Comandos adicionales que se pueden implementar en el futuro
class FutureCommands {
  // /traducir [idioma] [texto]
  // Ejemplo: /traducir inglés Hola, ¿cómo estás?
  
  // /resumir [texto largo]
  // Ejemplo: /resumir [pegar artículo largo]
  
  // /codigo [descripción]
  // Ejemplo: /codigo función para ordenar lista de números
  
  // /corregir [texto]
  // Ejemplo: /corregir Este es un teksto con herrores
  
  // /explicar [concepto]
  // Ejemplo: /explicar ¿Qué es async/await?
  
  // /comparar [opción A] vs [opción B]
  // Ejemplo: /comparar Flutter vs React Native
}