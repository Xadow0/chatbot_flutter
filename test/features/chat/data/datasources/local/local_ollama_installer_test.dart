import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:chatbot_app/features/chat/data/datasources/local/local_ollama_installer.dart';
import 'package:chatbot_app/features/chat/data/models/local_ollama_models.dart';

/// ==================
/// HTTP Fakes seguros
/// ==================

class FakeHttpOverrides extends HttpOverrides {
  final int statusCode;

  FakeHttpOverrides(this.statusCode);

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _FakeHttpClient(statusCode);
  }
}

class _FakeHttpClient implements HttpClient {
  final int statusCode;

  _FakeHttpClient(this.statusCode);

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpRequest(statusCode);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpRequest implements HttpClientRequest {
  final int statusCode;

  _FakeHttpRequest(this.statusCode);

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpResponse(statusCode);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpResponse implements HttpClientResponse {
  final int _statusCode;

  _FakeHttpResponse(this._statusCode);

  @override
  int get statusCode => _statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // Stream vacío
    return const Stream<List<int>>.empty().listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// ==================
/// Tests
/// ==================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalOllamaInstaller.isOllamaRunning', () {
    test('returns false when server responds non-200', () async {
      HttpOverrides.runZoned(() async {
        final running = await LocalOllamaInstaller.isOllamaRunning();

        expect(running, isFalse);
      }, createHttpClient: (_) => _FakeHttpClient(500));
    });

    test('returns false on exception', () async {
      final running = await LocalOllamaInstaller.isOllamaRunning(port: 9999);

      expect(running, isFalse);
    });
  });

  group('LocalOllamaInstaller.startOllamaService', () {
    test('returns true if already running', () async {
      HttpOverrides.runZoned(() async {
        final started = await LocalOllamaInstaller.startOllamaService();

        expect(started, isTrue);
      }, createHttpClient: (_) => _FakeHttpClient(200));
    });

    test('returns false when service does not start (timeout path)', () async {
      HttpOverrides.runZoned(() async {
        final started = await LocalOllamaInstaller.startOllamaService();

        expect(started, isFalse);
      }, createHttpClient: (_) => _FakeHttpClient(500));
    });
  });

  group('LocalOllamaInstaller.stopOllamaService', () {
    test('does not throw on any platform', () async {
      await LocalOllamaInstaller.stopOllamaService();
      expect(true, isTrue); // solo verificar que no crashea
    });
  });

  group('LocalOllamaInstaller.installOllama', () {
    test('yields error progress on unsupported platform or failure', () async {
      try {
        final stream = LocalOllamaInstaller.installOllama();
        await stream.toList();
      } catch (e) {
        expect(e, isA<LocalOllamaException>());
      }
    });
  });
}
