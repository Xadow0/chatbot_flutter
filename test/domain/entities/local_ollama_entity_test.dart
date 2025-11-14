import 'package:flutter_test/flutter_test.dart';
import '../../../lib/domain/entities/local_ollama_entity.dart';

void main() {
  group('LocalOllamaStatusEntity', () {
    test('displayText should return correct text for each status', () {
      expect(LocalOllamaStatusEntity.notInitialized.displayText, 'No inicializado');
      expect(LocalOllamaStatusEntity.checkingInstallation.displayText, 'Verificando instalación...');
      expect(LocalOllamaStatusEntity.downloadingInstaller.displayText, 'Descargando Ollama...');
      expect(LocalOllamaStatusEntity.installing.displayText, 'Instalando Ollama...');
      expect(LocalOllamaStatusEntity.downloadingModel.displayText, 'Descargando modelo de IA...');
      expect(LocalOllamaStatusEntity.starting.displayText, 'Iniciando servidor...');
      expect(LocalOllamaStatusEntity.loading.displayText, 'Cargando modelo...');
      expect(LocalOllamaStatusEntity.ready.displayText, 'Listo');
      expect(LocalOllamaStatusEntity.error.displayText, 'Error');
    });

    test('emoji should return correct emoji for each status', () {
      expect(LocalOllamaStatusEntity.notInitialized.emoji, '⚫');
      expect(LocalOllamaStatusEntity.checkingInstallation.emoji, '🟡');
      expect(LocalOllamaStatusEntity.downloadingInstaller.emoji, '🟡');
      expect(LocalOllamaStatusEntity.installing.emoji, '🟡');
      expect(LocalOllamaStatusEntity.downloadingModel.emoji, '🟡');
      expect(LocalOllamaStatusEntity.starting.emoji, '🟡');
      expect(LocalOllamaStatusEntity.loading.emoji, '🟡');
      expect(LocalOllamaStatusEntity.ready.emoji, '🟢');
      expect(LocalOllamaStatusEntity.error.emoji, '🔴');
    });

    test('isUsable should return true only for ready status', () {
      expect(LocalOllamaStatusEntity.notInitialized.isUsable, false);
      expect(LocalOllamaStatusEntity.checkingInstallation.isUsable, false);
      expect(LocalOllamaStatusEntity.ready.isUsable, true);
      expect(LocalOllamaStatusEntity.error.isUsable, false);
    });

    test('isProcessing should return true for processing states', () {
      expect(LocalOllamaStatusEntity.checkingInstallation.isProcessing, true);
      expect(LocalOllamaStatusEntity.downloadingInstaller.isProcessing, true);
      expect(LocalOllamaStatusEntity.installing.isProcessing, true);
      expect(LocalOllamaStatusEntity.downloadingModel.isProcessing, true);
      expect(LocalOllamaStatusEntity.starting.isProcessing, true);
      expect(LocalOllamaStatusEntity.loading.isProcessing, true);
      expect(LocalOllamaStatusEntity.notInitialized.isProcessing, false);
      expect(LocalOllamaStatusEntity.ready.isProcessing, false);
      expect(LocalOllamaStatusEntity.error.isProcessing, false);
    });
  });

  group('OllamaInstallationInfoEntity', () {
    test('should create installation info', () {
      const info = OllamaInstallationInfoEntity(
        isInstalled: true,
        installPath: '/usr/local/bin/ollama',
        version: '0.1.0',
        canExecute: true,
      );

      expect(info.isInstalled, true);
      expect(info.installPath, '/usr/local/bin/ollama');
      expect(info.version, '0.1.0');
      expect(info.canExecute, true);
    });

    test('needsInstallation should return true when not installed', () {
      const info = OllamaInstallationInfoEntity(
        isInstalled: false,
        canExecute: false,
      );

      expect(info.needsInstallation, true);
    });

    test('needsInstallation should return true when cannot execute', () {
      const info = OllamaInstallationInfoEntity(
        isInstalled: true,
        canExecute: false,
      );

      expect(info.needsInstallation, true);
    });

    test('needsInstallation should return false when properly installed', () {
      const info = OllamaInstallationInfoEntity(
        isInstalled: true,
        canExecute: true,
      );

      expect(info.needsInstallation, false);
    });

    test('copyWith should work correctly', () {
      const original = OllamaInstallationInfoEntity(
        isInstalled: false,
        canExecute: false,
      );

      final copied = original.copyWith(
        isInstalled: true,
        installPath: '/usr/bin/ollama',
        canExecute: true,
      );

      expect(copied.isInstalled, true);
      expect(copied.installPath, '/usr/bin/ollama');
      expect(copied.canExecute, true);
    });
  });

  group('LocalOllamaInstallProgressEntity', () {
    test('should create progress entity', () {
      const progress = LocalOllamaInstallProgressEntity(
        status: LocalOllamaStatusEntity.downloadingModel,
        progress: 0.5,
        message: 'Downloading...',
        bytesDownloaded: 50000000,
        totalBytes: 100000000,
      );

      expect(progress.status, LocalOllamaStatusEntity.downloadingModel);
      expect(progress.progress, 0.5);
      expect(progress.message, 'Downloading...');
      expect(progress.bytesDownloaded, 50000000);
      expect(progress.totalBytes, 100000000);
    });

    test('progressText should format bytes correctly', () {
      const progress = LocalOllamaInstallProgressEntity(
        status: LocalOllamaStatusEntity.downloadingModel,
        progress: 0.5,
        bytesDownloaded: 52428800, // 50 MB
        totalBytes: 104857600, // 100 MB
      );

      final text = progress.progressText;

      expect(text, contains('50.0 MB'));
      expect(text, contains('100.0 MB'));
    });

    test('progressText should format percentage when bytes not available', () {
      const progress = LocalOllamaInstallProgressEntity(
        status: LocalOllamaStatusEntity.installing,
        progress: 0.75,
      );

      expect(progress.progressText, '75%');
    });

    test('copyWith should work correctly', () {
      const original = LocalOllamaInstallProgressEntity(
        status: LocalOllamaStatusEntity.downloadingModel,
        progress: 0.3,
      );

      final copied = original.copyWith(
        progress: 0.6,
        message: 'Almost done...',
      );

      expect(copied.status, LocalOllamaStatusEntity.downloadingModel);
      expect(copied.progress, 0.6);
      expect(copied.message, 'Almost done...');
    });
  });

  group('LocalOllamaInitResultEntity', () {
    test('should create successful result', () {
      const result = LocalOllamaInitResultEntity(
        success: true,
        modelName: 'phi3',
        availableModels: ['phi3', 'llama2'],
        initTime: Duration(seconds: 5),
        wasNewInstallation: false,
      );

      expect(result.success, true);
      expect(result.modelName, 'phi3');
      expect(result.availableModels, ['phi3', 'llama2']);
      expect(result.initTime, Duration(seconds: 5));
      expect(result.wasNewInstallation, false);
    });

    test('userMessage should format success message for existing installation', () {
      const result = LocalOllamaInitResultEntity(
        success: true,
        modelName: 'phi3',
        availableModels: ['phi3', 'llama2'],
        initTime: Duration(seconds: 5),
        wasNewInstallation: false,
      );

      final message = result.userMessage;

      expect(message, contains('✅ Conectado a Ollama local'));
      expect(message, contains('phi3'));
      expect(message, contains('2'));
      expect(message, contains('5s'));
    });

    test('userMessage should format success message for new installation', () {
      const result = LocalOllamaInitResultEntity(
        success: true,
        modelName: 'phi3',
        availableModels: ['phi3'],
        initTime: Duration(seconds: 10),
        wasNewInstallation: true,
      );

      final message = result.userMessage;

      expect(message, contains('✅ Ollama instalado correctamente'));
    });

    test('userMessage should format error message', () {
      const result = LocalOllamaInitResultEntity(
        success: false,
        error: 'Installation failed',
      );

      final message = result.userMessage;

      expect(message, contains('❌'));
      expect(message, contains('Installation failed'));
    });

    test('copyWith should work correctly', () {
      const original = LocalOllamaInitResultEntity(
        success: true,
        modelName: 'phi3',
      );

      final copied = original.copyWith(
        availableModels: ['phi3', 'llama2', 'mistral'],
        initTime: Duration(seconds: 8),
      );

      expect(copied.success, true);
      expect(copied.modelName, 'phi3');
      expect(copied.availableModels, ['phi3', 'llama2', 'mistral']);
      expect(copied.initTime, Duration(seconds: 8));
    });
  });

  group('LocalOllamaModelEntity', () {
    test('should create model entity', () {
      const model = LocalOllamaModelEntity(
        name: 'phi3:latest',
        displayName: 'Phi-3 Mini',
        description: 'Small but powerful',
        isDownloaded: true,
        estimatedSize: '2.3 GB',
        isRecommended: true,
        parametersB: 3,
      );

      expect(model.name, 'phi3:latest');
      expect(model.displayName, 'Phi-3 Mini');
      expect(model.description, 'Small but powerful');
      expect(model.isDownloaded, true);
      expect(model.estimatedSize, '2.3 GB');
      expect(model.isRecommended, true);
      expect(model.parametersB, 3);
    });

    test('copyWith should work correctly', () {
      const original = LocalOllamaModelEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: false,
        estimatedSize: '2.3 GB',
        parametersB: 3,
      );

      final copied = original.copyWith(
        isDownloaded: true,
        isRecommended: true,
      );

      expect(copied.name, 'phi3');
      expect(copied.isDownloaded, true);
      expect(copied.isRecommended, true);
    });

    test('equality should work correctly', () {
      const model1 = LocalOllamaModelEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: true,
        estimatedSize: '2.3 GB',
        parametersB: 3,
      );

      const model2 = LocalOllamaModelEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: true,
        estimatedSize: '2.3 GB',
        parametersB: 3,
      );

      expect(model1, model2);
    });

    test('hashCode should be consistent', () {
      const model1 = LocalOllamaModelEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: true,
        estimatedSize: '2.3 GB',
        parametersB: 3,
      );

      const model2 = LocalOllamaModelEntity(
        name: 'phi3',
        displayName: 'Phi-3',
        description: 'Test',
        isDownloaded: true,
        estimatedSize: '2.3 GB',
        parametersB: 3,
      );

      expect(model1.hashCode, model2.hashCode);
    });
  });

  group('LocalOllamaConfigEntity', () {
    test('should create config with default values', () {
      const config = LocalOllamaConfigEntity();

      expect(config.baseUrl, 'http://localhost');
      expect(config.port, 11434);
      expect(config.temperature, 0.7);
      expect(config.maxTokens, 2048);
      expect(config.timeout, Duration(seconds: 60));
    });

    test('should create config with custom values', () {
      const config = LocalOllamaConfigEntity(
        baseUrl: 'http://192.168.1.100',
        port: 8080,
        temperature: 0.9,
        maxTokens: 4096,
        timeout: Duration(seconds: 120),
      );

      expect(config.baseUrl, 'http://192.168.1.100');
      expect(config.port, 8080);
      expect(config.temperature, 0.9);
      expect(config.maxTokens, 4096);
      expect(config.timeout, Duration(seconds: 120));
    });

    test('fullBaseUrl should combine baseUrl and port', () {
      const config = LocalOllamaConfigEntity(
        baseUrl: 'http://localhost',
        port: 11434,
      );

      expect(config.fullBaseUrl, 'http://localhost:11434');
    });

    test('copyWith should work correctly', () {
      const original = LocalOllamaConfigEntity();

      final copied = original.copyWith(
        port: 8080,
        temperature: 0.9,
      );

      expect(copied.baseUrl, 'http://localhost');
      expect(copied.port, 8080);
      expect(copied.temperature, 0.9);
    });
  });
}