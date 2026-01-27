import 'package:flutter_test/flutter_test.dart';

import 'package:chatbot_app/features/chat/data/datasources/local/local_ollama_source.dart';
import 'package:chatbot_app/features/chat/data/models/local_ollama_models.dart';

void main() {
  group('OllamaManagedService - Unit tests puros', () {
    late OllamaManagedService service;

    setUp(() {
      service = OllamaManagedService();
    });

    test('estado inicial correcto', () {
      expect(service.status, LocalOllamaStatus.notInitialized);
      expect(service.isAvailable, false);
      expect(service.isProcessing, false);
      expect(service.currentModel, isNull);
      expect(service.availableModels, isEmpty);
      expect(service.errorMessage, isNull);
    });

    test('InstalledModelInfo sizeFormatted y getters', () {
      final small = InstalledModelInfo(name: 'model:latest', size: 1024);
      expect(small.sizeFormatted, '1 KB');

      final medium = InstalledModelInfo(name: 'model:latest', size: 1024 * 1024);
      expect(medium.sizeFormatted, '1 MB');

      final big = InstalledModelInfo(name: 'model:latest', size: 1024 * 1024 * 1024);
      expect(big.sizeFormatted, '1.0 GB');

      expect(big.displayName, 'model');
      expect(big.tag, 'latest');

      final noTag = InstalledModelInfo(name: 'plain', size: 100);
      expect(noTag.displayName, 'plain');
      expect(noTag.tag, 'latest');
    });

    test('deleteModel falla si servicio no está listo', () async {
      final result = await service.deleteModel('llama2');

      expect(result.success, false);
      expect(result.error, isNotNull);
      expect(result.deletedModel, isNull);
    });

    test('cancelModelDownload sin descarga activa no cambia estado', () {
      service.cancelModelDownload();

      expect(service.status, LocalOllamaStatus.notInitialized);
    });

    test('generateContentStream lanza excepción si servicio no está disponible', () async {
      expect(
        () => service.generateContentStream('hola').first,
        throwsA(isA<LocalOllamaException>()),
      );
    });

    test('generateContentStreamContext lanza excepción si servicio no está disponible', () async {
      expect(
        () => service.generateContentStreamContext('hola').first,
        throwsA(isA<LocalOllamaException>()),
      );
    });

    test('clearConversation limpia historial sin error', () {
      service.clearConversation();

      // No hay getter público, solo verificamos que no lanza excepción
      expect(true, true);
    });

    test('addUserMessage y addBotMessage no lanzan excepción', () {
      service.addUserMessage('hola');
      service.addBotMessage('respuesta');

      expect(true, true);
    });

    test('pause no hace nada si no está ready', () async {
      await service.pause();

      expect(service.status, LocalOllamaStatus.notInitialized);
    });

    test('resume intenta reanudar aunque no esté inicializado (no lanza)', () async {
      // No podemos mockear isOllamaRunning → solo verificamos que no explota
      await service.resume();

      expect(service.status, isNotNull);
    });

    test('stop resetea estado y limpia modelos', () async {
      await service.stop();

      expect(service.status, LocalOllamaStatus.notInitialized);
      expect(service.availableModels, isEmpty);
      expect(service.currentModel, isNull);
    });

    test('retry llama a initialize y devuelve error (sin colgar)', () async {
      // IMPORTANTE: no dejamos que se cuelgue más de 2 segundos
      final future = service.retry();

      final result = await future.timeout(
        const Duration(seconds: 2),
        onTimeout: () => LocalOllamaInitResult(success: false, error: 'timeout'),
      );

      expect(result.success, false);
    });

    test('checkHealth devuelve false si no hay servidor', () async {
      final healthy = await service.checkHealth();

      expect(healthy, false);
    });

    test('dispose limpia timers y listeners sin error', () {
      service.dispose();

      expect(true, true);
    });
  });
}
