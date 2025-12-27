import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_app/features/chat/domain/entities/message_entity.dart';

void main() {
  group('MessageEntity', () {
    final testTimestamp = DateTime(2024, 1, 1, 12, 0, 0);

    test('should create a MessageEntity with all properties', () {
      final message = MessageEntity(
        id: '1',
        content: 'Test message',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      expect(message.id, '1');
      expect(message.content, 'Test message');
      expect(message.type, MessageTypeEntity.user);
      expect(message.timestamp, testTimestamp);
    });

    test('isUser should return true for user messages', () {
      final message = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      expect(message.isUser, true);
      expect(message.isBot, false);
    });

    test('isBot should return true for bot messages', () {
      final message = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.bot,
        timestamp: testTimestamp,
      );

      expect(message.isBot, true);
      expect(message.isUser, false);
    });

    test('displayPrefix should return correct emoji for user', () {
      final message = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      expect(message.displayPrefix, '👤');
    });

    test('displayPrefix should return correct emoji for bot', () {
      final message = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.bot,
        timestamp: testTimestamp,
      );

      expect(message.displayPrefix, '🤖');
    });

    test('displayName should return "Usuario" for user messages', () {
      final message = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      expect(message.displayName, 'Usuario');
    });

    test('displayName should return "Bot" for bot messages', () {
      final message = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.bot,
        timestamp: testTimestamp,
      );

      expect(message.displayName, 'Bot');
    });

    test('copyWith should create a new instance with modified properties', () {
      final original = MessageEntity(
        id: '1',
        content: 'Original content',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      final newTimestamp = DateTime(2024, 1, 2, 12, 0, 0);
      final copied = original.copyWith(
        content: 'Modified content',
        timestamp: newTimestamp,
      );

      expect(copied.id, '1');
      expect(copied.content, 'Modified content');
      expect(copied.type, MessageTypeEntity.user);
      expect(copied.timestamp, newTimestamp);
    });

    test('copyWith should keep original values when no parameters provided', () {
      final original = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      final copied = original.copyWith();

      expect(copied.id, original.id);
      expect(copied.content, original.content);
      expect(copied.type, original.type);
      expect(copied.timestamp, original.timestamp);
    });

    test('equality should work correctly', () {
      final message1 = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      final message2 = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      final message3 = MessageEntity(
        id: '2',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      expect(message1, message2);
      expect(message1, isNot(message3));
    });

    test('hashCode should be consistent', () {
      final message1 = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      final message2 = MessageEntity(
        id: '1',
        content: 'Test',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      expect(message1.hashCode, message2.hashCode);
    });

    test('toString should format message correctly', () {
      final message = MessageEntity(
        id: '1',
        content: 'Short message',
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      final result = message.toString();

      expect(result, contains('MessageEntity'));
      expect(result, contains('id: 1'));
      expect(result, contains('Short message'));
    });

    test('toString should truncate long content', () {
      const longContent = 'This is a very long message content that should be truncated';
      final message = MessageEntity(
        id: '1',
        content: longContent,
        type: MessageTypeEntity.user,
        timestamp: testTimestamp,
      );

      final result = message.toString();

      expect(result, contains('...'));
      expect(result.length, lessThan(longContent.length + 100));
    });
  });

  group('MessageTypeEntity', () {
    test('should have user and bot types', () {
      expect(MessageTypeEntity.user, isNotNull);
      expect(MessageTypeEntity.bot, isNotNull);
    });

    test('user and bot should be different', () {
      expect(MessageTypeEntity.user, isNot(MessageTypeEntity.bot));
    });
  });
}