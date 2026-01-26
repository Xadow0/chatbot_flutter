import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// =============================================================================
// MOCKS Y STUBS
// =============================================================================

// Enum que replica SystemCommandType del código original
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

// Entidad de comando simplificada para tests
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

// Interfaz del repositorio
abstract class ICommandRepository {
  Future<List<CommandEntity>> getAllCommands();
}

// Resultado de detección de idioma
class LanguageDetectionResult {
  final String languageName;
  final String remainingText;

  LanguageDetectionResult({
    required this.languageName,
    required this.remainingText,
  });
}

// Detector de idioma simplificado para tests
class LanguageDetector {
  static LanguageDetectionResult detectLanguage(
    String text, {
    String defaultLanguage = 'inglés',
  }) {
    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      return LanguageDetectionResult(
        languageName: defaultLanguage,
        remainingText: '',
      );
    }

    final words = trimmedText.split(RegExp(r'\s+'));
    if (words.isEmpty) {
      return LanguageDetectionResult(
        languageName: defaultLanguage,
        remainingText: '',
      );
    }

    final languageMap = {
      'español': 'español',
      'spanish': 'español',
      'inglés': 'inglés',
      'ingles': 'inglés',
      'english': 'inglés',
      'francés': 'francés',
      'frances': 'francés',
      'french': 'francés',
      'alemán': 'alemán',
      'aleman': 'alemán',
      'german': 'alemán',
      'italiano': 'italiano',
      'italian': 'italiano',
      'portugués': 'portugués',
      'portugues': 'portugués',
      'portuguese': 'portugués',
    };

    final firstWord = words.first.toLowerCase();
    if (languageMap.containsKey(firstWord)) {
      return LanguageDetectionResult(
        languageName: languageMap[firstWord]!,
        remainingText: words.skip(1).join(' '),
      );
    }

    return LanguageDetectionResult(
      languageName: defaultLanguage,
      remainingText: text,
    );
  }
}

// =============================================================================
// CÓDIGO BAJO PRUEBA (CommandStreamResult y CommandProcessor)
// =============================================================================

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

// =============================================================================
// MOCKS CON MOCKTAIL
// =============================================================================

class MockAIService extends Mock implements AIServiceBase {}

class MockCommandRepository extends Mock implements ICommandRepository {}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // CommandStreamResult Tests
  // ---------------------------------------------------------------------------
  group('CommandStreamResult', () {
    group('constructor', () {
      test('crea instancia con todos los parámetros', () {
        final command = _createCommand();
        final stream = Stream<String>.fromIterable(['test']);

        final result = CommandStreamResult(
          isCommand: true,
          command: command,
          responseStream: stream,
          error: 'test error',
        );

        expect(result.isCommand, isTrue);
        expect(result.command, equals(command));
        expect(result.responseStream, equals(stream));
        expect(result.error, equals('test error'));
      });

      test('crea instancia con parámetros mínimos', () {
        final result = CommandStreamResult(isCommand: false);

        expect(result.isCommand, isFalse);
        expect(result.command, isNull);
        expect(result.responseStream, isNull);
        expect(result.error, isNull);
      });
    });

    group('factory notCommand', () {
      test('retorna resultado con isCommand false', () {
        final result = CommandStreamResult.notCommand();

        expect(result.isCommand, isFalse);
        expect(result.command, isNull);
        expect(result.responseStream, isNull);
        expect(result.error, isNull);
      });
    });

    group('factory success', () {
      test('retorna resultado exitoso con comando y stream', () {
        final command = _createCommand();
        final stream = Stream<String>.fromIterable(['response', 'data']);

        final result = CommandStreamResult.success(command, stream);

        expect(result.isCommand, isTrue);
        expect(result.command, equals(command));
        expect(result.responseStream, equals(stream));
        expect(result.error, isNull);
      });
    });

    group('factory error', () {
      test('retorna resultado de error con comando', () {
        final command = _createCommand();

        final result = CommandStreamResult.error(command, 'Error message');

        expect(result.isCommand, isTrue);
        expect(result.command, equals(command));
        expect(result.responseStream, isNull);
        expect(result.error, equals('Error message'));
      });

      test('retorna resultado de error sin comando (null)', () {
        final result = CommandStreamResult.error(null, 'Error sin comando');

        expect(result.isCommand, isTrue);
        expect(result.command, isNull);
        expect(result.responseStream, isNull);
        expect(result.error, equals('Error sin comando'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // CommandProcessor Tests
  // ---------------------------------------------------------------------------
  group('CommandProcessor', () {
    late MockAIService mockAIService;
    late MockCommandRepository mockRepository;
    late CommandProcessor processor;

    setUp(() {
      mockAIService = MockAIService();
      mockRepository = MockCommandRepository();
      processor = CommandProcessor(mockAIService, mockRepository);
    });

    // -------------------------------------------------------------------------
    // processMessageStream - Casos básicos
    // -------------------------------------------------------------------------
    group('processMessageStream - casos básicos', () {
      test('retorna notCommand cuando mensaje no empieza con /', () async {
        final result = await processor.processMessageStream('hello world');

        expect(result.isCommand, isFalse);
        verifyNever(() => mockRepository.getAllCommands());
      });

      test('retorna notCommand para mensaje vacío', () async {
        final result = await processor.processMessageStream('');

        expect(result.isCommand, isFalse);
        verifyNever(() => mockRepository.getAllCommands());
      });

      test('retorna notCommand para mensaje solo con espacios', () async {
        final result = await processor.processMessageStream('   ');

        expect(result.isCommand, isFalse);
        verifyNever(() => mockRepository.getAllCommands());
      });

      test('procesa mensaje que empieza con / después de trim', () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => []);

        final result = await processor.processMessageStream('  /test');

        // Debe intentar buscar comandos porque empieza con /
        verify(() => mockRepository.getAllCommands()).called(1);
      });

      test('retorna notCommand cuando no hay comandos registrados', () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => []);

        final result = await processor.processMessageStream('/unknown');

        expect(result.isCommand, isFalse);
      });

      test('retorna notCommand para comando no registrado', () async {
        when(() => mockRepository.getAllCommands()).thenAnswer(
          (_) async => [
            _createCommand(trigger: '/help'),
            _createCommand(trigger: '/test'),
          ],
        );

        final result = await processor.processMessageStream('/unknown');

        expect(result.isCommand, isFalse);
      });

      test('retorna notCommand cuando repository lanza excepción', () async {
        when(() => mockRepository.getAllCommands())
            .thenThrow(Exception('Database error'));

        final result = await processor.processMessageStream('/test');

        expect(result.isCommand, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // processMessageStream - Matching de comandos
    // -------------------------------------------------------------------------
    group('processMessageStream - matching de comandos', () {
      test('coincide con comando exacto (case insensitive)', () async {
        final command = _createCommand(
          trigger: '/test',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((_) => Stream.fromIterable(['ok']));

        final result = await processor.processMessageStream('/TEST content');

        expect(result.isCommand, isTrue);
        expect(result.command, equals(command));
      });

      test('prioriza comando más largo cuando hay múltiples coincidencias',
          () async {
        final shortCommand = _createCommand(
          id: '1',
          trigger: '/t',
          title: 'Short',
          systemType: SystemCommandType.none,
        );
        final longCommand = _createCommand(
          id: '2',
          trigger: '/test',
          title: 'Long',
          systemType: SystemCommandType.none,
        );

        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [shortCommand, longCommand]);
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((_) => Stream.fromIterable(['ok']));

        final result = await processor.processMessageStream('/test content');

        expect(result.command?.id, equals('2'));
        expect(result.command?.title, equals('Long'));
      });

      test('coincide con comando cuando mensaje solo tiene el trigger',
          () async {
        final command = _createCommand(
          trigger: '/help',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((_) => Stream.fromIterable(['ok']));

        final result = await processor.processMessageStream('/help');

        expect(result.isCommand, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // processMessageStream - Comandos de usuario (SystemCommandType.none)
    // -------------------------------------------------------------------------
    group('processMessageStream - comandos de usuario', () {
      test('procesa comando con plantilla que contiene {{content}}', () async {
        final command = _createCommand(
          trigger: '/custom',
          promptTemplate: 'Analiza esto: {{content}}',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['response']);
        });

        final result =
            await processor.processMessageStream('/custom mi texto');

        expect(result.isCommand, isTrue);
        expect(capturedPrompt, equals('Analiza esto: mi texto'));
      });

      test('procesa comando con plantilla sin {{content}}', () async {
        final command = _createCommand(
          trigger: '/simple',
          promptTemplate: 'Plantilla simple',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['response']);
        });

        final result =
            await processor.processMessageStream('/simple contenido extra');

        expect(capturedPrompt, equals('Plantilla simple\n\ncontenido extra'));
      });

      test('comando de usuario funciona sin contenido adicional', () async {
        final command = _createCommand(
          trigger: '/empty',
          promptTemplate: 'Solo template {{content}}',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['response']);
        });

        final result = await processor.processMessageStream('/empty');

        expect(result.isCommand, isTrue);
        expect(capturedPrompt, equals('Solo template '));
      });
    });

    // -------------------------------------------------------------------------
    // processMessageStream - Comando traducir
    // -------------------------------------------------------------------------
    group('processMessageStream - comando traducir', () {
      late CommandEntity traducirCommand;

      setUp(() {
        traducirCommand = _createCommand(
          trigger: '/traducir',
          promptTemplate:
              'Traduce al {{targetLanguage}}: {{content}}',
          systemType: SystemCommandType.traducir,
        );
      });

      test('retorna error cuando no hay contenido después del comando',
          () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [traducirCommand]);

        final result = await processor.processMessageStream('/traducir');

        expect(result.isCommand, isTrue);
        expect(result.error, contains('Uso:'));
        expect(result.error, contains('/traducir'));
      });

      test('retorna error cuando solo hay espacios después del comando',
          () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [traducirCommand]);

        final result = await processor.processMessageStream('/traducir   ');

        expect(result.isCommand, isTrue);
        expect(result.error, isNotNull);
      });

      test('traduce con idioma detectado y texto', () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [traducirCommand]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['traducción']);
        });

        final result = await processor
            .processMessageStream('/traducir español Hello world');

        expect(result.isCommand, isTrue);
        expect(result.error, isNull);
        expect(capturedPrompt, contains('español'));
        expect(capturedPrompt, contains('Hello world'));
      });

      test('usa idioma por defecto (inglés) cuando no se especifica', () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [traducirCommand]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['traducción']);
        });

        final result =
            await processor.processMessageStream('/traducir Hola mundo');

        expect(result.isCommand, isTrue);
        expect(capturedPrompt, contains('inglés'));
        expect(capturedPrompt, contains('Hola mundo'));
      });

      test('retorna error cuando solo hay idioma sin texto', () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [traducirCommand]);

        final result =
            await processor.processMessageStream('/traducir español');

        expect(result.isCommand, isTrue);
        expect(result.error, equals('Falta el texto a traducir.'));
      });

      test('detecta diferentes idiomas correctamente', () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [traducirCommand]);

        final testCases = [
          ('francés', 'francés'),
          ('french', 'francés'),
          ('alemán', 'alemán'),
          ('german', 'alemán'),
          ('italiano', 'italiano'),
          ('portugués', 'portugués'),
        ];

        for (final (input, expected) in testCases) {
          String? capturedPrompt;
          when(() => mockAIService.generateContentStreamWithoutHistory(any()))
              .thenAnswer((invocation) {
            capturedPrompt = invocation.positionalArguments[0] as String;
            return Stream.fromIterable(['ok']);
          });

          await processor.processMessageStream('/traducir $input test text');

          expect(capturedPrompt, contains(expected),
              reason: 'Fallo para idioma: $input');
        }
      });
    });

    // -------------------------------------------------------------------------
    // processMessageStream - Comandos de sistema estándar
    // -------------------------------------------------------------------------
    group('processMessageStream - comandos de sistema estándar', () {
      final systemTypes = [
        (SystemCommandType.evaluarPrompt, '/evaluar'),
        (SystemCommandType.resumir, '/resumir'),
        (SystemCommandType.codigo, '/codigo'),
        (SystemCommandType.corregir, '/corregir'),
        (SystemCommandType.explicar, '/explicar'),
        (SystemCommandType.comparar, '/comparar'),
      ];

      for (final (type, trigger) in systemTypes) {
        group('SystemCommandType.${type.name}', () {
          test('procesa correctamente con contenido', () async {
            final command = _createCommand(
              trigger: trigger,
              promptTemplate: 'Procesa: {{content}}',
              systemType: type,
            );
            when(() => mockRepository.getAllCommands())
                .thenAnswer((_) async => [command]);

            String? capturedPrompt;
            when(() => mockAIService.generateContentStreamWithoutHistory(any()))
                .thenAnswer((invocation) {
              capturedPrompt = invocation.positionalArguments[0] as String;
              return Stream.fromIterable(['response']);
            });

            final result =
                await processor.processMessageStream('$trigger mi contenido');

            expect(result.isCommand, isTrue);
            expect(result.error, isNull);
            expect(capturedPrompt, equals('Procesa: mi contenido'));
          });

          test('retorna error cuando no hay contenido', () async {
            final command = _createCommand(
              trigger: trigger,
              promptTemplate: 'Procesa: {{content}}',
              systemType: type,
            );
            when(() => mockRepository.getAllCommands())
                .thenAnswer((_) async => [command]);

            final result = await processor.processMessageStream(trigger);

            expect(result.isCommand, isTrue);
            expect(result.error,
                equals('Por favor, añade el contenido después del comando.'));
            expect(result.command, equals(command));
          });

          test('retorna error cuando solo hay espacios después del comando',
              () async {
            final command = _createCommand(
              trigger: trigger,
              promptTemplate: 'Procesa: {{content}}',
              systemType: type,
            );
            when(() => mockRepository.getAllCommands())
                .thenAnswer((_) async => [command]);

            final result =
                await processor.processMessageStream('$trigger    ');

            expect(result.isCommand, isTrue);
            expect(result.error, isNotNull);
          });
        });
      }
    });

    // -------------------------------------------------------------------------
    // processMessageStream - Extracción de contenido
    // -------------------------------------------------------------------------
    group('processMessageStream - extracción de contenido', () {
      test('extrae contenido preservando mayúsculas/minúsculas', () async {
        final command = _createCommand(
          trigger: '/test',
          promptTemplate: '{{content}}',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['ok']);
        });

        await processor.processMessageStream('/test HoLa MuNdO');

        expect(capturedPrompt, equals('HoLa MuNdO'));
      });

      test('extrae contenido con múltiples espacios', () async {
        final command = _createCommand(
          trigger: '/test',
          promptTemplate: '{{content}}',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['ok']);
        });

        await processor.processMessageStream('/test   contenido   con   espacios');

        // trim() solo elimina espacios al inicio/final del contenido extraído
        expect(capturedPrompt, equals('contenido   con   espacios'));
      });

      test('maneja trigger con mayúsculas en el mensaje', () async {
        final command = _createCommand(
          trigger: '/test',
          promptTemplate: '{{content}}',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['ok']);
        });

        await processor.processMessageStream('/TEST contenido');

        expect(capturedPrompt, equals('contenido'));
      });

      test('extrae contenido con caracteres especiales', () async {
        final command = _createCommand(
          trigger: '/test',
          promptTemplate: '{{content}}',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['ok']);
        });

        await processor.processMessageStream('/test ¡Hola! ¿Cómo estás? @#\$%');

        expect(capturedPrompt, equals('¡Hola! ¿Cómo estás? @#\$%'));
      });

      test('extrae contenido multilínea', () async {
        final command = _createCommand(
          trigger: '/test',
          promptTemplate: '{{content}}',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['ok']);
        });

        await processor.processMessageStream('/test línea 1\nlínea 2\nlínea 3');

        expect(capturedPrompt, equals('línea 1\nlínea 2\nlínea 3'));
      });
    });

    // -------------------------------------------------------------------------
    // processMessageStream - Stream de respuesta
    // -------------------------------------------------------------------------
    group('processMessageStream - stream de respuesta', () {
      test('retorna stream funcional que puede ser consumido', () async {
        final command = _createCommand(
          trigger: '/test',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((_) => Stream.fromIterable(['chunk1', 'chunk2', 'chunk3']));

        final result = await processor.processMessageStream('/test content');

        expect(result.responseStream, isNotNull);

        final chunks = await result.responseStream!.toList();
        expect(chunks, equals(['chunk1', 'chunk2', 'chunk3']));
      });

      test('verifica que se llama al servicio AI correcto', () async {
        final command = _createCommand(
          trigger: '/test',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((_) => Stream.fromIterable(['ok']));

        await processor.processMessageStream('/test content');

        verify(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .called(1);
        verifyNever(() => mockAIService.generateContentStream(any()));
      });
    });

    // -------------------------------------------------------------------------
    // processMessageStream - Casos edge
    // -------------------------------------------------------------------------
    group('processMessageStream - casos edge', () {
      test('maneja comando que es exactamente el trigger sin espacio', () async {
        final command = _createCommand(
          trigger: '/test',
          promptTemplate: 'Template: {{content}}',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);

        String? capturedPrompt;
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((invocation) {
          capturedPrompt = invocation.positionalArguments[0] as String;
          return Stream.fromIterable(['ok']);
        });

        await processor.processMessageStream('/test');

        expect(capturedPrompt, equals('Template: '));
      });

      test('maneja mensaje con solo "/" ', () async {
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [_createCommand(trigger: '/test')]);

        final result = await processor.processMessageStream('/');

        expect(result.isCommand, isFalse);
      });

      test('no confunde texto que contiene / en medio', () async {
        final result =
            await processor.processMessageStream('texto con/barra');

        expect(result.isCommand, isFalse);
        verifyNever(() => mockRepository.getAllCommands());
      });

      test('maneja múltiples comandos con triggers similares', () async {
        final commands = [
          _createCommand(id: '1', trigger: '/t', title: 'T'),
          _createCommand(id: '2', trigger: '/te', title: 'Te'),
          _createCommand(id: '3', trigger: '/tes', title: 'Tes'),
          _createCommand(id: '4', trigger: '/test', title: 'Test'),
          _createCommand(id: '5', trigger: '/testing', title: 'Testing'),
        ];

        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => commands);
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((_) => Stream.fromIterable(['ok']));

        // Debe coincidir con /testing (el más largo que coincide)
        var result = await processor.processMessageStream('/testing123');
        expect(result.command?.title, equals('Testing'));

        // Debe coincidir con /test
        result = await processor.processMessageStream('/test123');
        expect(result.command?.title, equals('Test'));

        // Debe coincidir con /t
        result = await processor.processMessageStream('/txyz');
        expect(result.command?.title, equals('T'));
      });

      test('maneja trigger con caracteres unicode', () async {
        final command = _createCommand(
          trigger: '/búsqueda',
          systemType: SystemCommandType.none,
        );
        when(() => mockRepository.getAllCommands())
            .thenAnswer((_) async => [command]);
        when(() => mockAIService.generateContentStreamWithoutHistory(any()))
            .thenAnswer((_) => Stream.fromIterable(['ok']));

        final result =
            await processor.processMessageStream('/búsqueda término');

        expect(result.isCommand, isTrue);
        expect(result.command?.trigger, equals('/búsqueda'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // LanguageDetector Tests (para completar cobertura)
  // ---------------------------------------------------------------------------
  group('LanguageDetector', () {
    test('detecta idioma español', () {
      final result = LanguageDetector.detectLanguage('español hello world');

      expect(result.languageName, equals('español'));
      expect(result.remainingText, equals('hello world'));
    });

    test('detecta idioma inglés con variantes', () {
      var result = LanguageDetector.detectLanguage('inglés hola');
      expect(result.languageName, equals('inglés'));

      result = LanguageDetector.detectLanguage('ingles hola');
      expect(result.languageName, equals('inglés'));

      result = LanguageDetector.detectLanguage('english hola');
      expect(result.languageName, equals('inglés'));
    });

    test('usa idioma por defecto cuando no detecta idioma', () {
      final result = LanguageDetector.detectLanguage('hello world');

      expect(result.languageName, equals('inglés'));
      expect(result.remainingText, equals('hello world'));
    });

    test('usa idioma por defecto personalizado', () {
      final result = LanguageDetector.detectLanguage(
        'hello world',
        defaultLanguage: 'español',
      );

      expect(result.languageName, equals('español'));
    });

    test('maneja texto vacío', () {
      final result = LanguageDetector.detectLanguage('');

      expect(result.languageName, equals('inglés'));
      expect(result.remainingText, equals(''));
    });

    test('maneja texto con solo espacios', () {
      final result = LanguageDetector.detectLanguage('   ');

      expect(result.languageName, equals('inglés'));
      expect(result.remainingText, equals(''));
    });

    test('detecta idioma case insensitive', () {
      var result = LanguageDetector.detectLanguage('ESPAÑOL hello');
      expect(result.languageName, equals('español'));

      result = LanguageDetector.detectLanguage('FrAnCéS hello');
      expect(result.languageName, equals('francés'));
    });
  });
}

// =============================================================================
// HELPERS
// =============================================================================

CommandEntity _createCommand({
  String id = 'test-id',
  String trigger = '/test',
  String title = 'Test Command',
  String promptTemplate = 'Test prompt: {{content}}',
  SystemCommandType systemType = SystemCommandType.none,
}) {
  return CommandEntity(
    id: id,
    trigger: trigger,
    title: title,
    promptTemplate: promptTemplate,
    systemType: systemType,
  );
}