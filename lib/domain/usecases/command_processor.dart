import 'package:flutter/foundation.dart';
import '../../domain/entities/command_entity.dart';
import '../../domain/repositories/command_repository.dart';
import '../../core/utils/laguande_detector.dart';

/// Resultado del procesamiento de un comando
class CommandResult {
  final bool isCommand;
  final CommandEntity? command;
  final String? processedMessage;
  final String? error;

  CommandResult({
    required this.isCommand,
    this.command,
    this.processedMessage,
    this.error,
  });

  factory CommandResult.notCommand() {
    return CommandResult(isCommand: false);
  }

  factory CommandResult.success(CommandEntity command, String message) {
    return CommandResult(
      isCommand: true,
      command: command,
      processedMessage: message,
    );
  }

  factory CommandResult.error(CommandEntity? command, String error) {
    return CommandResult(
      isCommand: true,
      command: command,
      error: error,
    );
  }
}

abstract class AIServiceBase {
  Future<String> generateContent(String prompt);
  Future<String> generateContentWithoutHistory(String prompt);
}

class CommandProcessor {
  final AIServiceBase _aiService;
  final CommandRepository _commandRepository;

  CommandProcessor(this._aiService, this._commandRepository);

  /// Detecta si el mensaje es un comando buscando en la base de datos/repositorio
  Future<CommandResult> processMessage(String message) async {
    final normalizedMessage = message.trim();
    if (!normalizedMessage.startsWith('/')) {
      return CommandResult.notCommand();
    }

    debugPrint('🔍 [CommandProcessor] Analizando mensaje: $normalizedMessage');

    try {
      // 1. Obtener todos los comandos disponibles (Sistema + Usuario)
      final commands = await _commandRepository.getAllCommands();
      
      // 2. Buscar coincidencia con el trigger
      // Ordenamos por longitud desc (para que /traduciringles no coincida con /traducir por error si existieran ambos)
      commands.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
      
      final matchingCommand = commands.firstWhere(
        (cmd) => normalizedMessage.toLowerCase().startsWith(cmd.trigger.toLowerCase()),
        orElse: () => throw Exception('No match'), // Usamos try/catch para el flujo
      );

      debugPrint('   ✅ Comando detectado: ${matchingCommand.trigger} (${matchingCommand.title})');

      // 3. Enrutar según el tipo de sistema
      switch (matchingCommand.systemType) {
        case SystemCommandType.none:
          return await _processUserCommand(matchingCommand, message);
        
        case SystemCommandType.traducir:
          return await _processTraducir(matchingCommand, message);

        // Los siguientes comparten lógica simple (Template + Contenido),
        // pero mantenemos el switch por si quieres añadir lógica específica a futuro.
        case SystemCommandType.evaluarPrompt:
        case SystemCommandType.resumir:
        case SystemCommandType.codigo:
        case SystemCommandType.corregir:
        case SystemCommandType.explicar:
        case SystemCommandType.comparar:
          return await _processStandardSystemCommand(matchingCommand, message);
      }

    } catch (e) {
      // Si no se encontró comando o hubo error en repositorio
      if (e.toString().contains('No match')) {
         debugPrint('   ℹ️ No es un comando registrado.');
         return CommandResult.notCommand();
      }
      debugPrint('   ❌ Error recuperando comandos: $e');
      return CommandResult.notCommand();
    }
  }

  /// Procesa comandos personalizados del usuario (Simples)
  /// Concatena el Prompt del usuario + el Input actual
  Future<CommandResult> _processUserCommand(CommandEntity command, String message) async {
    try {
      final content = _extractContentAfterCommand(message, command.trigger);
      
      // Si el usuario definió un placeholder {{content}}, lo usamos. Si no, concatenamos.
      String finalPrompt;
      if (command.promptTemplate.contains('{{content}}')) {
        finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);
      } else {
        finalPrompt = '${command.promptTemplate}\n\n$content';
      }

      debugPrint('   🤖 Enviando Prompt Usuario a IA...');
      final response = await _aiService.generateContentWithoutHistory(finalPrompt);
      return CommandResult.success(command, response);
    } catch (e) {
      return CommandResult.error(command, 'Error ejecutando comando: $e');
    }
  }

  /// Procesa comandos estándar del sistema que solo requieren inyección de contenido
  /// (Evaluar, Resumir, Código, Corregir, Explicar, Comparar)
  Future<CommandResult> _processStandardSystemCommand(CommandEntity command, String message) async {
    try {
      final content = _extractContentAfterCommand(message, command.trigger);
      
      if (content.isEmpty) {
        return CommandResult.error(command, 'Por favor, añade el contenido después del comando.');
      }

      // Inyectamos el contenido en el template que viene del Modelo/Firebase
      final finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);

      debugPrint('   🤖 Enviando Prompt Sistema (${command.title}) a IA...');
      final response = await _aiService.generateContentWithoutHistory(finalPrompt);
      return CommandResult.success(command, response);
    } catch (e) {
      return CommandResult.error(command, 'Error: $e');
    }
  }

  /// Lógica avanzada específica para TRADUCIR
  /// 
  /// Detecta el idioma objetivo al inicio del contenido usando [LanguageDetector]
  /// y traduce el texto restante a ese idioma
  Future<CommandResult> _processTraducir(CommandEntity command, String message) async {
    try {
      final contentRaw = _extractContentAfterCommand(message, command.trigger);
      
      if (contentRaw.isEmpty) {
        return CommandResult.error(command, 'Uso: ${command.trigger} [idioma opcional] [texto]');
      }

      // Usar el detector de idiomas para extraer el idioma objetivo
      final detection = LanguageDetector.detectLanguage(
        contentRaw,
        defaultLanguage: 'inglés',
      );

      final targetLanguage = detection.languageName;
      final textToTranslate = detection.remainingText;

      if (textToTranslate.isEmpty) {
        return CommandResult.error(command, 'Falta el texto a traducir.');
      }

      // Construir el prompt final con el idioma detectado
      final finalPrompt = command.promptTemplate
          .replaceAll('{{targetLanguage}}', targetLanguage)
          .replaceAll('{{content}}', textToTranslate);

      debugPrint('   🌍 Traduciendo a: $targetLanguage (detectado: ${detection.wasDetected})');
      final response = await _aiService.generateContentWithoutHistory(finalPrompt);
      return CommandResult.success(command, response);

    } catch (e) {
      return CommandResult.error(command, 'Error de traducción: $e');
    }
  }

  /// Extrae el contenido después del comando (trigger)
  /// 
  /// Maneja correctamente mayúsculas/minúsculas y espacios
  String _extractContentAfterCommand(String message, String trigger) {
    // Aseguramos case-insensitive matching para el trigger
    final msgLower = message.toLowerCase();
    final trigLower = trigger.toLowerCase();
    
    final index = msgLower.indexOf(trigLower);
    if (index == -1) return message; // Fallback raro
    
    final contentStart = index + trigger.length;
    if (contentStart >= message.length) return '';
    
    return message.substring(contentStart).trim();
  }
}