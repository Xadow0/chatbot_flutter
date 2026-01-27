import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Entidades
import 'package:chatbot_app/features/chat/domain/entities/message_entity.dart';
import 'package:chatbot_app/features/chat/domain/entities/quick_response_entity.dart';

// Modelos
import 'package:chatbot_app/features/chat/data/models/remote_ollama_models.dart';
import 'package:chatbot_app/features/chat/data/models/local_ollama_models.dart';

// Datasources
import 'package:chatbot_app/features/chat/data/datasources/remote/gemini_datasource.dart';
import 'package:chatbot_app/features/chat/data/datasources/remote/ollama_remote_source.dart';
import 'package:chatbot_app/features/chat/data/datasources/remote/openai_datasource.dart';
import 'package:chatbot_app/features/chat/data/datasources/local/local_ollama_source.dart';
import 'package:chatbot_app/features/chat/data/datasources/ai_interfaces/ai_service_adapters.dart';

// Utils
import 'package:chatbot_app/features/chat/data/utils/ai_service_selector.dart';

// Repositorios
import 'package:chatbot_app/features/chat/domain/repositories/conversation_repository.dart';
import 'package:chatbot_app/features/commands/domain/repositories/command_repository.dart';

// Providers
import 'package:chatbot_app/features/commands/presentation/logic/command_provider.dart';
import 'package:chatbot_app/features/chat/presentation/logic/chat_provider.dart';

// ==============================================================================
// MOCKS
// ==============================================================================

class MockConversationRepository extends Mock implements IConversationRepository {}

class MockCommandRepository extends Mock implements ICommandRepository {}

class MockAIServiceSelector extends Mock implements AIServiceSelector {}

class MockGeminiService extends Mock implements GeminiService {}

class MockOllamaService extends Mock implements OllamaService {}

class MockOpenAIService extends Mock implements OpenAIService {}

class MockOllamaManagedService extends Mock implements OllamaManagedService {}

class MockCommandManagementProvider extends Mock implements CommandManagementProvider {}

class MockFile extends Mock implements File {}

// Fake classes para registerFallbackValue
class FakeFile extends Fake implements File {}

class FakeMessageEntity extends Fake implements MessageEntity {}

// ==============================================================================
// TEST HELPERS
// ==============================================================================

/// Helper para crear ConnectionInfo válido
ConnectionInfo createTestConnectionInfo({
  ConnectionStatus status = ConnectionStatus.disconnected,
  String url = 'http://localhost:11434',
  bool isHealthy = false,
  String? errorMessage,
}) {
  return ConnectionInfo(
    status: status,
    url: url,
    isHealthy: isHealthy,
    errorMessage: errorMessage,
  );
}

/// Helper para configurar MockGeminiService para streaming
void setupMockGeminiServiceForStreaming(
  MockGeminiService mockService, {
  List<String> responses = const ['Response'],
}) {
  when(() => mockService.generateContentStreamContext(any()))
      .thenAnswer((_) => Stream.fromIterable(responses));
  when(() => mockService.generateContentStream(any()))
      .thenAnswer((_) => Stream.fromIterable(responses));
}

/// Helper para crear un ChatProvider configurado para tests
ChatProvider createTestChatProvider({
  required MockConversationRepository conversationRepository,
  required MockCommandRepository commandRepository,
  required MockAIServiceSelector aiServiceSelector,
  required MockGeminiService geminiService,
  required MockOllamaService ollamaService,
  required MockOpenAIService openaiService,
  required MockOllamaManagedService localOllamaService,
}) {
  // Configurar el AIServiceSelector con los servicios mock
  when(() => aiServiceSelector.geminiService).thenReturn(geminiService);
  when(() => aiServiceSelector.ollamaService).thenReturn(ollamaService);
  when(() => aiServiceSelector.openaiService).thenReturn(openaiService);
  when(() => aiServiceSelector.localOllamaService).thenReturn(localOllamaService);
  when(() => aiServiceSelector.ollamaAvailable).thenReturn(false);
  when(() => aiServiceSelector.openaiAvailable).thenReturn(false);
  when(() => aiServiceSelector.localOllamaAvailable).thenReturn(false);
  when(() => aiServiceSelector.localOllamaLoading).thenReturn(false);
  when(() => aiServiceSelector.localOllamaStatus).thenReturn(LocalOllamaStatus.notInitialized);
  when(() => aiServiceSelector.availableModels).thenReturn([]);
  when(() => aiServiceSelector.currentOllamaModel).thenReturn('phi3:latest');
  when(() => aiServiceSelector.currentOpenAIModel).thenReturn('gpt-4');
  when(() => aiServiceSelector.availableOpenAIModels).thenReturn(['gpt-4', 'gpt-3.5-turbo']);
  when(() => aiServiceSelector.connectionInfo).thenReturn(createTestConnectionInfo());
  when(() => aiServiceSelector.connectionStream).thenAnswer(
    (_) => Stream.value(createTestConnectionInfo(status: ConnectionStatus.connected, isHealthy: true)),
  );
  when(() => aiServiceSelector.addListener(any())).thenAnswer((_) {});
  when(() => aiServiceSelector.removeListener(any())).thenAnswer((_) {});
  when(() => aiServiceSelector.dispose()).thenAnswer((_) {});

  return ChatProvider(
    conversationRepository: conversationRepository,
    commandRepository: commandRepository,
    aiServiceSelector: aiServiceSelector,
  );
}

/// Helper para crear mensajes de prueba
MessageEntity createTestMessage({
  String? id,
  required String content,
  required MessageTypeEntity type,
  DateTime? timestamp,
}) {
  return MessageEntity(
    id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
    content: content,
    type: type,
    timestamp: timestamp ?? DateTime.now(),
  );
}

/// Helper para crear lista de mensajes de conversación
List<MessageEntity> createTestConversation({int messageCount = 4}) {
  final messages = <MessageEntity>[];
  for (int i = 0; i < messageCount; i++) {
    final isUser = i % 2 == 0;
    messages.add(createTestMessage(
      id: 'msg_$i',
      content: isUser ? 'User message $i' : 'Bot response $i',
      type: isUser ? MessageTypeEntity.user : MessageTypeEntity.bot,
    ));
  }
  return messages;
}

// ==============================================================================
// MAIN TEST SUITE
// ==============================================================================

void main() {
  // Registrar fallback values para mocktail
  setUpAll(() {
    registerFallbackValue(FakeFile());
    registerFallbackValue(FakeMessageEntity());
    registerFallbackValue(AIProvider.gemini);
    registerFallbackValue(<MessageEntity>[]);
    registerFallbackValue(<File>[]);
  });

  // Variables comunes para los tests
  late MockConversationRepository mockConversationRepository;
  late MockCommandRepository mockCommandRepository;
  late MockAIServiceSelector mockAIServiceSelector;
  late MockGeminiService mockGeminiService;
  late MockOllamaService mockOllamaService;
  late MockOpenAIService mockOpenAIService;
  late MockOllamaManagedService mockLocalOllamaService;
  late ChatProvider chatProvider;

  setUp(() async {
    // Configurar SharedPreferences para tests
    SharedPreferences.setMockInitialValues({});

    // Crear mocks frescos para cada test
    mockConversationRepository = MockConversationRepository();
    mockCommandRepository = MockCommandRepository();
    mockAIServiceSelector = MockAIServiceSelector();
    mockGeminiService = MockGeminiService();
    mockOllamaService = MockOllamaService();
    mockOpenAIService = MockOpenAIService();
    mockLocalOllamaService = MockOllamaManagedService();

    // Configurar comportamientos por defecto de los mocks
    when(() => mockCommandRepository.getAllCommands()).thenAnswer((_) async => []);
    when(() => mockCommandRepository.getAllFolders()).thenAnswer((_) async => []);
    when(() => mockConversationRepository.listConversations()).thenAnswer((_) async => []);
    when(() => mockConversationRepository.saveConversation(any(), existingFile: any(named: 'existingFile')))
        .thenAnswer((_) async => MockFile());
    when(() => mockConversationRepository.loadConversation(any()))
        .thenAnswer((_) async => createTestConversation());
    when(() => mockConversationRepository.deleteAllConversations()).thenAnswer((_) async {});
    when(() => mockConversationRepository.deleteConversations(any())).thenAnswer((_) async {});

    when(() => mockGeminiService.clearConversation()).thenAnswer((_) {});
    when(() => mockGeminiService.addUserMessage(any())).thenAnswer((_) {});
    when(() => mockGeminiService.addBotMessage(any())).thenAnswer((_) {});

    when(() => mockOllamaService.clearConversation()).thenAnswer((_) {});
    when(() => mockOllamaService.addUserMessage(any())).thenAnswer((_) {});
    when(() => mockOllamaService.addBotMessage(any())).thenAnswer((_) {});
    when(() => mockOllamaService.reconnect()).thenAnswer((_) async {});

    when(() => mockOpenAIService.clearConversation()).thenAnswer((_) {});
    when(() => mockOpenAIService.addUserMessage(any())).thenAnswer((_) {});
    when(() => mockOpenAIService.addBotMessage(any())).thenAnswer((_) {});

    when(() => mockLocalOllamaService.clearConversation()).thenAnswer((_) {});
    when(() => mockLocalOllamaService.addUserMessage(any())).thenAnswer((_) {});
    when(() => mockLocalOllamaService.addBotMessage(any())).thenAnswer((_) {});

    // Crear el provider
    chatProvider = createTestChatProvider(
      conversationRepository: mockConversationRepository,
      commandRepository: mockCommandRepository,
      aiServiceSelector: mockAIServiceSelector,
      geminiService: mockGeminiService,
      ollamaService: mockOllamaService,
      openaiService: mockOpenAIService,
      localOllamaService: mockLocalOllamaService,
    );

    // Esperar a que se complete la inicialización
    await Future.delayed(const Duration(milliseconds: 100));
  });

  tearDown(() {
    chatProvider.dispose();
  });

  // ============================================================================
  // GRUPO: Inicialización y Estado Inicial
  // ============================================================================
  group('Initialization', () {
    test('should initialize with default values', () {
      expect(chatProvider.isProcessing, isFalse);
      expect(chatProvider.isStreaming, isFalse);
      expect(chatProvider.showModelSelector, isFalse);
      expect(chatProvider.hasUnsavedChanges, isFalse);
      expect(chatProvider.hasActiveSession, isFalse);
      expect(chatProvider.isRetryingOllama, isFalse);
      expect(chatProvider.currentProvider, equals(AIProvider.gemini));
    });

    test('should add welcome message on initialization', () async {
      await Future.delayed(const Duration(milliseconds: 200));
      expect(chatProvider.messages.isNotEmpty, isTrue);
      expect(chatProvider.messages.first.type, equals(MessageTypeEntity.bot));
    });

    test('should initialize quick responses', () async {
      await Future.delayed(const Duration(milliseconds: 200));
      expect(chatProvider.quickResponses, isNotEmpty);
    });

    test('should register listener on AIServiceSelector', () {
      verify(() => mockAIServiceSelector.addListener(any())).called(1);
    });
  });

  // ============================================================================
  // GRUPO: Getters
  // ============================================================================
  group('Getters', () {
    test('messages getter should return unmodifiable list', () {
      final messages = chatProvider.messages;
      expect(() => (messages as List).add(createTestMessage(
        content: 'test',
        type: MessageTypeEntity.user,
      )), throwsA(isA<UnsupportedError>()));
    });

    test('quickResponses getter should return current quick responses', () {
      expect(chatProvider.quickResponses, isA<List<QuickResponseEntity>>());
    });

    test('currentModel should return default model', () {
      expect(chatProvider.currentModel, equals('phi3:latest'));
    });

    test('availableModels should return list from AISelector', () {
      expect(chatProvider.availableModels, isEmpty);
    });

    test('connectionInfo should return info from AISelector', () {
      final info = chatProvider.connectionInfo;
      expect(info, isNotNull);
      expect(info.status, equals(ConnectionStatus.disconnected));
    });

    test('ollamaAvailable should combine selector and selectable state', () {
      expect(chatProvider.ollamaAvailable, isFalse);
    });

    test('openaiAvailable should return value from AISelector', () {
      expect(chatProvider.openaiAvailable, isFalse);
    });

    test('localOllamaAvailable should return value from AISelector', () {
      expect(chatProvider.localOllamaAvailable, isFalse);
    });

    test('localOllamaStatus should return status from AISelector', () {
      expect(chatProvider.localOllamaStatus, equals(LocalOllamaStatus.notInitialized));
    });

    test('currentOpenAIModel should return model from AISelector', () {
      expect(chatProvider.currentOpenAIModel, equals('gpt-4'));
    });

    test('availableOpenAIModels should return models from AISelector', () {
      expect(chatProvider.availableOpenAIModels, containsAll(['gpt-4', 'gpt-3.5-turbo']));
    });

    test('connectionStream should return stream from AISelector', () {
      expect(chatProvider.connectionStream, isA<Stream<ConnectionInfo>>());
    });
  });

  // ============================================================================
  // GRUPO: hasSignificantContent
  // ============================================================================
  group('hasSignificantContent', () {
    test('should return false when only welcome message exists', () async {
      await chatProvider.clearMessages();
      expect(chatProvider.messages.length, equals(1));
      expect(chatProvider.messages.first.type, equals(MessageTypeEntity.bot));
      expect(chatProvider.hasSignificantContent, isFalse);
    });

    test('should return true when user message exists', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());

      await chatProvider.loadConversation(mockFile);

      expect(chatProvider.hasSignificantContent, isTrue);
    });
  });

  // ============================================================================
  // GRUPO: Model Selector
  // ============================================================================
  group('Model Selector', () {
    test('toggleModelSelector should toggle showModelSelector', () {
      expect(chatProvider.showModelSelector, isFalse);
      
      chatProvider.toggleModelSelector();
      expect(chatProvider.showModelSelector, isTrue);
      
      chatProvider.toggleModelSelector();
      expect(chatProvider.showModelSelector, isFalse);
    });

    test('hideModelSelector should set showModelSelector to false', () {
      chatProvider.toggleModelSelector();
      expect(chatProvider.showModelSelector, isTrue);
      
      chatProvider.hideModelSelector();
      expect(chatProvider.showModelSelector, isFalse);
    });

    test('hideModelSelector should not notify if already hidden', () {
      var notificationCount = 0;
      chatProvider.addListener(() => notificationCount++);
      
      chatProvider.hideModelSelector();
      expect(notificationCount, equals(0));
    });
  });

  // ============================================================================
  // GRUPO: Select Model
  // ============================================================================
  group('selectModel', () {
    test('should update current model', () async {
      when(() => mockAIServiceSelector.setOllamaModel(any())).thenAnswer((_) async {});
      
      await chatProvider.selectModel('llama2:latest');
      
      expect(chatProvider.currentModel, equals('llama2:latest'));
    });

    test('should hide model selector after selection', () async {
      when(() => mockAIServiceSelector.setOllamaModel(any())).thenAnswer((_) async {});
      
      chatProvider.toggleModelSelector();
      expect(chatProvider.showModelSelector, isTrue);
      
      await chatProvider.selectModel('llama2:latest');
      
      expect(chatProvider.showModelSelector, isFalse);
    });

    test('should handle error when selecting model', () async {
      when(() => mockAIServiceSelector.setOllamaModel(any()))
          .thenThrow(Exception('Model selection failed'));
      
      await expectLater(
        chatProvider.selectModel('invalid:model'),
        completes,
      );
    });
  });

  // ============================================================================
  // GRUPO: Select Provider
  // ============================================================================
  group('selectProvider', () {
    test('should change to Gemini provider', () async {
      when(() => mockAIServiceSelector.setProvider(AIProvider.gemini))
          .thenAnswer((_) async {});
      
      await chatProvider.selectProvider(AIProvider.gemini);
      
      expect(chatProvider.currentProvider, equals(AIProvider.gemini));
    });

    test('should not change to Ollama if not available', () async {
      when(() => mockAIServiceSelector.ollamaAvailable).thenReturn(false);
      
      final previousProvider = chatProvider.currentProvider;
      await chatProvider.selectProvider(AIProvider.ollama);
      
      expect(chatProvider.currentProvider, equals(previousProvider));
    });

    test('should change to Ollama if available', () async {
      when(() => mockAIServiceSelector.ollamaAvailable).thenReturn(true);
      when(() => mockAIServiceSelector.setProvider(AIProvider.ollama))
          .thenAnswer((_) async {});
      
      await chatProvider.selectProvider(AIProvider.ollama);
      
      expect(chatProvider.currentProvider, equals(AIProvider.ollama));
    });

    test('should not change to OpenAI if not available', () async {
      when(() => mockAIServiceSelector.openaiAvailable).thenReturn(false);
      
      final previousProvider = chatProvider.currentProvider;
      await chatProvider.selectProvider(AIProvider.openai);
      
      expect(chatProvider.currentProvider, equals(previousProvider));
    });

    test('should change to OpenAI if available', () async {
      when(() => mockAIServiceSelector.openaiAvailable).thenReturn(true);
      when(() => mockAIServiceSelector.setProvider(AIProvider.openai))
          .thenAnswer((_) async {});
      
      await chatProvider.selectProvider(AIProvider.openai);
      
      expect(chatProvider.currentProvider, equals(AIProvider.openai));
    });

    test('should not change to LocalOllama if not available', () async {
      when(() => mockAIServiceSelector.localOllamaAvailable).thenReturn(false);
      
      final previousProvider = chatProvider.currentProvider;
      await chatProvider.selectProvider(AIProvider.localOllama);
      
      expect(chatProvider.currentProvider, equals(previousProvider));
    });

    test('should change to LocalOllama if available', () async {
      when(() => mockAIServiceSelector.localOllamaAvailable).thenReturn(true);
      when(() => mockAIServiceSelector.setProvider(AIProvider.localOllama))
          .thenAnswer((_) async {});
      
      await chatProvider.selectProvider(AIProvider.localOllama);
      
      expect(chatProvider.currentProvider, equals(AIProvider.localOllama));
    });

    test('should hide model selector after provider change', () async {
      when(() => mockAIServiceSelector.setProvider(any()))
          .thenAnswer((_) async {});
      
      chatProvider.toggleModelSelector();
      await chatProvider.selectProvider(AIProvider.gemini);
      
      expect(chatProvider.showModelSelector, isFalse);
    });
  });

  // ============================================================================
  // GRUPO: Select OpenAI Model
  // ============================================================================
  group('selectOpenAIModel', () {
    test('should call setOpenAIModel on AISelector', () async {
      when(() => mockAIServiceSelector.setOpenAIModel(any()))
          .thenAnswer((_) async {});
      
      await chatProvider.selectOpenAIModel('gpt-3.5-turbo');
      
      verify(() => mockAIServiceSelector.setOpenAIModel('gpt-3.5-turbo')).called(1);
    });

    test('should handle error gracefully', () async {
      when(() => mockAIServiceSelector.setOpenAIModel(any()))
          .thenThrow(Exception('Model not available'));
      
      await expectLater(
        chatProvider.selectOpenAIModel('invalid-model'),
        completes,
      );
    });
  });

  // ============================================================================
  // GRUPO: Send Message
  // ============================================================================
  group('sendMessage', () {
    test('should not send empty message', () async {
      final initialMessageCount = chatProvider.messages.length;
      
      await chatProvider.sendMessage('');
      await chatProvider.sendMessage('   ');
      
      expect(chatProvider.messages.length, equals(initialMessageCount));
    });

    test('should detect command messages starting with /', () async {
      // Configurar el adapter usando GeminiServiceAdapter con el mock
      setupMockGeminiServiceForStreaming(mockGeminiService, responses: ['Command response']);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('/help');
      
      expect(
        chatProvider.messages.any((m) => m.content == '/help' && m.type == MessageTypeEntity.user),
        isTrue,
      );
    });

    test('should add user and bot messages on successful send', () async {
      setupMockGeminiServiceForStreaming(mockGeminiService, responses: ['Hello', ' ', 'World']);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      final initialCount = chatProvider.messages.length;
      
      await chatProvider.sendMessage('Test message');
      
      expect(chatProvider.messages.length, greaterThan(initialCount));
      expect(
        chatProvider.messages.any((m) => 
          m.content == 'Test message' && m.type == MessageTypeEntity.user),
        isTrue,
      );
    });

    test('should set hasActiveSession to true after sending message', () async {
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      expect(chatProvider.hasActiveSession, isFalse);
      
      await chatProvider.sendMessage('Test');
      
      expect(chatProvider.hasActiveSession, isTrue);
    });

    test('should set hasUnsavedChanges to true after message', () async {
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('Test');
      
      expect(chatProvider.hasUnsavedChanges, isTrue);
    });
  });

  // ============================================================================
  // GRUPO: Clear Messages
  // ============================================================================
  group('clearMessages', () {
    test('should clear all messages and add welcome message', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      expect(chatProvider.messages.length, greaterThan(1));
      
      await chatProvider.clearMessages();
      
      expect(chatProvider.messages.length, equals(1));
      expect(chatProvider.messages.first.type, equals(MessageTypeEntity.bot));
    });

    test('should clear AI service history', () async {
      await chatProvider.clearMessages();
      
      verify(() => mockGeminiService.clearConversation()).called(greaterThanOrEqualTo(1));
      verify(() => mockOpenAIService.clearConversation()).called(greaterThanOrEqualTo(1));
      verify(() => mockOllamaService.clearConversation()).called(greaterThanOrEqualTo(1));
      verify(() => mockLocalOllamaService.clearConversation()).called(greaterThanOrEqualTo(1));
    });

    test('should reset hasUnsavedChanges to false', () async {
      await chatProvider.clearMessages();
      expect(chatProvider.hasUnsavedChanges, isFalse);
    });
  });

  // ============================================================================
  // GRUPO: Start New Conversation
  // ============================================================================
  group('startNewConversation', () {
    test('should save current conversation before starting new one', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('New message');
      
      await chatProvider.startNewConversation();
      
      verify(() => mockConversationRepository.saveConversation(
        any(),
        existingFile: any(named: 'existingFile'),
      )).called(greaterThanOrEqualTo(1));
    });

    test('should reset hasActiveSession', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      expect(chatProvider.hasActiveSession, isTrue);
      
      await chatProvider.startNewConversation();
      
      expect(chatProvider.hasActiveSession, isFalse);
    });

    test('should add welcome message', () async {
      await chatProvider.startNewConversation();
      
      expect(chatProvider.messages.isNotEmpty, isTrue);
      expect(chatProvider.messages.first.type, equals(MessageTypeEntity.bot));
    });
  });

  // ============================================================================
  // GRUPO: Load Conversation
  // ============================================================================
  group('loadConversation', () {
    test('should load messages from file', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      
      final testMessages = createTestConversation(messageCount: 6);
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => testMessages);
      
      await chatProvider.loadConversation(mockFile);
      
      expect(chatProvider.messages.length, equals(6));
      verify(() => mockConversationRepository.loadConversation(mockFile)).called(1);
    });

    test('should set hasActiveSession to true', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      expect(chatProvider.hasActiveSession, isTrue);
    });

    test('should not reload same file with unsaved changes', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('New message');
      
      await chatProvider.loadConversation(mockFile);
      
      verify(() => mockConversationRepository.loadConversation(mockFile)).called(1);
    });

    test('should handle load error gracefully', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenThrow(Exception('File not found'));
      
      await expectLater(
        chatProvider.loadConversation(mockFile),
        completes,
      );
    });
  });

  // ============================================================================
  // GRUPO: Save Conversation
  // ============================================================================
  group('saveCurrentConversation', () {
    test('should not save if no significant content', () async {
      await chatProvider.clearMessages();
      await chatProvider.saveCurrentConversation();
      
      verifyNever(() => mockConversationRepository.saveConversation(
        any(),
        existingFile: any(named: 'existingFile'),
      ));
    });

    test('should not save if no unsaved changes', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      await chatProvider.saveCurrentConversation();
      
      verifyNever(() => mockConversationRepository.saveConversation(
        any(),
        existingFile: any(named: 'existingFile'),
      ));
    });

    test('should save conversation with unsaved changes', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('New message');
      
      await chatProvider.saveCurrentConversation();
      
      verify(() => mockConversationRepository.saveConversation(
        any(),
        existingFile: any(named: 'existingFile'),
      )).called(greaterThanOrEqualTo(1));
    });

    test('should reset hasUnsaved changes after save', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('New message');
      expect(chatProvider.hasUnsavedChanges, isTrue);
      
      await chatProvider.saveCurrentConversation();
      
      expect(chatProvider.hasUnsavedChanges, isFalse);
    });
  });

  // ============================================================================
  // GRUPO: Delete Conversations
  // ============================================================================
  group('deleteAllConversations', () {
    test('should return success result', () async {
      final result = await chatProvider.deleteAllConversations();
      
      expect(result.success, isTrue);
      verify(() => mockConversationRepository.deleteAllConversations()).called(1);
    });

    test('should handle error and return failure result', () async {
      when(() => mockConversationRepository.deleteAllConversations())
          .thenThrow(Exception('Delete failed'));
      
      final result = await chatProvider.deleteAllConversations();
      
      expect(result.success, isFalse);
      expect(result.message, contains('Error'));
    });

    test('should indicate sync status in result message', () async {
      chatProvider.setSyncStatusChecker(() => true);
      
      final result = await chatProvider.deleteAllConversations();
      
      expect(result.syncWasEnabled, isTrue);
      expect(result.message, contains('nube'));
    });
  });

  group('deleteConversations', () {
    test('should delete specified files', () async {
      final files = [MockFile(), MockFile()];
      
      final result = await chatProvider.deleteConversations(files);
      
      expect(result.success, isTrue);
      verify(() => mockConversationRepository.deleteConversations(files)).called(1);
    });

    test('should return correct count in message', () async {
      final files = [MockFile(), MockFile(), MockFile()];
      
      final result = await chatProvider.deleteConversations(files);
      
      expect(result.message, contains('3'));
    });

    test('should handle error gracefully', () async {
      when(() => mockConversationRepository.deleteConversations(any()))
          .thenThrow(Exception('Delete failed'));
      
      final result = await chatProvider.deleteConversations([MockFile()]);
      
      expect(result.success, isFalse);
    });
  });

  // ============================================================================
  // GRUPO: Cancel Streaming
  // ============================================================================
  group('cancelStreaming', () {
    test('should not do anything if not streaming', () {
      var notificationCount = 0;
      chatProvider.addListener(() => notificationCount++);
      
      chatProvider.cancelStreaming();
      
      expect(notificationCount, equals(0));
    });

    test('should set hasUnsavedChanges when canceling active stream', () async {
      final controller = StreamController<String>();
      when(() => mockGeminiService.generateContentStreamContext(any()))
          .thenAnswer((_) => controller.stream);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      chatProvider.sendMessage('Test');
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      if (chatProvider.isStreaming) {
        chatProvider.cancelStreaming();
        expect(chatProvider.hasUnsavedChanges, isTrue);
      }
      
      controller.close();
    });
  });

  // ============================================================================
  // GRUPO: Retry Ollama Connection
  // ============================================================================
  group('retryOllamaConnection', () {
    test('should set isRetryingOllama during retry', () async {
      when(() => mockAIServiceSelector.ollamaAvailable).thenReturn(false);
      
      final future = chatProvider.retryOllamaConnection();
      
      expect(chatProvider.isRetryingOllama, isTrue);
      
      await future;
      
      expect(chatProvider.isRetryingOllama, isFalse);
    });

    test('should return true on successful reconnection', () async {
      when(() => mockAIServiceSelector.ollamaAvailable).thenReturn(true);
      when(() => mockAIServiceSelector.setProvider(AIProvider.ollama))
          .thenAnswer((_) async {});
      
      final result = await chatProvider.retryOllamaConnection();
      
      expect(result, isTrue);
    });

    test('should return false on failed reconnection', () async {
      when(() => mockAIServiceSelector.ollamaAvailable).thenReturn(false);
      when(() => mockAIServiceSelector.setProvider(AIProvider.gemini))
          .thenAnswer((_) async {});
      
      final result = await chatProvider.retryOllamaConnection();
      
      expect(result, isFalse);
    });

  });

  // ============================================================================
  // GRUPO: Initialize Local Ollama
  // ============================================================================
  group('initializeLocalOllama', () {
    test('should return result from AISelector', () async {
      final expectedResult = LocalOllamaInitResult(success: true);
      when(() => mockAIServiceSelector.initializeLocalOllama())
          .thenAnswer((_) async => expectedResult);
      when(() => mockAIServiceSelector.localOllamaAvailable).thenReturn(true);
      when(() => mockAIServiceSelector.setProvider(AIProvider.localOllama))
          .thenAnswer((_) async {});
      
      final result = await chatProvider.initializeLocalOllama();
      
      expect(result, equals(expectedResult));
      expect(result!.success, isTrue);
    });

    test('should switch to LocalOllama on success', () async {
      when(() => mockAIServiceSelector.initializeLocalOllama())
          .thenAnswer((_) async => LocalOllamaInitResult(success: true));
      when(() => mockAIServiceSelector.localOllamaAvailable).thenReturn(true);
      when(() => mockAIServiceSelector.setProvider(AIProvider.localOllama))
          .thenAnswer((_) async {});
      
      await chatProvider.initializeLocalOllama();
      
      verify(() => mockAIServiceSelector.setProvider(AIProvider.localOllama)).called(1);
    });

    test('should return null on exception', () async {
      when(() => mockAIServiceSelector.initializeLocalOllama())
          .thenThrow(Exception('Init failed'));
      
      final result = await chatProvider.initializeLocalOllama();
      
      expect(result, isNull);
    });
  });

  // ============================================================================
  // GRUPO: List Conversations
  // ============================================================================
  group('listConversations', () {
    test('should delegate to repository', () async {
      final expectedFiles = <FileSystemEntity>[MockFile(), MockFile()];
      when(() => mockConversationRepository.listConversations())
          .thenAnswer((_) async => expectedFiles);
      
      final result = await chatProvider.listConversations();
      
      expect(result, equals(expectedFiles));
      verify(() => mockConversationRepository.listConversations()).called(1);
    });
  });

  // ============================================================================
  // GRUPO: Quick Responses
  // ============================================================================
  group('refreshQuickResponses', () {
    test('should update quick responses from repository', () async {
      await chatProvider.refreshQuickResponses();
      
      verify(() => mockCommandRepository.getAllCommands()).called(greaterThanOrEqualTo(1));
      verify(() => mockCommandRepository.getAllFolders()).called(greaterThanOrEqualTo(1));
    });
  });

  // ============================================================================
  // GRUPO: Command Management Provider Integration
  // ============================================================================
  group('setCommandManagementProvider', () {
    test('should register listener on new provider', () {
      final mockCommandProvider = MockCommandManagementProvider();
      when(() => mockCommandProvider.addListener(any())).thenAnswer((_) {});
      when(() => mockCommandProvider.removeListener(any())).thenAnswer((_) {});
      when(() => mockCommandProvider.isLoading).thenReturn(false);
      when(() => mockCommandProvider.commands).thenReturn([]);
      when(() => mockCommandProvider.folders).thenReturn([]);
      when(() => mockCommandProvider.groupSystemCommands).thenReturn(false);
      
      chatProvider.setCommandManagementProvider(mockCommandProvider);
      
      verify(() => mockCommandProvider.addListener(any())).called(1);
    });

    test('should remove listener from old provider', () {
      final oldProvider = MockCommandManagementProvider();
      final newProvider = MockCommandManagementProvider();
      
      when(() => oldProvider.addListener(any())).thenAnswer((_) {});
      when(() => oldProvider.removeListener(any())).thenAnswer((_) {});
      when(() => oldProvider.isLoading).thenReturn(false);
      when(() => oldProvider.commands).thenReturn([]);
      when(() => oldProvider.folders).thenReturn([]);
      when(() => oldProvider.groupSystemCommands).thenReturn(false);
      
      when(() => newProvider.addListener(any())).thenAnswer((_) {});
      when(() => newProvider.removeListener(any())).thenAnswer((_) {});
      when(() => newProvider.isLoading).thenReturn(false);
      when(() => newProvider.commands).thenReturn([]);
      when(() => newProvider.folders).thenReturn([]);
      when(() => newProvider.groupSystemCommands).thenReturn(false);
      
      chatProvider.setCommandManagementProvider(oldProvider);
      chatProvider.setCommandManagementProvider(newProvider);
      
      verify(() => oldProvider.removeListener(any())).called(1);
    });
  });

  // ============================================================================
  // GRUPO: Sync Status Checker
  // ============================================================================
  group('setSyncStatusChecker', () {
    test('should use provided checker for delete operations', () async {
      var checkerCalled = false;
      chatProvider.setSyncStatusChecker(() {
        checkerCalled = true;
        return true;
      });
      
      await chatProvider.deleteAllConversations();
      
      expect(checkerCalled, isTrue);
    });
  });

  // ============================================================================
  // GRUPO: App Lifecycle
  // ============================================================================
  group('onAppPaused', () {
    test('should call saveCurrentConversation', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('New message');
      
      await chatProvider.onAppPaused();
      
      verify(() => mockConversationRepository.saveConversation(
        any(),
        existingFile: any(named: 'existingFile'),
      )).called(greaterThanOrEqualTo(1));
    });
  });

  group('onAppDetached', () {
    test('should call saveCurrentConversation', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('New message');
      
      await chatProvider.onAppDetached();
      
      verify(() => mockConversationRepository.saveConversation(
        any(),
        existingFile: any(named: 'existingFile'),
      )).called(greaterThanOrEqualTo(1));
    });
  });

  // ============================================================================
  // GRUPO: End Session
  // ============================================================================
  group('endSession', () {
    test('should not save if only welcome message', () async {
      await chatProvider.clearMessages();
      
      await chatProvider.endSession();
      
      verifyNever(() => mockConversationRepository.saveConversation(
        any(),
        existingFile: any(named: 'existingFile'),
      ));
    });

    test('should save if has significant changes', () async {
      final mockFile = MockFile();
      when(() => mockFile.path).thenReturn('/test/conversation.json');
      when(() => mockConversationRepository.loadConversation(mockFile))
          .thenAnswer((_) async => createTestConversation());
      
      await chatProvider.loadConversation(mockFile);
      
      setupMockGeminiServiceForStreaming(mockGeminiService);
      final adapter = GeminiServiceAdapter(mockGeminiService);
      when(() => mockAIServiceSelector.getCurrentAdapter()).thenReturn(adapter);
      
      await chatProvider.sendMessage('Test');
      
      await chatProvider.endSession();
      
      verify(() => mockConversationRepository.saveConversation(
        any(),
        existingFile: any(named: 'existingFile'),
      )).called(greaterThanOrEqualTo(1));
    });
  });

  // ============================================================================
  // GRUPO: DeleteResult
  // ============================================================================
  group('DeleteResult', () {
    test('should create with required parameters', () {
      final result = DeleteResult(
        success: true,
        syncWasEnabled: false,
        message: 'Test message',
      );
      
      expect(result.success, isTrue);
      expect(result.syncWasEnabled, isFalse);
      expect(result.message, equals('Test message'));
    });
  });

  // ============================================================================
  // GRUPO: Notifications
  // ============================================================================
  group('Notifications', () {
    test('should notify listeners on toggle model selector', () {
      var notified = false;
      chatProvider.addListener(() => notified = true);
      
      chatProvider.toggleModelSelector();
      
      expect(notified, isTrue);
    });

    test('should notify listeners on provider change', () async {
      when(() => mockAIServiceSelector.setProvider(any()))
          .thenAnswer((_) async {});
      
      var notified = false;
      chatProvider.addListener(() => notified = true);
      
      await chatProvider.selectProvider(AIProvider.gemini);
      
      expect(notified, isTrue);
    });
  });
}