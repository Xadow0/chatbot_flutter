import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:chatbot_app/domain/entities/message_entity.dart';
import 'package:chatbot_app/domain/repositories/chat_repository.dart';
import 'package:chatbot_app/domain/usecases/command_processor.dart';
import 'package:chatbot_app/domain/usecases/send_message_usecase.dart';

@GenerateMocks([CommandProcessor, ChatRepository])
import 'send_message_usecase_test.mocks.dart';

void main() {
  late SendMessageUseCase sendMessageUseCase;
  late MockCommandProcessor mockCommandProcessor;
  late MockChatRepository mockChatRepository;

  setUp(() {
    mockCommandProcessor = MockCommandProcessor();
    mockChatRepository = MockChatRepository();
    sendMessageUseCase = SendMessageUseCase(
      commandProcessor: mockCommandProcessor,
      chatRepository: mockChatRepository,
    );
  });

  group('SendMessageUseCase - Command Processing', () {
    test('should process command and return bot message with result', () async {
      const userMessage = '/evaluarprompt Test prompt';
      final commandResult = CommandResult.success(
        CommandType.evaluarPrompt,
        'Prompt evaluation result',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, 'Prompt evaluation result');
      verify(mockCommandProcessor.processMessage(userMessage)).called(1);
      verifyNever(mockChatRepository.sendMessage(any));
    });

    test('should handle command error and return bot message with error', () async {
      const userMessage = '/traducir';
      final commandResult = CommandResult.error(
        CommandType.traducir,
        'Missing language parameter',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, contains('❌'));
      expect(result.content, contains('Missing language parameter'));
      verify(mockCommandProcessor.processMessage(userMessage)).called(1);
      verifyNever(mockChatRepository.sendMessage(any));
    });

    test('should handle command with null processedMessage', () async {
      const userMessage = '/test';
      final commandResult = CommandResult(
        isCommand: true,
        type: CommandType.evaluarPrompt,
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, contains('⚠️ Comando sin resultado'));
      verify(mockCommandProcessor.processMessage(userMessage)).called(1);
      verifyNever(mockChatRepository.sendMessage(any));
    });

    test('should process traducir command successfully', () async {
      const userMessage = '/traducir inglés Hola mundo';
      final commandResult = CommandResult.success(
        CommandType.traducir,
        'Hello world',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, 'Hello world');
    });

    test('should process resumir command successfully', () async {
      const userMessage = '/resumir Long text';
      final commandResult = CommandResult.success(
        CommandType.resumir,
        'Short summary',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, 'Short summary');
    });

    test('should process codigo command successfully', () async {
      const userMessage = '/codigo Create function';
      final commandResult = CommandResult.success(
        CommandType.codigo,
        'def hello(): pass',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, 'def hello(): pass');
    });

    test('should process corregir command successfully', () async {
      const userMessage = '/corregir Text with erors';
      final commandResult = CommandResult.success(
        CommandType.corregir,
        'Text with errors',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, 'Text with errors');
    });

    test('should process explicar command successfully', () async {
      const userMessage = '/explicar quantum physics';
      final commandResult = CommandResult.success(
        CommandType.explicar,
        'Quantum physics explanation',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, 'Quantum physics explanation');
    });

    test('should process comparar command successfully', () async {
      const userMessage = '/comparar A vs B';
      final commandResult = CommandResult.success(
        CommandType.comparar,
        'Comparison result',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.type, MessageTypeEntity.bot);
      expect(result.content, 'Comparison result');
    });
  });

  group('SendMessageUseCase - Non-Command Processing', () {
    test('should delegate to ChatRepository for non-command messages', () async {
      const userMessage = 'Hello, how are you?';
      final commandResult = CommandResult.notCommand();
      final expectedMessage = MessageEntity(
        id: '123',
        content: 'Echo: Hello, how are you?',
        type: MessageTypeEntity.bot,
        timestamp: DateTime(2024, 1, 1),
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);
      when(mockChatRepository.sendMessage(userMessage))
          .thenAnswer((_) async => expectedMessage);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result, expectedMessage);
      verify(mockCommandProcessor.processMessage(userMessage)).called(1);
      verify(mockChatRepository.sendMessage(userMessage)).called(1);
    });

    test('should handle regular messages correctly', () async {
      const userMessage = 'This is a regular message';
      final commandResult = CommandResult.notCommand();
      final repositoryMessage = MessageEntity(
        id: '456',
        content: 'Response from repository',
        type: MessageTypeEntity.bot,
        timestamp: DateTime(2024, 1, 1),
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);
      when(mockChatRepository.sendMessage(userMessage))
          .thenAnswer((_) async => repositoryMessage);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result, repositoryMessage);
    });

    test('should not call ChatRepository for command messages', () async {
      const userMessage = '/evaluarprompt test';
      final commandResult = CommandResult.success(
        CommandType.evaluarPrompt,
        'Result',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      await sendMessageUseCase.execute(userMessage);

      verifyNever(mockChatRepository.sendMessage(any));
    });
  });

  group('SendMessageUseCase - Message Entity Creation', () {
    test('should create message entity with correct properties for command', () async {
      const userMessage = '/test command';
      final commandResult = CommandResult.success(
        CommandType.evaluarPrompt,
        'Command result',
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result.id, isNotEmpty);
      expect(result.content, 'Command result');
      expect(result.type, MessageTypeEntity.bot);
      expect(result.timestamp, isA<DateTime>());
    });

    test('should generate unique IDs for different command executions', () async {
      final commandResult = CommandResult.success(
        CommandType.evaluarPrompt,
        'Result',
      );

      when(mockCommandProcessor.processMessage(any))
          .thenAnswer((_) async => commandResult);

      final result1 = await sendMessageUseCase.execute('/test 1');
      await Future.delayed(const Duration(milliseconds: 1));
      final result2 = await sendMessageUseCase.execute('/test 2');

      expect(result1.id, isNot(result2.id));
    });

    test('should set timestamp to current time', () async {
      final beforeExecution = DateTime.now();
      final commandResult = CommandResult.success(
        CommandType.evaluarPrompt,
        'Result',
      );

      when(mockCommandProcessor.processMessage(any))
          .thenAnswer((_) async => commandResult);

      final result = await sendMessageUseCase.execute('/test');
      final afterExecution = DateTime.now();

      expect(
        result.timestamp.isAfter(beforeExecution) ||
            result.timestamp.isAtSameMomentAs(beforeExecution),
        true,
      );
      expect(
        result.timestamp.isBefore(afterExecution) ||
            result.timestamp.isAtSameMomentAs(afterExecution),
        true,
      );
    });
  });

  group('SendMessageUseCase - Error Handling', () {
    test('should handle CommandProcessor exceptions', () async {
      const userMessage = '/test';

      when(mockCommandProcessor.processMessage(userMessage))
          .thenThrow(Exception('Command processor error'));

      expect(
        () => sendMessageUseCase.execute(userMessage),
        throwsException,
      );
    });

    test('should handle ChatRepository exceptions for non-commands', () async {
      const userMessage = 'Regular message';
      final commandResult = CommandResult.notCommand();

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);
      when(mockChatRepository.sendMessage(userMessage))
          .thenThrow(Exception('Repository error'));

      expect(
        () => sendMessageUseCase.execute(userMessage),
        throwsException,
      );
    });
  });

  group('SendMessageUseCase - Edge Cases', () {
    test('should handle empty message', () async {
      const userMessage = '';
      final commandResult = CommandResult.notCommand();
      final repositoryMessage = MessageEntity(
        id: '1',
        content: 'Echo: ',
        type: MessageTypeEntity.bot,
        timestamp: DateTime(2024, 1, 1),
      );

      when(mockCommandProcessor.processMessage(userMessage))
          .thenAnswer((_) async => commandResult);
      when(mockChatRepository.sendMessage(userMessage))
          .thenAnswer((_) async => repositoryMessage);

      final result = await sendMessageUseCase.execute(userMessage);

      expect(result, repositoryMessage);
    });

    test('should handle very long messages', () async {
      final longMessage = 'A' * 10000;
      final commandResult = CommandResult.notCommand();
      final repositoryMessage = MessageEntity(
        id: '1',
        content: 'Response',
        type: MessageTypeEntity.bot,
        timestamp: DateTime(2024, 1, 1),
      );

      when(mockCommandProcessor.processMessage(longMessage))
          .thenAnswer((_) async => commandResult);
      when(mockChatRepository.sendMessage(longMessage))
          .thenAnswer((_) async => repositoryMessage);

      final result = await sendMessageUseCase.execute(longMessage);

      expect(result, repositoryMessage);
    });

    test('should handle special characters in messages', () async {
      const specialMessage = '!@#\$%^&*()_+-=[]{}|;:,.<>?';
      final commandResult = CommandResult.notCommand();
      final repositoryMessage = MessageEntity(
        id: '1',
        content: 'Response',
        type: MessageTypeEntity.bot,
        timestamp: DateTime(2024, 1, 1),
      );

      when(mockCommandProcessor.processMessage(specialMessage))
          .thenAnswer((_) async => commandResult);
      when(mockChatRepository.sendMessage(specialMessage))
          .thenAnswer((_) async => repositoryMessage);

      final result = await sendMessageUseCase.execute(specialMessage);

      expect(result, repositoryMessage);
    });
  });
}