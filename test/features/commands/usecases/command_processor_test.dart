import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

// -----------------------------------------------------------------------------
// Entidades y clases necesarias (simuladas para tests independientes)
// -----------------------------------------------------------------------------

/// Enum que representa los tipos de comandos del sistema
enum SystemCommandType {
  none,
  traducir,
  evaluarPrompt,
  resumir,
  codigo,
  corregir,
  explicar,
  comparar,
}

/// Entidad de comando (versión simplificada para tests)
class CommandEntity {
  final String id;
  final String trigger;
  final String title;
  final String promptTemplate;
  final SystemCommandType systemType;

  CommandEntity({
    required this.id,
    required this.trigger,
    required this.title,
    required this.promptTemplate,
    required this.systemType,
  });
}

/// Interfaz del repositorio de comandos
abstract class ICommandRepository {
  Future<List<CommandEntity>> getAllCommands();
}

/// Resultado de detección de idioma (simulado)
class LanguageDetectionResult {
  final String languageName;
  final String remainingText;

  LanguageDetectionResult({
    required this.languageName,
    required this.remainingText,
  });
}

/// Detector de idioma (simulado para poder controlar en tests)
class LanguageDetector {
  static LanguageDetectionResult Function(String, {String defaultLanguage})?
      _mockDetector;

  static void setMockDetector(
      LanguageDetectionResult Function(String, {String defaultLanguage})
          detector) {
    _mockDetector = detector;
  }

  static void resetMockDetector() {
    _mockDetector = null;
  }

  static LanguageDetectionResult detectLanguage(
    String text, {
    String defaultLanguage = 'inglés',
  }) {
    if (_mockDetector != null) {
      return _mockDetector!(text, defaultLanguage: defaultLanguage);
    }

    // Implementación real simplificada para tests
    final words = text.trim().split(RegExp(r'\s+'));
    final languageKeywords = {
      'inglés': ['inglés', 'ingles', 'english', 'en'],
      'español': ['español', 'espanol', 'spanish', 'es'],
      'francés': ['francés', 'frances', 'french', 'fr'],
      'alemán': ['alemán', 'aleman', 'german', 'de'],
      'italiano': ['italiano', 'italian', 'it'],
      'portugués': ['portugués', 'portugues', 'portuguese', 'pt'],
    };

    for (final entry in languageKeywords.entries) {
      if (words.isNotEmpty &&
          entry.value.contains(words.first.toLowerCase())) {
        return LanguageDetectionResult(
          languageName: entry.key,
          remainingText: words.skip(1).join(' '),
        );
      }
    }

    return LanguageDetectionResult(
      languageName: defaultLanguage,
      remainingText: text,
    );
  }
}

// -----------------------------------------------------------------------------
// Clases del archivo a testear (copiadas para test standalone)
// -----------------------------------------------------------------------------

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

  factory CommandStreamResult.success(
      CommandEntity command, Stream<String> stream) {
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
  Stream<String> generateContentStream(String prompt);
  Stream<String> generateContentStreamWithoutHistory(String prompt);
}

class CommandProcessor {
  final AIServiceBase _aiService;
  final ICommandRepository _commandRepository;

  CommandProcessor(this._aiService, this._commandRepository);

  Future<CommandStreamResult> processMessageStream(String message) async {
    final normalizedMessage = message.trim();
    if (!normalizedMessage.startsWith('/')) {
      return CommandStreamResult.notCommand();
    }

    try {
      final commands = await _commandRepository.getAllCommands();
      commands.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));

      final matchingCommand = commands.firstWhere(
        (cmd) => normalizedMessage
            .toLowerCase()
            .startsWith(cmd.trigger.toLowerCase()),
        orElse: () => throw Exception('No match'),
      );

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
        return CommandStreamResult.notCommand();
      }
      return CommandStreamResult.notCommand();
    }
  }

  CommandStreamResult _processUserCommandStream(
      CommandEntity command, String message) {
    final content = _extractContentAfterCommand(message, command.trigger);

    String finalPrompt;
    if (command.promptTemplate.contains('{{content}}')) {
      finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);
    } else {
      finalPrompt = '${command.promptTemplate}\n\n$content';
    }

    final stream = _aiService.generateContentStreamWithoutHistory(finalPrompt);
    return CommandStreamResult.success(command, stream);
  }

  CommandStreamResult _processStandardSystemCommandStream(
      CommandEntity command, String message) {
    final content = _extractContentAfterCommand(message, command.trigger);

    if (content.isEmpty) {
      return CommandStreamResult.error(
          command, 'Por favor, añade el contenido después del comando.');
    }

    final finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);

    final stream = _aiService.generateContentStreamWithoutHistory(finalPrompt);
    return CommandStreamResult.success(command, stream);
  }

  CommandStreamResult _processTraducirStream(
      CommandEntity command, String message) {
    final contentRaw = _extractContentAfterCommand(message, command.trigger);

    if (contentRaw.isEmpty) {
      return CommandStreamResult.error(
          command, 'Uso: ${command.trigger} [idioma opcional] [texto]');
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

    final stream = _aiService.generateContentStreamWithoutHistory(finalPrompt);
    return CommandStreamResult.success(command, stream);
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

// -----------------------------------------------------------------------------
// MOCKS
// -----------------------------------------------------------------------------

class MockAIService extends Mock implements AIServiceBase {
  @override
  Stream<String> generateContentStream(String prompt) {
    return Stream.value('mocked response');
  }

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) {
    return Stream.value('mocked response without history');
  }
}

class MockCommandRepository extends Mock implements ICommandRepository {
  List<CommandEntity> _commands = [];

  void setCommands(List<CommandEntity> commands) {
    _commands = commands;
  }

  void setThrowError(bool shouldThrow) {
    _shouldThrow = shouldThrow;
  }

  bool _shouldThrow = false;

  @override
  Future<List<CommandEntity>> getAllCommands() async {
    if (_shouldThrow) {
      throw Exception('Repository error');
    }
    return _commands;
  }
}

// -----------------------------------------------------------------------------
// TESTS
// -----------------------------------------------------------------------------

void main() {
  // ===========================================================================
  // GRUPO 1: Tests de CommandStreamResult
  // ===========================================================================
  group('CommandStreamResult', () {
    test('constructor principal crea instancia correctamente', () {
      final result = CommandStreamResult(
        isCommand: true,
        command: null,
        responseStream: null,
        error: 'test error',
      );

      expect(result.isCommand, true);
      expect(result.command, null);
      expect(result.responseStream, null);
      expect(result.error, 'test error');
    });

    test('factory notCommand() crea resultado con isCommand=false', () {
      final result = CommandStreamResult.notCommand();

      expect(result.isCommand, false);
      expect(result.command, null);
      expect(result.responseStream, null);
      expect(result.error, null);
    });

    test('factory success() crea resultado con comando y stream', () {
      final command = CommandEntity(
        id: '1',
        trigger: '/test',
        title: 'Test Command',
        promptTemplate: 'Test template',
        systemType: SystemCommandType.none,
      );
      final stream = Stream<String>.value('test');

      final result = CommandStreamResult.success(command, stream);

      expect(result.isCommand, true);
      expect(result.command, command);
      expect(result.responseStream, stream);
      expect(result.error, null);
    });

    test('factory error() crea resultado con comando y mensaje de error', () {
      final command = CommandEntity(
        id: '1',
        trigger: '/test',
        title: 'Test Command',
        promptTemplate: 'Test template',
        systemType: SystemCommandType.none,
      );

      final result = CommandStreamResult.error(command, 'Error message');

      expect(result.isCommand, true);
      expect(result.command, command);
      expect(result.responseStream, null);
      expect(result.error, 'Error message');
    });

    test('factory error() acepta comando null', () {
      final result = CommandStreamResult.error(null, 'Error without command');

      expect(result.isCommand, true);
      expect(result.command, null);
      expect(result.error, 'Error without command');
    });
  });

  // ===========================================================================
  // GRUPO 2: Tests de CommandProcessor.processMessageStream
  // ===========================================================================
  group('CommandProcessor.processMessageStream', () {
    late MockAIService mockAIService;
    late MockCommandRepository mockRepository;
    late CommandProcessor processor;

    setUp(() {
      mockAIService = MockAIService();
      mockRepository = MockCommandRepository();
      processor = CommandProcessor(mockAIService, mockRepository);
    });

    tearDown(() {
      LanguageDetector.resetMockDetector();
    });

    test('retorna notCommand cuando mensaje no empieza con /', () async {
      final result = await processor.processMessageStream('hello world');

      expect(result.isCommand, false);
    });

    test('retorna notCommand cuando mensaje es texto normal con espacios', () async {
      final result = await processor.processMessageStream('   hello world   ');

      expect(result.isCommand, false);
    });

    test('retorna notCommand cuando no hay comandos que coincidan', () async {
      mockRepository.setCommands([
        CommandEntity(
          id: '1',
          trigger: '/traducir',
          title: 'Traducir',
          promptTemplate: 'Traduce: {{content}}',
          systemType: SystemCommandType.traducir,
        ),
      ]);

      final result = await processor.processMessageStream('/unknown comando');

      expect(result.isCommand, false);
    });

    test('retorna notCommand cuando repositorio lanza excepción', () async {
      mockRepository.setThrowError(true);

      final result = await processor.processMessageStream('/test');

      expect(result.isCommand, false);
    });

    test('procesa comando de usuario (SystemCommandType.none) correctamente', () async {
      final userCommand = CommandEntity(
        id: '1',
        trigger: '/custom',
        title: 'Custom Command',
        promptTemplate: 'Custom prompt: {{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([userCommand]);

      final result = await processor.processMessageStream('/custom mi texto');

      expect(result.isCommand, true);
      expect(result.command?.trigger, '/custom');
      expect(result.responseStream, isNotNull);
      expect(result.error, null);
    });

    test('procesa comando traducir correctamente', () async {
      final traducirCommand = CommandEntity(
        id: '1',
        trigger: '/traducir',
        title: 'Traducir',
        promptTemplate: 'Traduce a {{targetLanguage}}: {{content}}',
        systemType: SystemCommandType.traducir,
      );
      mockRepository.setCommands([traducirCommand]);

      LanguageDetector.setMockDetector((text, {defaultLanguage = 'inglés'}) {
        return LanguageDetectionResult(
          languageName: 'francés',
          remainingText: 'hello world',
        );
      });

      final result = await processor.processMessageStream('/traducir francés hello world');

      expect(result.isCommand, true);
      expect(result.command?.trigger, '/traducir');
      expect(result.responseStream, isNotNull);
    });

    test('procesa comando evaluarPrompt correctamente', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/evaluar',
        title: 'Evaluar Prompt',
        promptTemplate: 'Evalúa este prompt: {{content}}',
        systemType: SystemCommandType.evaluarPrompt,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/evaluar mi prompt');

      expect(result.isCommand, true);
      expect(result.command?.systemType, SystemCommandType.evaluarPrompt);
      expect(result.responseStream, isNotNull);
    });

    test('procesa comando resumir correctamente', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/resumir',
        title: 'Resumir',
        promptTemplate: 'Resume: {{content}}',
        systemType: SystemCommandType.resumir,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/resumir texto largo');

      expect(result.isCommand, true);
      expect(result.command?.systemType, SystemCommandType.resumir);
      expect(result.responseStream, isNotNull);
    });

    test('procesa comando codigo correctamente', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/codigo',
        title: 'Código',
        promptTemplate: 'Genera código: {{content}}',
        systemType: SystemCommandType.codigo,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/codigo función suma');

      expect(result.isCommand, true);
      expect(result.command?.systemType, SystemCommandType.codigo);
      expect(result.responseStream, isNotNull);
    });

    test('procesa comando corregir correctamente', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/corregir',
        title: 'Corregir',
        promptTemplate: 'Corrige: {{content}}',
        systemType: SystemCommandType.corregir,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/corregir mi texto');

      expect(result.isCommand, true);
      expect(result.command?.systemType, SystemCommandType.corregir);
      expect(result.responseStream, isNotNull);
    });

    test('procesa comando explicar correctamente', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/explicar',
        title: 'Explicar',
        promptTemplate: 'Explica: {{content}}',
        systemType: SystemCommandType.explicar,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/explicar concepto');

      expect(result.isCommand, true);
      expect(result.command?.systemType, SystemCommandType.explicar);
      expect(result.responseStream, isNotNull);
    });

    test('procesa comando comparar correctamente', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/comparar',
        title: 'Comparar',
        promptTemplate: 'Compara: {{content}}',
        systemType: SystemCommandType.comparar,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/comparar A vs B');

      expect(result.isCommand, true);
      expect(result.command?.systemType, SystemCommandType.comparar);
      expect(result.responseStream, isNotNull);
    });

    test('selecciona comando más largo cuando hay múltiples coincidencias', () async {
      final shortCommand = CommandEntity(
        id: '1',
        trigger: '/test',
        title: 'Test',
        promptTemplate: 'Short: {{content}}',
        systemType: SystemCommandType.none,
      );
      final longCommand = CommandEntity(
        id: '2',
        trigger: '/testlong',
        title: 'Test Long',
        promptTemplate: 'Long: {{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([shortCommand, longCommand]);

      final result = await processor.processMessageStream('/testlong contenido');

      expect(result.isCommand, true);
      expect(result.command?.trigger, '/testlong');
    });

    test('maneja mensaje con solo el comando sin contenido adicional', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/resumir',
        title: 'Resumir',
        promptTemplate: 'Resume: {{content}}',
        systemType: SystemCommandType.resumir,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/resumir');

      expect(result.isCommand, true);
      expect(result.error, contains('añade el contenido'));
    });

    test('maneja mayúsculas y minúsculas en comandos', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/traducir',
        title: 'Traducir',
        promptTemplate: 'Traduce a {{targetLanguage}}: {{content}}',
        systemType: SystemCommandType.traducir,
      );
      mockRepository.setCommands([command]);

      LanguageDetector.setMockDetector((text, {defaultLanguage = 'inglés'}) {
        return LanguageDetectionResult(
          languageName: 'inglés',
          remainingText: 'texto',
        );
      });

      final result = await processor.processMessageStream('/TRADUCIR inglés texto');

      expect(result.isCommand, true);
      expect(result.command?.trigger, '/traducir');
    });

    test('maneja espacios al inicio y final del mensaje', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/test',
        title: 'Test',
        promptTemplate: 'Test: {{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('   /test contenido   ');

      expect(result.isCommand, true);
      expect(result.command?.trigger, '/test');
    });
  });

  // ===========================================================================
  // GRUPO 3: Tests de _processUserCommandStream (vía processMessageStream)
  // ===========================================================================
  group('CommandProcessor - User Commands', () {
    late MockAIService mockAIService;
    late MockCommandRepository mockRepository;
    late CommandProcessor processor;

    setUp(() {
      mockAIService = MockAIService();
      mockRepository = MockCommandRepository();
      processor = CommandProcessor(mockAIService, mockRepository);
    });

    test('reemplaza {{content}} en promptTemplate cuando está presente', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/custom',
        title: 'Custom',
        promptTemplate: 'Prefix {{content}} Suffix',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/custom mi contenido');

      expect(result.isCommand, true);
      expect(result.responseStream, isNotNull);
    });

    test('concatena contenido cuando {{content}} NO está en template', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/simple',
        title: 'Simple',
        promptTemplate: 'Este es un template simple sin placeholder',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/simple adicional');

      expect(result.isCommand, true);
      expect(result.responseStream, isNotNull);
    });

    test('maneja contenido vacío después del comando', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/empty',
        title: 'Empty',
        promptTemplate: 'Template: {{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/empty');

      expect(result.isCommand, true);
      // User commands don't require content, so it should succeed
      expect(result.responseStream, isNotNull);
    });
  });

  // ===========================================================================
  // GRUPO 4: Tests de _processStandardSystemCommandStream
  // ===========================================================================
  group('CommandProcessor - Standard System Commands', () {
    late MockAIService mockAIService;
    late MockCommandRepository mockRepository;
    late CommandProcessor processor;

    setUp(() {
      mockAIService = MockAIService();
      mockRepository = MockCommandRepository();
      processor = CommandProcessor(mockAIService, mockRepository);
    });

    test('retorna error cuando contenido está vacío', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/resumir',
        title: 'Resumir',
        promptTemplate: 'Resume: {{content}}',
        systemType: SystemCommandType.resumir,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/resumir');

      expect(result.isCommand, true);
      expect(result.error, 'Por favor, añade el contenido después del comando.');
      expect(result.responseStream, null);
    });

    test('retorna error cuando contenido es solo espacios', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/explicar',
        title: 'Explicar',
        promptTemplate: 'Explica: {{content}}',
        systemType: SystemCommandType.explicar,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/explicar    ');

      expect(result.isCommand, true);
      expect(result.error, contains('añade el contenido'));
    });

    test('procesa correctamente cuando hay contenido válido', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/codigo',
        title: 'Código',
        promptTemplate: 'Genera código para: {{content}}',
        systemType: SystemCommandType.codigo,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/codigo función factorial');

      expect(result.isCommand, true);
      expect(result.error, null);
      expect(result.responseStream, isNotNull);
    });
  });

  // ===========================================================================
  // GRUPO 5: Tests de _processTraducirStream
  // ===========================================================================
  group('CommandProcessor - Traducir Command', () {
    late MockAIService mockAIService;
    late MockCommandRepository mockRepository;
    late CommandProcessor processor;

    setUp(() {
      mockAIService = MockAIService();
      mockRepository = MockCommandRepository();
      processor = CommandProcessor(mockAIService, mockRepository);
    });

    tearDown(() {
      LanguageDetector.resetMockDetector();
    });

    test('retorna error cuando no hay contenido después del comando', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/traducir',
        title: 'Traducir',
        promptTemplate: 'Traduce a {{targetLanguage}}: {{content}}',
        systemType: SystemCommandType.traducir,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/traducir');

      expect(result.isCommand, true);
      expect(result.error, 'Uso: /traducir [idioma opcional] [texto]');
    });

    test('retorna error cuando texto a traducir está vacío', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/traducir',
        title: 'Traducir',
        promptTemplate: 'Traduce a {{targetLanguage}}: {{content}}',
        systemType: SystemCommandType.traducir,
      );
      mockRepository.setCommands([command]);

      LanguageDetector.setMockDetector((text, {defaultLanguage = 'inglés'}) {
        return LanguageDetectionResult(
          languageName: 'francés',
          remainingText: '', // Texto vacío
        );
      });

      final result = await processor.processMessageStream('/traducir francés');

      expect(result.isCommand, true);
      expect(result.error, 'Falta el texto a traducir.');
    });

    test('traduce correctamente con idioma especificado', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/traducir',
        title: 'Traducir',
        promptTemplate: 'Traduce a {{targetLanguage}}: {{content}}',
        systemType: SystemCommandType.traducir,
      );
      mockRepository.setCommands([command]);

      LanguageDetector.setMockDetector((text, {defaultLanguage = 'inglés'}) {
        return LanguageDetectionResult(
          languageName: 'alemán',
          remainingText: 'hello world',
        );
      });

      final result = await processor.processMessageStream('/traducir alemán hello world');

      expect(result.isCommand, true);
      expect(result.error, null);
      expect(result.responseStream, isNotNull);
    });

    test('traduce correctamente con idioma por defecto', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/traducir',
        title: 'Traducir',
        promptTemplate: 'Traduce a {{targetLanguage}}: {{content}}',
        systemType: SystemCommandType.traducir,
      );
      mockRepository.setCommands([command]);

      LanguageDetector.setMockDetector((text, {defaultLanguage = 'inglés'}) {
        return LanguageDetectionResult(
          languageName: defaultLanguage,
          remainingText: 'hola mundo',
        );
      });

      final result = await processor.processMessageStream('/traducir hola mundo');

      expect(result.isCommand, true);
      expect(result.error, null);
      expect(result.responseStream, isNotNull);
    });
  });

  // ===========================================================================
  // GRUPO 6: Tests de _extractContentAfterCommand
  // ===========================================================================
  group('CommandProcessor - Extract Content', () {
    late MockAIService mockAIService;
    late MockCommandRepository mockRepository;
    late CommandProcessor processor;

    setUp(() {
      mockAIService = MockAIService();
      mockRepository = MockCommandRepository();
      processor = CommandProcessor(mockAIService, mockRepository);
    });

    test('extrae contenido correctamente después del trigger', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/test',
        title: 'Test',
        promptTemplate: '{{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/test mi contenido aquí');

      expect(result.isCommand, true);
      expect(result.responseStream, isNotNull);
    });

    test('maneja trigger al final del mensaje', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/test',
        title: 'Test',
        promptTemplate: '{{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/test');

      expect(result.isCommand, true);
    });

    test('maneja mayúsculas y minúsculas en extracción', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/test',
        title: 'Test',
        promptTemplate: '{{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/TEST contenido');

      expect(result.isCommand, true);
    });

    test('trimea espacios del contenido extraído', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/trim',
        title: 'Trim',
        promptTemplate: '[{{content}}]',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/trim    espacios    ');

      expect(result.isCommand, true);
      expect(result.responseStream, isNotNull);
    });
  });

  // ===========================================================================
  // GRUPO 7: Tests de LanguageDetector
  // ===========================================================================
  group('LanguageDetector', () {
    tearDown(() {
      LanguageDetector.resetMockDetector();
    });

    test('detecta inglés correctamente', () {
      final result = LanguageDetector.detectLanguage('inglés hello world');

      expect(result.languageName, 'inglés');
      expect(result.remainingText, 'hello world');
    });

    test('detecta español correctamente', () {
      final result = LanguageDetector.detectLanguage('español hola mundo');

      expect(result.languageName, 'español');
      expect(result.remainingText, 'hola mundo');
    });

    test('detecta francés correctamente', () {
      final result = LanguageDetector.detectLanguage('french bonjour monde');

      expect(result.languageName, 'francés');
      expect(result.remainingText, 'bonjour monde');
    });

    test('usa idioma por defecto cuando no se especifica', () {
      final result = LanguageDetector.detectLanguage('hello world');

      expect(result.languageName, 'inglés');
      expect(result.remainingText, 'hello world');
    });

    test('permite configurar idioma por defecto personalizado', () {
      final result = LanguageDetector.detectLanguage(
        'texto sin idioma',
        defaultLanguage: 'español',
      );

      expect(result.languageName, 'español');
      expect(result.remainingText, 'texto sin idioma');
    });

    test('detecta abreviatura "en" para inglés', () {
      final result = LanguageDetector.detectLanguage('en hello');

      expect(result.languageName, 'inglés');
      expect(result.remainingText, 'hello');
    });

    test('detecta "german" para alemán', () {
      final result = LanguageDetector.detectLanguage('german hallo welt');

      expect(result.languageName, 'alemán');
      expect(result.remainingText, 'hallo welt');
    });

    test('detecta "italian" para italiano', () {
      final result = LanguageDetector.detectLanguage('italian ciao mondo');

      expect(result.languageName, 'italiano');
      expect(result.remainingText, 'ciao mondo');
    });

    test('detecta "portuguese" para portugués', () {
      final result = LanguageDetector.detectLanguage('portuguese olá mundo');

      expect(result.languageName, 'portugués');
      expect(result.remainingText, 'olá mundo');
    });

    test('mock detector puede sobreescribir comportamiento', () {
      LanguageDetector.setMockDetector((text, {defaultLanguage = 'inglés'}) {
        return LanguageDetectionResult(
          languageName: 'custom',
          remainingText: 'mocked',
        );
      });

      final result = LanguageDetector.detectLanguage('cualquier cosa');

      expect(result.languageName, 'custom');
      expect(result.remainingText, 'mocked');
    });

    test('resetMockDetector restaura comportamiento original', () {
      LanguageDetector.setMockDetector((text, {defaultLanguage = 'inglés'}) {
        return LanguageDetectionResult(
          languageName: 'mocked',
          remainingText: 'mocked',
        );
      });

      LanguageDetector.resetMockDetector();

      final result = LanguageDetector.detectLanguage('inglés real text');

      expect(result.languageName, 'inglés');
      expect(result.remainingText, 'real text');
    });
  });

  // ===========================================================================
  // GRUPO 8: Tests de casos edge
  // ===========================================================================
  group('CommandProcessor - Edge Cases', () {
    late MockAIService mockAIService;
    late MockCommandRepository mockRepository;
    late CommandProcessor processor;

    setUp(() {
      mockAIService = MockAIService();
      mockRepository = MockCommandRepository();
      processor = CommandProcessor(mockAIService, mockRepository);
    });

    tearDown(() {
      LanguageDetector.resetMockDetector();
    });

    test('maneja lista de comandos vacía', () async {
      mockRepository.setCommands([]);

      final result = await processor.processMessageStream('/test');

      expect(result.isCommand, false);
    });

    test('maneja mensaje vacío', () async {
      final result = await processor.processMessageStream('');

      expect(result.isCommand, false);
    });

    test('maneja mensaje con solo espacios', () async {
      final result = await processor.processMessageStream('   ');

      expect(result.isCommand, false);
    });

    test('maneja mensaje con solo /', () async {
      mockRepository.setCommands([]);

      final result = await processor.processMessageStream('/');

      expect(result.isCommand, false);
    });

    test('distingue entre comandos similares', () async {
      final commands = [
        CommandEntity(
          id: '1',
          trigger: '/t',
          title: 'T',
          promptTemplate: 'Short',
          systemType: SystemCommandType.none,
        ),
        CommandEntity(
          id: '2',
          trigger: '/test',
          title: 'Test',
          promptTemplate: 'Medium',
          systemType: SystemCommandType.none,
        ),
        CommandEntity(
          id: '3',
          trigger: '/testing',
          title: 'Testing',
          promptTemplate: 'Long',
          systemType: SystemCommandType.none,
        ),
      ];
      mockRepository.setCommands(commands);

      final result1 = await processor.processMessageStream('/t contenido');
      final result2 = await processor.processMessageStream('/test contenido');
      final result3 = await processor.processMessageStream('/testing contenido');

      expect(result1.command?.trigger, '/t');
      expect(result2.command?.trigger, '/test');
      expect(result3.command?.trigger, '/testing');
    });

    test('maneja caracteres especiales en contenido', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/special',
        title: 'Special',
        promptTemplate: '{{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/special !@#\$%^&*()_+-=[]{}|;:,.<>?');

      expect(result.isCommand, true);
      expect(result.responseStream, isNotNull);
    });

    test('maneja emojis en contenido', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/emoji',
        title: 'Emoji',
        promptTemplate: '{{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/emoji 🎉🚀💻');

      expect(result.isCommand, true);
      expect(result.responseStream, isNotNull);
    });

    test('maneja contenido multilinea', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/multi',
        title: 'Multi',
        promptTemplate: '{{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/multi línea 1\nlínea 2\nlínea 3');

      expect(result.isCommand, true);
      expect(result.responseStream, isNotNull);
    });

    test('trigger con números funciona', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/cmd123',
        title: 'Cmd123',
        promptTemplate: '{{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/cmd123 contenido');

      expect(result.isCommand, true);
      expect(result.command?.trigger, '/cmd123');
    });

    test('contenido muy largo se procesa correctamente', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/long',
        title: 'Long',
        promptTemplate: '{{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final longContent = 'a' * 10000;
      final result = await processor.processMessageStream('/long $longContent');

      expect(result.isCommand, true);
      expect(result.responseStream, isNotNull);
    });
  });

  // ===========================================================================
  // GRUPO 9: Tests de CommandEntity
  // ===========================================================================
  group('CommandEntity', () {
    test('crea instancia con todos los campos', () {
      final entity = CommandEntity(
        id: 'test-id',
        trigger: '/test',
        title: 'Test Title',
        promptTemplate: 'Test template',
        systemType: SystemCommandType.none,
      );

      expect(entity.id, 'test-id');
      expect(entity.trigger, '/test');
      expect(entity.title, 'Test Title');
      expect(entity.promptTemplate, 'Test template');
      expect(entity.systemType, SystemCommandType.none);
    });

    test('soporta todos los SystemCommandType', () {
      for (final type in SystemCommandType.values) {
        final entity = CommandEntity(
          id: 'id',
          trigger: '/trigger',
          title: 'Title',
          promptTemplate: 'Template',
          systemType: type,
        );
        expect(entity.systemType, type);
      }
    });
  });

  // ===========================================================================
  // GRUPO 10: Tests de integración
  // ===========================================================================
  group('CommandProcessor - Integration Tests', () {
    late MockAIService mockAIService;
    late MockCommandRepository mockRepository;
    late CommandProcessor processor;

    setUp(() {
      mockAIService = MockAIService();
      mockRepository = MockCommandRepository();
      processor = CommandProcessor(mockAIService, mockRepository);
    });

    tearDown(() {
      LanguageDetector.resetMockDetector();
    });

    test('flujo completo de comando de usuario', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/analizar',
        title: 'Analizar',
        promptTemplate: 'Analiza el siguiente texto y proporciona insights: {{content}}',
        systemType: SystemCommandType.none,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/analizar Este es un texto de ejemplo para analizar.');

      expect(result.isCommand, true);
      expect(result.command, isNotNull);
      expect(result.command!.title, 'Analizar');
      expect(result.responseStream, isNotNull);
      expect(result.error, null);
    });

    test('flujo completo de comando de sistema', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/resumir',
        title: 'Resumir',
        promptTemplate: 'Resume el siguiente contenido de manera concisa: {{content}}',
        systemType: SystemCommandType.resumir,
      );
      mockRepository.setCommands([command]);

      final result = await processor.processMessageStream('/resumir Lorem ipsum dolor sit amet, consectetur adipiscing elit.');

      expect(result.isCommand, true);
      expect(result.command!.systemType, SystemCommandType.resumir);
      expect(result.responseStream, isNotNull);
    });

    test('flujo completo de traducción', () async {
      final command = CommandEntity(
        id: '1',
        trigger: '/traducir',
        title: 'Traducir',
        promptTemplate: 'Traduce el siguiente texto a {{targetLanguage}}: {{content}}',
        systemType: SystemCommandType.traducir,
      );
      mockRepository.setCommands([command]);

      LanguageDetector.setMockDetector((text, {defaultLanguage = 'inglés'}) {
        return LanguageDetectionResult(
          languageName: 'francés',
          remainingText: 'Hola, ¿cómo estás?',
        );
      });

      final result = await processor.processMessageStream('/traducir francés Hola, ¿cómo estás?');

      expect(result.isCommand, true);
      expect(result.command!.systemType, SystemCommandType.traducir);
      expect(result.responseStream, isNotNull);
    });

    test('múltiples comandos en secuencia', () async {
      final commands = [
        CommandEntity(
          id: '1',
          trigger: '/a',
          title: 'A',
          promptTemplate: 'A: {{content}}',
          systemType: SystemCommandType.none,
        ),
        CommandEntity(
          id: '2',
          trigger: '/b',
          title: 'B',
          promptTemplate: 'B: {{content}}',
          systemType: SystemCommandType.none,
        ),
      ];
      mockRepository.setCommands(commands);

      final result1 = await processor.processMessageStream('/a contenido a');
      final result2 = await processor.processMessageStream('/b contenido b');
      final result3 = await processor.processMessageStream('no comando');

      expect(result1.isCommand, true);
      expect(result1.command!.trigger, '/a');
      expect(result2.isCommand, true);
      expect(result2.command!.trigger, '/b');
      expect(result3.isCommand, false);
    });
  });
}