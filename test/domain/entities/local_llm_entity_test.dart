import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_app/features/chat/domain/entities/local_llm_entity.dart';

void main() {
  group('LocalLLMStatusEntity', () {
    test('displayText should return correct text for each status', () {
      expect(LocalLLMStatusEntity.stopped.displayText, 'Detenido');
      expect(LocalLLMStatusEntity.loading.displayText, 'Cargando...');
      expect(LocalLLMStatusEntity.ready.displayText, 'Listo');
      expect(LocalLLMStatusEntity.error.displayText, 'Error');
    });

    test('emoji should return correct emoji for each status', () {
      expect(LocalLLMStatusEntity.stopped.emoji, '⚫');
      expect(LocalLLMStatusEntity.loading.emoji, '🟡');
      expect(LocalLLMStatusEntity.ready.emoji, '🟢');
      expect(LocalLLMStatusEntity.error.emoji, '🔴');
    });

    test('isUsable should return true only for ready status', () {
      expect(LocalLLMStatusEntity.stopped.isUsable, false);
      expect(LocalLLMStatusEntity.loading.isUsable, false);
      expect(LocalLLMStatusEntity.ready.isUsable, true);
      expect(LocalLLMStatusEntity.error.isUsable, false);
    });
  });

  group('LocalLLMInitResultEntity', () {
    test('should create a successful result', () {
      const result = LocalLLMInitResultEntity(
        success: true,
        modelName: 'phi3',
        modelSize: '2.3 GB',
        loadTimeMs: 1500,
      );

      expect(result.success, true);
      expect(result.modelName, 'phi3');
      expect(result.modelSize, '2.3 GB');
      expect(result.loadTimeMs, 1500);
      expect(result.error, isNull);
    });

    test('should create a failed result', () {
      const result = LocalLLMInitResultEntity(
        success: false,
        error: 'Failed to load model',
      );

      expect(result.success, false);
      expect(result.error, 'Failed to load model');
      expect(result.modelName, isNull);
    });

    test('userMessage should format success message correctly', () {
      const result = LocalLLMInitResultEntity(
        success: true,
        modelName: 'phi3',
        modelSize: '2.3 GB',
        loadTimeMs: 1500,
      );

      final message = result.userMessage;

      expect(message, contains('✅'));
      expect(message, contains('phi3'));
      expect(message, contains('2.3 GB'));
      expect(message, contains('1500ms'));
    });

    test('userMessage should format error message correctly', () {
      const result = LocalLLMInitResultEntity(
        success: false,
        error: 'Connection failed',
      );

      final message = result.userMessage;

      expect(message, contains('❌'));
      expect(message, contains('Connection failed'));
    });

    test('userMessage should handle unknown error', () {
      const result = LocalLLMInitResultEntity(success: false);

      final message = result.userMessage;

      expect(message, contains('Desconocido'));
    });

    test('copyWith should create a new instance with modified properties', () {
      const original = LocalLLMInitResultEntity(
        success: true,
        modelName: 'phi3',
        modelSize: '2.3 GB',
      );

      final copied = original.copyWith(
        modelSize: '2.5 GB',
        loadTimeMs: 2000,
      );

      expect(copied.success, true);
      expect(copied.modelName, 'phi3');
      expect(copied.modelSize, '2.5 GB');
      expect(copied.loadTimeMs, 2000);
    });
  });

  group('LocalLLMModelInfoEntity', () {
    test('should create a model info entity', () {
      const model = LocalLLMModelInfoEntity(
        name: 'phi3',
        displayName: 'Phi-3 Mini',
        description: 'Small but powerful model',
        isDownloaded: true,
        filePath: '/models/phi3.gguf',
        fileSizeBytes: 2400000000,
      );

      expect(model.name, 'phi3');
      expect(model.displayName, 'Phi-3 Mini');
      expect(model.description, 'Small but powerful model');
      expect(model.isDownloaded, true);
      expect(model.filePath, '/models/phi3.gguf');
      expect(model.fileSizeBytes, 2400000000);
    });

    test('sizeFormatted should format MB correctly', () {
      const model = LocalLLMModelInfoEntity(
        name: 'test',
        displayName: 'Test',
        description: 'Test',
        isDownloaded: false,
        fileSizeBytes: 500 * 1024 * 1024, // 500 MB
      );

      expect(model.sizeFormatted, '500.0 MB');
    });

    test('sizeFormatted should format GB correctly', () {
      const model = LocalLLMModelInfoEntity(
        name: 'test',
        displayName: 'Test',
        description: 'Test',
        isDownloaded: false,
        fileSizeBytes: 2400000000, // ~2.24 GB
      );

      expect(model.sizeFormatted, contains('GB'));
    });

    test('sizeFormatted should handle null size', () {
      const model = LocalLLMModelInfoEntity(
        name: 'test',
        displayName: 'Test',
        description: 'Test',
        isDownloaded: false,
      );

      expect(model.sizeFormatted, 'Desconocido');
    });

    test('copyWith should work correctly', () {
      const original = LocalLLMModelInfoEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: false,
      );

      final copied = original.copyWith(
        isDownloaded: true,
        filePath: '/models/phi3.gguf',
      );

      expect(copied.name, 'phi3');
      expect(copied.isDownloaded, true);
      expect(copied.filePath, '/models/phi3.gguf');
    });

    test('equality should work correctly', () {
      const model1 = LocalLLMModelInfoEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: true,
        fileSizeBytes: 2400000000,
      );

      const model2 = LocalLLMModelInfoEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: true,
        fileSizeBytes: 2400000000,
      );

      const model3 = LocalLLMModelInfoEntity(
        name: 'llama',
        displayName: 'Llama',
        description: 'Test',
        isDownloaded: false,
      );

      expect(model1, model2);
      expect(model1, isNot(model3));
    });

    test('hashCode should be consistent', () {
      const model1 = LocalLLMModelInfoEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: true,
      );

      const model2 = LocalLLMModelInfoEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: true,
      );

      expect(model1.hashCode, model2.hashCode);
    });
  });

  group('LocalLLMConfigEntity', () {
    test('should create config with default values', () {
      const config = LocalLLMConfigEntity();

      expect(config.contextSize, 2048);
      expect(config.maxTokens, 512);
      expect(config.temperature, 0.7);
      expect(config.numThreads, 4);
      expect(config.useGPU, false);
    });

    test('should create config with custom values', () {
      const config = LocalLLMConfigEntity(
        contextSize: 4096,
        maxTokens: 1024,
        temperature: 0.9,
        numThreads: 8,
        useGPU: true,
      );

      expect(config.contextSize, 4096);
      expect(config.maxTokens, 1024);
      expect(config.temperature, 0.9);
      expect(config.numThreads, 8);
      expect(config.useGPU, true);
    });

    test('copyWith should work correctly', () {
      const original = LocalLLMConfigEntity(
        contextSize: 2048,
        temperature: 0.7,
      );

      final copied = original.copyWith(
        contextSize: 4096,
        useGPU: true,
      );

      expect(copied.contextSize, 4096);
      expect(copied.temperature, 0.7);
      expect(copied.useGPU, true);
    });
  });
}