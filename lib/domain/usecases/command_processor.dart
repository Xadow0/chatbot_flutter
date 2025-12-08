import 'package:flutter/foundation.dart';
import '../../domain/entities/command_entity.dart';
import '../../domain/repositories/command_repository.dart';
import '../../core/utils/language_detector.dart';

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
/// Resultado del procesamiento de un comando para streaming
class CommandStreamResult {
  final bool isCommand;
  final CommandEntity? command;
  final Stream<String>? responseStream;
  final String? error;

  CommandStreamResult({
    required this.isCommand,
    this.command,
    this.responseStream,
    this.error,
  });

  factory CommandStreamResult.notCommand() {
    return CommandStreamResult(isCommand: false);
  }

  factory CommandStreamResult.success(CommandEntity command, Stream<String> stream) {
    return CommandStreamResult(
      isCommand: true,
      command: command,
      responseStream: stream,
    );
  }

  factory CommandStreamResult.error(CommandEntity? command, String error) {
    return CommandStreamResult(
      isCommand: true,
      command: command,
      error: error,
    );
  }
}

abstract class AIServiceBase {
  Future<String> generateContent(String prompt);
  Future<String> generateContentWithoutHistory(String prompt);
  Stream<String> generateContentStream(String prompt);
  Stream<String> generateContentStreamWithoutHistory(String prompt);
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
      final commands = await _commandRepository.getAllCommands();
      commands.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
      
      final matchingCommand = commands.firstWhere(
        (cmd) => normalizedMessage.toLowerCase().startsWith(cmd.trigger.toLowerCase()),
        orElse: () => throw Exception('No match'),
      );

      debugPrint('   ✅ Comando detectado: ${matchingCommand.trigger} (${matchingCommand.title})');

      switch (matchingCommand.systemType) {
        case SystemCommandType.none:
          return await _processUserCommand(matchingCommand, message);
        
        case SystemCommandType.traducir:
          return await _processTraducir(matchingCommand, message);

        case SystemCommandType.evaluarPrompt:
        case SystemCommandType.resumir:
        case SystemCommandType.codigo:
        case SystemCommandType.corregir:
        case SystemCommandType.explicar:
        case SystemCommandType.comparar:
          return await _processStandardSystemCommand(matchingCommand, message);
      }

    } catch (e) {
      if (e.toString().contains('No match')) {
         debugPrint('   ℹ️ No es un comando registrado.');
         return CommandResult.notCommand();
      }
      debugPrint('   ❌ Error recuperando comandos: $e');
      return CommandResult.notCommand();
    }
  }

  /// Procesa un comando y retorna un Stream para streaming
  Future<CommandStreamResult> processMessageStream(String message) async {
    final normalizedMessage = message.trim();
    if (!normalizedMessage.startsWith('/')) {
      return CommandStreamResult.notCommand();
    }

    debugPrint('🌊 [CommandProcessor] Analizando comando para streaming: $normalizedMessage');

    try {
      final commands = await _commandRepository.getAllCommands();
      commands.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
      
      final matchingCommand = commands.firstWhere(
        (cmd) => normalizedMessage.toLowerCase().startsWith(cmd.trigger.toLowerCase()),
        orElse: () => throw Exception('No match'),
      );

      debugPrint('   ✅ Comando detectado: ${matchingCommand.trigger} (${matchingCommand.title})');

      switch (matchingCommand.systemType) {
        case SystemCommandType.none:
          return _processUserCommandStream(matchingCommand, message);
        
        case SystemCommandType.traducir:
          return _processTraducirStream(matchingCommand, message);

        case SystemCommandType.evaluarPrompt:
        case SystemCommandType.resumir:
        case SystemCommandType.codigo:
        case SystemCommandType.corregir:
        case SystemCommandType.explicar:
        case SystemCommandType.comparar:
          return _processStandardSystemCommandStream(matchingCommand, message);
      }

    } catch (e) {
      if (e.toString().contains('No match')) {
        debugPrint('   ℹ️ No es un comando registrado.');
        return CommandStreamResult.notCommand();
      }
      debugPrint('   ❌ Error recuperando comandos: $e');
      return CommandStreamResult.notCommand();
    }
  }

  CommandStreamResult _processUserCommandStream(CommandEntity command, String message) {
    final content = _extractContentAfterCommand(message, command.trigger);
    
    String finalPrompt;
    if (command.promptTemplate.contains('{{content}}')) {
      finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);
    } else {
      finalPrompt = '${command.promptTemplate}\n\n$content';
    }

    debugPrint('   🌊 Enviando Prompt Usuario a IA (streaming)...');
    final stream = _aiService.generateContentStreamWithoutHistory(finalPrompt);
    return CommandStreamResult.success(command, stream);
  }

  CommandStreamResult _processStandardSystemCommandStream(CommandEntity command, String message) {
    final content = _extractContentAfterCommand(message, command.trigger);
    
    if (content.isEmpty) {
      return CommandStreamResult.error(command, 'Por favor, añade el contenido después del comando.');
    }

    final finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);

    debugPrint('   🌊 Enviando Prompt Sistema (${command.title}) a IA (streaming)...');
    final stream = _aiService.generateContentStreamWithoutHistory(finalPrompt);
    return CommandStreamResult.success(command, stream);
  }

  CommandStreamResult _processTraducirStream(CommandEntity command, String message) {
    final contentRaw = _extractContentAfterCommand(message, command.trigger);
    
    if (contentRaw.isEmpty) {
      return CommandStreamResult.error(command, 'Uso: ${command.trigger} [idioma opcional] [texto]');
    }

    final detection = LanguageDetector.detectLanguage(
      contentRaw,
      defaultLanguage: 'inglés',
    );

    final targetLanguage = detection.languageName;
    final textToTranslate = detection.remainingText;

    if (textToTranslate.isEmpty) {
      return CommandStreamResult.error(command, 'Falta el texto a traducir.');
    }

    final finalPrompt = command.promptTemplate
        .replaceAll('{{targetLanguage}}', targetLanguage)
        .replaceAll('{{content}}', textToTranslate);

    debugPrint('   🌊 Traduciendo a: $targetLanguage (streaming)');
    final stream = _aiService.generateContentStreamWithoutHistory(finalPrompt);
    return CommandStreamResult.success(command, stream);
  }

  Future<CommandResult> _processUserCommand(CommandEntity command, String message) async {
    try {
      final content = _extractContentAfterCommand(message, command.trigger);
      
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

  Future<CommandResult> _processStandardSystemCommand(CommandEntity command, String message) async {
    try {
      final content = _extractContentAfterCommand(message, command.trigger);
      
      if (content.isEmpty) {
        return CommandResult.error(command, 'Por favor, añade el contenido después del comando.');
      }

      final finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);

      debugPrint('   🤖 Enviando Prompt Sistema (${command.title}) a IA...');
      final response = await _aiService.generateContentWithoutHistory(finalPrompt);
      return CommandResult.success(command, response);
    } catch (e) {
      return CommandResult.error(command, 'Error: $e');
    }
  }

  Future<CommandResult> _processTraducir(CommandEntity command, String message) async {
    try {
      final contentRaw = _extractContentAfterCommand(message, command.trigger);
      
      if (contentRaw.isEmpty) {
        return CommandResult.error(command, 'Uso: ${command.trigger} [idioma opcional] [texto]');
      }

      final detection = LanguageDetector.detectLanguage(
        contentRaw,
        defaultLanguage: 'inglés',
      );

      final targetLanguage = detection.languageName;
      final textToTranslate = detection.remainingText;

      if (textToTranslate.isEmpty) {
        return CommandResult.error(command, 'Falta el texto a traducir.');
      }

      final finalPrompt = command.promptTemplate
          .replaceAll('{{targetLanguage}}', targetLanguage)
          .replaceAll('{{content}}', textToTranslate);

      debugPrint('   🌐 Traduciendo a: $targetLanguage (detectado: ${detection.wasDetected})');
      final response = await _aiService.generateContentWithoutHistory(finalPrompt);
      return CommandResult.success(command, response);

    } catch (e) {
      return CommandResult.error(command, 'Error de traducción: $e');
    }
  }

  String _extractContentAfterCommand(String message, String trigger) {
    final msgLower = message.toLowerCase();
    final trigLower = trigger.toLowerCase();
    
    final index = msgLower.indexOf(trigLower);
    if (index == -1) return message;
    
    final contentStart = index + trigger.length;
    if (contentStart >= message.length) return '';
    
    return message.substring(contentStart).trim();
  }
}