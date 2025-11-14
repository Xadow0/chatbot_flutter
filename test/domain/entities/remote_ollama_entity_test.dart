import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_app/domain/entities/remote_ollama_entity.dart';

void main() {
  group('OllamaModelEntity', () {
    final testDate = DateTime(2024, 1, 1, 12, 0, 0);

    test('should create a model entity', () {
      final model = OllamaModelEntity(
        name: 'phi3:latest',
        size: 2400000000,
        digest: 'sha256:abc123',
        modifiedAt: testDate,
      );

      expect(model.name, 'phi3:latest');
      expect(model.size, 2400000000);
      expect(model.digest, 'sha256:abc123');
      expect(model.modifiedAt, testDate);
    });

    test('sizeFormatted should format GB correctly', () {
      final model = OllamaModelEntity(
        name: 'phi3',
        size: 2400000000, // ~2.24 GB
        digest: 'abc',
        modifiedAt: testDate,
      );

      expect(model.sizeFormatted, contains('2.2'));
      expect(model.sizeFormatted, contains('GB'));
    });

    test('sizeFormatted should handle zero size', () {
      final model = OllamaModelEntity(
        name: 'phi3',
        size: 0,
        digest: 'abc',
        modifiedAt: testDate,
      );

      expect(model.sizeFormatted, 'Unknown');
    });

    test('displayName should remove :latest tag', () {
      final model = OllamaModelEntity(
        name: 'phi3:latest',
        size: 1000000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      expect(model.displayName, 'phi3');
    });

    test('displayName should keep name without :latest', () {
      final model = OllamaModelEntity(
        name: 'llama2:13b',
        size: 1000000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      expect(model.displayName, 'llama2:13b');
    });

    test('copyWith should work correctly', () {
      final original = OllamaModelEntity(
        name: 'phi3',
        size: 1000000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      final copied = original.copyWith(
        name: 'llama2',
        size: 2000000000,
      );

      expect(copied.name, 'llama2');
      expect(copied.size, 2000000000);
      expect(copied.digest, 'abc');
      expect(copied.modifiedAt, testDate);
    });

    test('equality should work correctly', () {
      final model1 = OllamaModelEntity(
        name: 'phi3',
        size: 1000000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      final model2 = OllamaModelEntity(
        name: 'phi3',
        size: 1000000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      final model3 = OllamaModelEntity(
        name: 'llama2',
        size: 1000000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      expect(model1, model2);
      expect(model1, isNot(model3));
    });

    test('hashCode should be consistent', () {
      final model1 = OllamaModelEntity(
        name: 'phi3',
        size: 1000000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      final model2 = OllamaModelEntity(
        name: 'phi3',
        size: 1000000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      expect(model1.hashCode, model2.hashCode);
    });

    test('toString should format correctly', () {
      final model = OllamaModelEntity(
        name: 'phi3',
        size: 2400000000,
        digest: 'abc',
        modifiedAt: testDate,
      );

      final result = model.toString();

      expect(result, contains('OllamaModelEntity'));
      expect(result, contains('phi3'));
      expect(result, contains('GB'));
    });
  });

  group('ConnectionInfoEntity', () {
    test('should create connection info', () {
      const info = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connected,
        url: 'http://100.64.0.1:11434',
        isHealthy: true,
      );

      expect(info.status, ConnectionStatusEntity.connected);
      expect(info.url, 'http://100.64.0.1:11434');
      expect(info.isHealthy, true);
      expect(info.errorMessage, isNull);
      expect(info.healthData, isNull);
    });

    test('statusText should return correct text for connected', () {
      const info = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connected,
        url: 'http://localhost:11434',
        isHealthy: true,
      );

      expect(info.statusText, '🟢 Conectado');
    });

    test('statusText should return correct text for connecting', () {
      const info = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connecting,
        url: 'http://localhost:11434',
        isHealthy: false,
      );

      expect(info.statusText, '🟡 Conectando...');
    });

    test('statusText should return correct text for disconnected', () {
      const info = ConnectionInfoEntity(
        status: ConnectionStatusEntity.disconnected,
        url: 'http://localhost:11434',
        isHealthy: false,
      );

      expect(info.statusText, '🔴 Desconectado');
    });

    test('statusText should return correct text for error', () {
      const info = ConnectionInfoEntity(
        status: ConnectionStatusEntity.error,
        url: 'http://localhost:11434',
        isHealthy: false,
        errorMessage: 'Connection timeout',
      );

      expect(info.statusText, '❌ Error');
    });

    test('urlForDisplay should truncate long URLs', () {
      const longUrl = 'http://very-long-hostname-that-exceeds-forty-characters.com:11434/api/generate';
      const info = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connected,
        url: longUrl,
        isHealthy: true,
      );

      final displayUrl = info.urlForDisplay;

      expect(displayUrl.length, lessThan(longUrl.length));
      expect(displayUrl, contains('...'));
    });

    test('urlForDisplay should not truncate short URLs', () {
      const shortUrl = 'http://localhost:11434';
      const info = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connected,
        url: shortUrl,
        isHealthy: true,
      );

      expect(info.urlForDisplay, shortUrl);
    });

    test('copyWith should work correctly', () {
      const original = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connecting,
        url: 'http://localhost:11434',
        isHealthy: false,
      );

      final copied = original.copyWith(
        status: ConnectionStatusEntity.connected,
        isHealthy: true,
      );

      expect(copied.status, ConnectionStatusEntity.connected);
      expect(copied.url, 'http://localhost:11434');
      expect(copied.isHealthy, true);
    });

    test('equality should work correctly', () {
      const info1 = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connected,
        url: 'http://localhost:11434',
        isHealthy: true,
      );

      const info2 = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connected,
        url: 'http://localhost:11434',
        isHealthy: true,
      );

      const info3 = ConnectionInfoEntity(
        status: ConnectionStatusEntity.disconnected,
        url: 'http://localhost:11434',
        isHealthy: false,
      );

      expect(info1, info2);
      expect(info1, isNot(info3));
    });

    test('hashCode should be consistent', () {
      const info1 = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connected,
        url: 'http://localhost:11434',
        isHealthy: true,
      );

      const info2 = ConnectionInfoEntity(
        status: ConnectionStatusEntity.connected,
        url: 'http://localhost:11434',
        isHealthy: true,
      );

      expect(info1.hashCode, info2.hashCode);
    });
  });

  group('ConnectionStatusEntity', () {
    test('should have all status values', () {
      expect(ConnectionStatusEntity.connected, isNotNull);
      expect(ConnectionStatusEntity.connecting, isNotNull);
      expect(ConnectionStatusEntity.disconnected, isNotNull);
      expect(ConnectionStatusEntity.error, isNotNull);
    });
  });

  group('OllamaHealthEntity', () {
    test('should create health entity', () {
      const health = OllamaHealthEntity(
        success: true,
        status: 'healthy',
        ollamaAvailable: true,
        modelCount: 3,
        tailscaleIP: '100.64.0.1',
      );

      expect(health.success, true);
      expect(health.status, 'healthy');
      expect(health.ollamaAvailable, true);
      expect(health.modelCount, 3);
      expect(health.tailscaleIP, '100.64.0.1');
    });

    test('copyWith should work correctly', () {
      const original = OllamaHealthEntity(
        success: true,
        status: 'healthy',
        ollamaAvailable: true,
        modelCount: 2,
      );

      final copied = original.copyWith(
        modelCount: 3,
        tailscaleIP: '100.64.0.1',
      );

      expect(copied.success, true);
      expect(copied.status, 'healthy');
      expect(copied.modelCount, 3);
      expect(copied.tailscaleIP, '100.64.0.1');
    });

    test('equality should work correctly', () {
      const health1 = OllamaHealthEntity(
        success: true,
        status: 'healthy',
        ollamaAvailable: true,
        modelCount: 3,
      );

      const health2 = OllamaHealthEntity(
        success: true,
        status: 'healthy',
        ollamaAvailable: true,
        modelCount: 3,
      );

      const health3 = OllamaHealthEntity(
        success: false,
        status: 'unhealthy',
        ollamaAvailable: false,
        modelCount: 0,
      );

      expect(health1, health2);
      expect(health1, isNot(health3));
    });

    test('hashCode should be consistent', () {
      const health1 = OllamaHealthEntity(
        success: true,
        status: 'healthy',
        ollamaAvailable: true,
        modelCount: 3,
      );

      const health2 = OllamaHealthEntity(
        success: true,
        status: 'healthy',
        ollamaAvailable: true,
        modelCount: 3,
      );

      expect(health1.hashCode, health2.hashCode);
    });
  });
}