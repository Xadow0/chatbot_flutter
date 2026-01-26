import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// =============================================================================
// STUBS Y ENUMS
// =============================================================================

enum AIProvider {
  gemini,
  ollama,
  openai,
  localOllama,
}

enum ConnectionStatus {
  disconnected,
  connecting,
  connected,
  error,
}

enum LocalOllamaStatus {
  notInitialized,
  initializing,
  downloadingModel,
  loadingModel,
  ready,
  error,
  stopping,
}

extension LocalOllamaStatusX on LocalOllamaStatus {
  bool get isProcessing =>
      this == LocalOllamaStatus.initializing ||
      this == LocalOllamaStatus.downloadingModel ||
      this == LocalOllamaStatus.loadingModel ||
      this == LocalOllamaStatus.stopping;

  String get displayText {
    switch (this) {
      case LocalOllamaStatus.notInitialized:
        return 'No inicializado';
      case LocalOllamaStatus.initializing:
        return 'Inicializando...';
      case LocalOllamaStatus.downloadingModel:
        return 'Descargando modelo...';
      case LocalOllamaStatus.loadingModel:
        return 'Cargando modelo...';
      case LocalOllamaStatus.ready:
        return 'Listo';
      case LocalOllamaStatus.error:
        return 'Error';
      case LocalOllamaStatus.stopping:
        return 'Deteniendo...';
    }
  }
}

class OllamaModel {
  final String name;
  final String? digest;
  final int? size;

  OllamaModel({
    required this.name,
    this.digest,
    this.size,
  });
}

class ConnectionInfo {
  final ConnectionStatus status;
  final String? url;
  final String? error;

  ConnectionInfo({
    required this.status,
    this.url,
    this.error,
  });

  factory ConnectionInfo.disconnected() =>
      ConnectionInfo(status: ConnectionStatus.disconnected);

  factory ConnectionInfo.connected(String url) =>
      ConnectionInfo(status: ConnectionStatus.connected, url: url);

  factory ConnectionInfo.error(String error) =>
      ConnectionInfo(status: ConnectionStatus.error, error: error);
}

class HealthCheckResult {
  final bool success;
  final bool ollamaAvailable;

  HealthCheckResult({required this.success, required this.ollamaAvailable});
}

class LocalOllamaInitResult {
  final bool success;
  final String? modelName;
  final List<String>? availableModels;
  final String? error;

  LocalOllamaInitResult({
    required this.success,
    this.modelName,
    this.availableModels,
    this.error,
  });

  factory LocalOllamaInitResult.success(String model, List<String> models) =>
      LocalOllamaInitResult(
        success: true,
        modelName: model,
        availableModels: models,
      );

  factory LocalOllamaInitResult.failure(String error) =>
      LocalOllamaInitResult(success: false, error: error);
}

// =============================================================================
// INTERFACES DE SERVICIOS
// =============================================================================

abstract class GeminiService {
  Stream<String> streamMessage(String message, List<Map<String, dynamic>> history);
}

abstract class OllamaService {
  Stream<ConnectionInfo> get connectionStream;
  ConnectionInfo get connectionInfo;
  Future<HealthCheckResult> checkHealth();
  Future<List<OllamaModel>> getModels();
  Future<void> reconnect();
  void dispose();
}

abstract class OpenAIService {
  static const List<String> availableModels = [
    'gpt-4o',
    'gpt-4o-mini',
    'gpt-4-turbo',
    'gpt-3.5-turbo',
  ];

  Future<bool> isAvailable();
}

abstract class OllamaManagedService {
  bool get isPlatformSupported;
  String? get errorMessage;
  void addStatusListener(void Function(LocalOllamaStatus) listener);
  void removeStatusListener(void Function(LocalOllamaStatus) listener);
  Future<LocalOllamaInitResult> initialize();
  Future<void> stop();
  Future<LocalOllamaInitResult> retry();
  Future<bool> changeModel(String modelName);
  void dispose();
}

// =============================================================================
// INTERFACES DE ADAPTADORES
// =============================================================================

abstract class AIServiceBase {
  Stream<String> generateContentStream(String prompt);
  Stream<String> generateContentStreamWithoutHistory(String prompt);
}

class GeminiServiceAdapter implements AIServiceBase {
  final GeminiService _service;
  GeminiServiceAdapter(this._service);

  @override
  Stream<String> generateContentStream(String prompt) =>
      _service.streamMessage(prompt, []);

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) =>
      _service.streamMessage(prompt, []);
}

class OpenAIServiceAdapter implements AIServiceBase {
  final OpenAIService _service;
  OpenAIServiceAdapter(this._service);

  @override
  Stream<String> generateContentStream(String prompt) =>
      Stream.fromIterable(['response']);

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) =>
      Stream.fromIterable(['response']);
}

class OllamaServiceAdapter implements AIServiceBase {
  final OllamaService _service;
  final String _model;
  OllamaServiceAdapter(this._service, this._model);

  @override
  Stream<String> generateContentStream(String prompt) =>
      Stream.fromIterable(['response']);

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) =>
      Stream.fromIterable(['response']);
}

class LocalOllamaServiceAdapter implements AIServiceBase {
  final OllamaManagedService _service;
  LocalOllamaServiceAdapter(this._service);

  @override
  Stream<String> generateContentStream(String prompt) =>
      Stream.fromIterable(['response']);

  @override
  Stream<String> generateContentStreamWithoutHistory(String prompt) =>
      Stream.fromIterable(['response']);
}

// =============================================================================
// CÓDIGO BAJO PRUEBA
// =============================================================================

class AIServiceSelector extends ChangeNotifier {
  final GeminiService _geminiService;
  final OllamaService _ollamaService;
  final OpenAIService _openaiService;
  final OllamaManagedService _localOllamaService;

  AIProvider _currentProvider = AIProvider.gemini;
  String _currentOllamaModel = 'phi3:latest';
  String _currentOpenAIModel = 'gpt-4o-mini';
  List<OllamaModel> _availableModels = [];
  bool _ollamaAvailable = false;
  bool get isLocalOllamaSupported => _localOllamaService.isPlatformSupported;

  bool _openaiAvailable = false;

  StreamSubscription? _ollamaConnectionSubscription;

  LocalOllamaStatus _localOllamaStatus = LocalOllamaStatus.notInitialized;

  AIServiceSelector({
    required GeminiService geminiService,
    required OllamaService ollamaService,
    required OpenAIService openaiService,
    required OllamaManagedService localOllamaService,
  })  : _geminiService = geminiService,
        _ollamaService = ollamaService,
        _openaiService = openaiService,
        _localOllamaService = localOllamaService {
    _ollamaConnectionSubscription =
        _ollamaService.connectionStream.listen(_onOllamaConnectionChanged);

    _localOllamaService.addStatusListener(_onLocalOllamaStatusChanged);

    _initializeOpenAI();

    _onOllamaConnectionChanged(_ollamaService.connectionInfo);
  }

  AIProvider get currentProvider => _currentProvider;
  String get currentOllamaModel => _currentOllamaModel;
  String get currentOpenAIModel => _currentOpenAIModel;
  List<OllamaModel> get availableModels => _availableModels;
  List<String> get availableOpenAIModels => OpenAIService.availableModels;
  bool get ollamaAvailable => _ollamaAvailable;

  bool get openaiAvailable => _openaiAvailable;

  OllamaService get ollamaService => _ollamaService;
  OpenAIService get openaiService => _openaiService;
  ConnectionInfo get connectionInfo => _ollamaService.connectionInfo;

  GeminiService get geminiService => _geminiService;
  OllamaManagedService get localOllamaService => _localOllamaService;
  LocalOllamaStatus get localOllamaStatus => _localOllamaStatus;
  bool get localOllamaAvailable =>
      _localOllamaStatus == LocalOllamaStatus.ready;
  bool get localOllamaLoading => _localOllamaStatus.isProcessing;
  String? get localOllamaError => _localOllamaService.errorMessage;

  Stream<ConnectionInfo> get connectionStream => _ollamaService.connectionStream;

  void _onLocalOllamaStatusChanged(LocalOllamaStatus status) {
    _localOllamaStatus = status;
    notifyListeners();
  }

  Future<void> refreshOpenAIAvailability() async {
    try {
      _openaiAvailable = await _openaiService.isAvailable();
      notifyListeners();
    } catch (e) {
      _openaiAvailable = false;
      notifyListeners();
    }
  }

  Future<void> refreshOllama() async {
    try {
      await _ollamaService.reconnect();
    } catch (e) {
      // Error handling
    }
  }

  Future<void> _onOllamaConnectionChanged(ConnectionInfo info) async {
    if (info.status == ConnectionStatus.connected) {
      final wasAvailable = _ollamaAvailable;
      _ollamaAvailable = true;

      if (!wasAvailable) {
        await _loadAvailableModels();
      }
    } else {
      _ollamaAvailable = false;
      _availableModels = [];
    }

    notifyListeners();
  }

  Future<void> _initializeOpenAI() async {
    try {
      _openaiAvailable = await _openaiService.isAvailable();
    } catch (e) {
      _openaiAvailable = false;
    }
  }

  Future<LocalOllamaInitResult> initializeLocalOllama() async {
    final result = await _localOllamaService.initialize();
    notifyListeners();
    return result;
  }

  Future<void> stopLocalOllama() async {
    if (_currentProvider == AIProvider.localOllama) {
      await setProvider(AIProvider.gemini);
    }

    await _localOllamaService.stop();
    notifyListeners();
  }

  Future<LocalOllamaInitResult> retryLocalOllama() async {
    return await _localOllamaService.retry();
  }

  Future<void> _loadAvailableModels() async {
    try {
      _availableModels = await _ollamaService.getModels();

      if (_availableModels.isNotEmpty) {
        final modelExists =
            _availableModels.any((m) => m.name == _currentOllamaModel);
        if (!modelExists) {
          _currentOllamaModel = _availableModels.first.name;
        }
      }
    } catch (e) {
      _availableModels = [];
    }
  }

  Future<void> setProvider(AIProvider provider) async {
    if (provider == AIProvider.ollama && !_ollamaAvailable) {
      throw Exception('Ollama remoto no está disponible');
    }

    if (provider == AIProvider.openai && !_openaiAvailable) {
      throw Exception('OpenAI no está disponible. Configure su API Key en Ajustes');
    }

    if (provider == AIProvider.localOllama) {
      if (!isLocalOllamaSupported) {
        throw Exception('Ollama Local no está disponible en este dispositivo.');
      }
      if (!localOllamaAvailable) {
        throw Exception('Ollama Local no está listo. Inicialízalo primero.');
      }
    }

    _currentProvider = provider;
    notifyListeners();
  }

  Future<void> setOllamaModel(String modelName) async {
    if (!_availableModels.any((m) => m.name == modelName)) {
      throw Exception('Modelo $modelName no está disponible');
    }

    _currentOllamaModel = modelName;
    notifyListeners();
  }

  Future<void> setOpenAIModel(String modelName) async {
    if (!OpenAIService.availableModels.contains(modelName)) {
      throw Exception('Modelo $modelName no está disponible');
    }

    _currentOpenAIModel = modelName;
    notifyListeners();
  }

  Future<bool> setLocalOllamaModel(String modelName) async {
    final success = await _localOllamaService.changeModel(modelName);
    return success;
  }

  @override
  void dispose() {
    _ollamaConnectionSubscription?.cancel();
    _localOllamaService.removeStatusListener(_onLocalOllamaStatusChanged);
    _localOllamaService.dispose();
    _ollamaService.dispose();
    super.dispose();
  }

  AIServiceBase getCurrentAdapter() {
    switch (_currentProvider) {
      case AIProvider.gemini:
        return GeminiServiceAdapter(_geminiService);
      case AIProvider.openai:
        return OpenAIServiceAdapter(_openaiService);
      case AIProvider.ollama:
        return OllamaServiceAdapter(_ollamaService, _currentOllamaModel);
      case AIProvider.localOllama:
        return LocalOllamaServiceAdapter(_localOllamaService);
    }
  }
}

// =============================================================================
// MOCKS
// =============================================================================

class MockGeminiService extends Mock implements GeminiService {}

class MockOllamaService extends Mock implements OllamaService {}

class MockOpenAIService extends Mock implements OpenAIService {}

class MockOllamaManagedService extends Mock implements OllamaManagedService {}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // AIProvider Tests
  // ---------------------------------------------------------------------------
  group('AIProvider', () {
    test('contiene todos los valores esperados', () {
      expect(AIProvider.values.length, equals(4));
      expect(AIProvider.values, contains(AIProvider.gemini));
      expect(AIProvider.values, contains(AIProvider.ollama));
      expect(AIProvider.values, contains(AIProvider.openai));
      expect(AIProvider.values, contains(AIProvider.localOllama));
    });

    test('gemini es el primer valor (índice 0)', () {
      expect(AIProvider.gemini.index, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // LocalOllamaStatus Tests
  // ---------------------------------------------------------------------------
  group('LocalOllamaStatus', () {
    test('contiene todos los valores esperados', () {
      expect(LocalOllamaStatus.values.length, equals(7));
    });

    test('isProcessing retorna true para estados de procesamiento', () {
      expect(LocalOllamaStatus.initializing.isProcessing, isTrue);
      expect(LocalOllamaStatus.downloadingModel.isProcessing, isTrue);
      expect(LocalOllamaStatus.loadingModel.isProcessing, isTrue);
      expect(LocalOllamaStatus.stopping.isProcessing, isTrue);
    });

    test('isProcessing retorna false para estados estables', () {
      expect(LocalOllamaStatus.notInitialized.isProcessing, isFalse);
      expect(LocalOllamaStatus.ready.isProcessing, isFalse);
      expect(LocalOllamaStatus.error.isProcessing, isFalse);
    });

    test('displayText retorna texto correcto', () {
      expect(LocalOllamaStatus.notInitialized.displayText, equals('No inicializado'));
      expect(LocalOllamaStatus.ready.displayText, equals('Listo'));
      expect(LocalOllamaStatus.error.displayText, equals('Error'));
    });
  });

  // ---------------------------------------------------------------------------
  // AIServiceSelector Tests
  // ---------------------------------------------------------------------------
  group('AIServiceSelector', () {
    late MockGeminiService mockGemini;
    late MockOllamaService mockOllama;
    late MockOpenAIService mockOpenAI;
    late MockOllamaManagedService mockLocalOllama;
    late StreamController<ConnectionInfo> connectionStreamController;
    late AIServiceSelector selector;

    setUp(() {
      mockGemini = MockGeminiService();
      mockOllama = MockOllamaService();
      mockOpenAI = MockOpenAIService();
      mockLocalOllama = MockOllamaManagedService();
      connectionStreamController = StreamController<ConnectionInfo>.broadcast();

      // Setup básico de mocks
      when(() => mockOllama.connectionStream)
          .thenAnswer((_) => connectionStreamController.stream);
      when(() => mockOllama.connectionInfo)
          .thenReturn(ConnectionInfo.disconnected());
      when(() => mockOpenAI.isAvailable()).thenAnswer((_) async => false);
      when(() => mockLocalOllama.isPlatformSupported).thenReturn(true);
      when(() => mockLocalOllama.errorMessage).thenReturn(null);
      when(() => mockLocalOllama.addStatusListener(any())).thenReturn(null);
      when(() => mockLocalOllama.removeStatusListener(any())).thenReturn(null);
    });

    tearDown(() {
      connectionStreamController.close();
    });

    AIServiceSelector createSelector() {
      return AIServiceSelector(
        geminiService: mockGemini,
        ollamaService: mockOllama,
        openaiService: mockOpenAI,
        localOllamaService: mockLocalOllama,
      );
    }

    // -------------------------------------------------------------------------
    // Constructor y estado inicial
    // -------------------------------------------------------------------------
    group('constructor y estado inicial', () {
      test('inicializa con valores por defecto correctos', () {
        selector = createSelector();

        expect(selector.currentProvider, equals(AIProvider.gemini));
        expect(selector.currentOllamaModel, equals('phi3:latest'));
        expect(selector.currentOpenAIModel, equals('gpt-4o-mini'));
        expect(selector.availableModels, isEmpty);
        expect(selector.ollamaAvailable, isFalse);
        expect(selector.localOllamaStatus, equals(LocalOllamaStatus.notInitialized));
      });

      test('suscribe a connectionStream de Ollama', () {
        selector = createSelector();

        verify(() => mockOllama.connectionStream).called(1);
      });

      test('añade status listener a localOllama', () {
        selector = createSelector();

        verify(() => mockLocalOllama.addStatusListener(any())).called(1);
      });

      test('inicializa OpenAI al crear', () async {
        when(() => mockOpenAI.isAvailable()).thenAnswer((_) async => true);

        selector = createSelector();

        // Esperar a que se complete la inicialización asíncrona
        await Future.delayed(Duration.zero);

        expect(selector.openaiAvailable, isTrue);
      });

      test('procesa connectionInfo inicial de Ollama', () {
        when(() => mockOllama.connectionInfo)
            .thenReturn(ConnectionInfo.connected('http://localhost:11434'));
        when(() => mockOllama.getModels()).thenAnswer((_) async => []);

        selector = createSelector();

        // Debería marcar ollama como disponible
        expect(selector.ollamaAvailable, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // Getters
    // -------------------------------------------------------------------------
    group('getters', () {
      setUp(() {
        selector = createSelector();
      });

      test('geminiService retorna el servicio inyectado', () {
        expect(selector.geminiService, equals(mockGemini));
      });

      test('ollamaService retorna el servicio inyectado', () {
        expect(selector.ollamaService, equals(mockOllama));
      });

      test('openaiService retorna el servicio inyectado', () {
        expect(selector.openaiService, equals(mockOpenAI));
      });

      test('localOllamaService retorna el servicio inyectado', () {
        expect(selector.localOllamaService, equals(mockLocalOllama));
      });

      test('connectionInfo retorna info del servicio Ollama', () {
        final info = ConnectionInfo.connected('http://test');
        when(() => mockOllama.connectionInfo).thenReturn(info);

        expect(selector.connectionInfo, equals(info));
      });

      test('connectionStream retorna stream del servicio Ollama', () {
        expect(selector.connectionStream, equals(connectionStreamController.stream));
      });

      test('availableOpenAIModels retorna lista estática', () {
        expect(selector.availableOpenAIModels, contains('gpt-4o'));
        expect(selector.availableOpenAIModels, contains('gpt-4o-mini'));
      });

      test('isLocalOllamaSupported delega a localOllamaService', () {
        when(() => mockLocalOllama.isPlatformSupported).thenReturn(true);
        expect(selector.isLocalOllamaSupported, isTrue);

        when(() => mockLocalOllama.isPlatformSupported).thenReturn(false);
        selector = createSelector();
        expect(selector.isLocalOllamaSupported, isFalse);
      });

      test('localOllamaError delega a localOllamaService', () {
        when(() => mockLocalOllama.errorMessage).thenReturn('Test error');

        expect(selector.localOllamaError, equals('Test error'));
      });

      test('localOllamaAvailable es true solo cuando status es ready', () {
        expect(selector.localOllamaAvailable, isFalse);
      });

      test('localOllamaLoading es true durante estados de procesamiento', () {
        expect(selector.localOllamaLoading, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // setProvider
    // -------------------------------------------------------------------------
    group('setProvider', () {
      setUp(() {
        selector = createSelector();
      });

      test('cambia a Gemini exitosamente', () async {
        await selector.setProvider(AIProvider.gemini);

        expect(selector.currentProvider, equals(AIProvider.gemini));
      });

      test('lanza excepción al cambiar a Ollama si no disponible', () async {
        expect(
          () => selector.setProvider(AIProvider.ollama),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Ollama remoto no está disponible'),
          )),
        );
      });

      test('cambia a Ollama exitosamente si disponible', () async {
        // Simular Ollama disponible
        when(() => mockOllama.connectionInfo)
            .thenReturn(ConnectionInfo.connected('http://localhost'));
        when(() => mockOllama.getModels()).thenAnswer((_) async => []);

        selector = createSelector();
        await Future.delayed(Duration.zero);

        await selector.setProvider(AIProvider.ollama);

        expect(selector.currentProvider, equals(AIProvider.ollama));
      });

      test('lanza excepción al cambiar a OpenAI si no disponible', () async {
        expect(
          () => selector.setProvider(AIProvider.openai),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('OpenAI no está disponible'),
          )),
        );
      });

      test('cambia a OpenAI exitosamente si disponible', () async {
        when(() => mockOpenAI.isAvailable()).thenAnswer((_) async => true);

        selector = createSelector();
        await Future.delayed(Duration.zero);

        await selector.setProvider(AIProvider.openai);

        expect(selector.currentProvider, equals(AIProvider.openai));
      });

      test('lanza excepción al cambiar a LocalOllama si no soportado', () async {
        when(() => mockLocalOllama.isPlatformSupported).thenReturn(false);

        selector = createSelector();

        expect(
          () => selector.setProvider(AIProvider.localOllama),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('no está disponible en este dispositivo'),
          )),
        );
      });

      test('lanza excepción al cambiar a LocalOllama si no está listo', () async {
        expect(
          () => selector.setProvider(AIProvider.localOllama),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('no está listo'),
          )),
        );
      });

      test('notifica listeners al cambiar proveedor', () async {
        var notified = false;
        selector.addListener(() => notified = true);

        await selector.setProvider(AIProvider.gemini);

        expect(notified, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // setOllamaModel
    // -------------------------------------------------------------------------
    group('setOllamaModel', () {
      setUp(() {
        when(() => mockOllama.connectionInfo)
            .thenReturn(ConnectionInfo.connected('http://localhost'));
        when(() => mockOllama.getModels()).thenAnswer((_) async => [
              OllamaModel(name: 'llama2:latest'),
              OllamaModel(name: 'mistral:latest'),
              OllamaModel(name: 'phi3:latest'),
            ]);

        selector = createSelector();
      });

      test('cambia modelo exitosamente si existe', () async {
        await Future.delayed(Duration.zero);

        await selector.setOllamaModel('llama2:latest');

        expect(selector.currentOllamaModel, equals('llama2:latest'));
      });

      test('lanza excepción si modelo no existe', () async {
        await Future.delayed(Duration.zero);

        expect(
          () => selector.setOllamaModel('nonexistent:model'),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('no está disponible'),
          )),
        );
      });

      test('notifica listeners al cambiar modelo', () async {
        await Future.delayed(Duration.zero);

        var notified = false;
        selector.addListener(() => notified = true);

        await selector.setOllamaModel('mistral:latest');

        expect(notified, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // setOpenAIModel
    // -------------------------------------------------------------------------
    group('setOpenAIModel', () {
      setUp(() {
        selector = createSelector();
      });

      test('cambia modelo exitosamente si existe', () async {
        await selector.setOpenAIModel('gpt-4o');

        expect(selector.currentOpenAIModel, equals('gpt-4o'));
      });

      test('lanza excepción si modelo no existe', () async {
        expect(
          () => selector.setOpenAIModel('gpt-nonexistent'),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('no está disponible'),
          )),
        );
      });

      test('notifica listeners al cambiar modelo', () async {
        var notified = false;
        selector.addListener(() => notified = true);

        await selector.setOpenAIModel('gpt-4-turbo');

        expect(notified, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // setLocalOllamaModel
    // -------------------------------------------------------------------------
    group('setLocalOllamaModel', () {
      setUp(() {
        selector = createSelector();
      });

      test('delega a localOllamaService.changeModel', () async {
        when(() => mockLocalOllama.changeModel('model-name'))
            .thenAnswer((_) async => true);

        final result = await selector.setLocalOllamaModel('model-name');

        expect(result, isTrue);
        verify(() => mockLocalOllama.changeModel('model-name')).called(1);
      });

      test('retorna false si cambio falla', () async {
        when(() => mockLocalOllama.changeModel(any()))
            .thenAnswer((_) async => false);

        final result = await selector.setLocalOllamaModel('model-name');

        expect(result, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // refreshOpenAIAvailability
    // -------------------------------------------------------------------------
    group('refreshOpenAIAvailability', () {
      setUp(() {
        selector = createSelector();
      });

      test('actualiza disponibilidad cuando está disponible', () async {
        when(() => mockOpenAI.isAvailable()).thenAnswer((_) async => true);

        await selector.refreshOpenAIAvailability();

        expect(selector.openaiAvailable, isTrue);
      });

      test('actualiza disponibilidad cuando no está disponible', () async {
        when(() => mockOpenAI.isAvailable()).thenAnswer((_) async => false);

        await selector.refreshOpenAIAvailability();

        expect(selector.openaiAvailable, isFalse);
      });

      test('maneja excepción y marca como no disponible', () async {
        when(() => mockOpenAI.isAvailable()).thenThrow(Exception('Network error'));

        await selector.refreshOpenAIAvailability();

        expect(selector.openaiAvailable, isFalse);
      });

      test('notifica listeners', () async {
        when(() => mockOpenAI.isAvailable()).thenAnswer((_) async => true);

        var notified = false;
        selector.addListener(() => notified = true);

        await selector.refreshOpenAIAvailability();

        expect(notified, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // refreshOllama
    // -------------------------------------------------------------------------
    group('refreshOllama', () {
      setUp(() {
        selector = createSelector();
      });

      test('llama a reconnect del servicio Ollama', () async {
        when(() => mockOllama.reconnect()).thenAnswer((_) async {});

        await selector.refreshOllama();

        verify(() => mockOllama.reconnect()).called(1);
      });

      test('maneja excepción sin propagar', () async {
        when(() => mockOllama.reconnect()).thenThrow(Exception('Error'));

        // No debería lanzar excepción
        await selector.refreshOllama();
      });
    });

    // -------------------------------------------------------------------------
    // initializeLocalOllama
    // -------------------------------------------------------------------------
    group('initializeLocalOllama', () {
      setUp(() {
        selector = createSelector();
      });

      test('retorna resultado exitoso', () async {
        final initResult = LocalOllamaInitResult.success(
          'llama2',
          ['llama2', 'mistral'],
        );
        when(() => mockLocalOllama.initialize())
            .thenAnswer((_) async => initResult);

        final result = await selector.initializeLocalOllama();

        expect(result.success, isTrue);
        expect(result.modelName, equals('llama2'));
        expect(result.availableModels, contains('mistral'));
      });

      test('retorna resultado fallido', () async {
        final initResult = LocalOllamaInitResult.failure('Init error');
        when(() => mockLocalOllama.initialize())
            .thenAnswer((_) async => initResult);

        final result = await selector.initializeLocalOllama();

        expect(result.success, isFalse);
        expect(result.error, equals('Init error'));
      });

      test('notifica listeners', () async {
        when(() => mockLocalOllama.initialize())
            .thenAnswer((_) async => LocalOllamaInitResult.success('m', []));

        var notified = false;
        selector.addListener(() => notified = true);

        await selector.initializeLocalOllama();

        expect(notified, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // stopLocalOllama
    // -------------------------------------------------------------------------
    group('stopLocalOllama', () {
      test('detiene servicio local', () async {
        when(() => mockLocalOllama.stop()).thenAnswer((_) async {});

        selector = createSelector();

        await selector.stopLocalOllama();

        verify(() => mockLocalOllama.stop()).called(1);
      });

      test('cambia a Gemini si provider actual es localOllama', () async {
        when(() => mockLocalOllama.stop()).thenAnswer((_) async {});
        when(() => mockLocalOllama.initialize()).thenAnswer(
            (_) async => LocalOllamaInitResult.success('m', []));

        selector = createSelector();

        // Simular que localOllama está listo
        // (Necesitamos simular el status listener)
        final capturedListener = verify(
          () => mockLocalOllama.addStatusListener(captureAny()),
        ).captured.first as void Function(LocalOllamaStatus);

        capturedListener(LocalOllamaStatus.ready);

        // Cambiar a localOllama
        await selector.setProvider(AIProvider.localOllama);
        expect(selector.currentProvider, equals(AIProvider.localOllama));

        // Detener
        await selector.stopLocalOllama();

        expect(selector.currentProvider, equals(AIProvider.gemini));
      });

      test('notifica listeners', () async {
        when(() => mockLocalOllama.stop()).thenAnswer((_) async {});

        selector = createSelector();

        var notified = false;
        selector.addListener(() => notified = true);

        await selector.stopLocalOllama();

        expect(notified, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // retryLocalOllama
    // -------------------------------------------------------------------------
    group('retryLocalOllama', () {
      setUp(() {
        selector = createSelector();
      });

      test('delega a localOllamaService.retry', () async {
        final result = LocalOllamaInitResult.success('m', []);
        when(() => mockLocalOllama.retry()).thenAnswer((_) async => result);

        final retryResult = await selector.retryLocalOllama();

        expect(retryResult, equals(result));
        verify(() => mockLocalOllama.retry()).called(1);
      });
    });

    // -------------------------------------------------------------------------
    // Connection stream handling
    // -------------------------------------------------------------------------
    group('manejo de connection stream', () {
      test('marca ollama disponible cuando se conecta', () async {
        when(() => mockOllama.getModels()).thenAnswer((_) async => []);

        selector = createSelector();

        connectionStreamController.add(ConnectionInfo.connected('http://localhost'));
        await Future.delayed(Duration.zero);

        expect(selector.ollamaAvailable, isTrue);
      });

      test('carga modelos cuando se conecta', () async {
        final models = [
          OllamaModel(name: 'model1'),
          OllamaModel(name: 'model2'),
        ];
        when(() => mockOllama.getModels()).thenAnswer((_) async => models);

        selector = createSelector();

        connectionStreamController.add(ConnectionInfo.connected('http://localhost'));
        await Future.delayed(Duration.zero);

        expect(selector.availableModels.length, equals(2));
      });

      test('marca ollama no disponible cuando se desconecta', () async {
        when(() => mockOllama.getModels()).thenAnswer((_) async => []);

        selector = createSelector();

        // Conectar primero
        connectionStreamController.add(ConnectionInfo.connected('http://localhost'));
        await Future.delayed(Duration.zero);
        expect(selector.ollamaAvailable, isTrue);

        // Desconectar
        connectionStreamController.add(ConnectionInfo.disconnected());
        await Future.delayed(Duration.zero);

        expect(selector.ollamaAvailable, isFalse);
        expect(selector.availableModels, isEmpty);
      });

      test('cambia modelo por defecto si el actual no existe', () async {
        final models = [
          OllamaModel(name: 'llama2:latest'),
          OllamaModel(name: 'mistral:latest'),
        ];
        when(() => mockOllama.getModels()).thenAnswer((_) async => models);

        selector = createSelector();
        expect(selector.currentOllamaModel, equals('phi3:latest'));

        connectionStreamController.add(ConnectionInfo.connected('http://localhost'));
        await Future.delayed(Duration.zero);

        // phi3 no está en la lista, debe cambiar al primero
        expect(selector.currentOllamaModel, equals('llama2:latest'));
      });

      test('mantiene modelo si existe en la lista', () async {
        final models = [
          OllamaModel(name: 'phi3:latest'),
          OllamaModel(name: 'mistral:latest'),
        ];
        when(() => mockOllama.getModels()).thenAnswer((_) async => models);

        selector = createSelector();

        connectionStreamController.add(ConnectionInfo.connected('http://localhost'));
        await Future.delayed(Duration.zero);

        expect(selector.currentOllamaModel, equals('phi3:latest'));
      });
    });

    // -------------------------------------------------------------------------
    // Local Ollama status listener
    // -------------------------------------------------------------------------
    group('local ollama status listener', () {
      test('actualiza localOllamaStatus cuando cambia', () {
        selector = createSelector();

        final capturedListener = verify(
          () => mockLocalOllama.addStatusListener(captureAny()),
        ).captured.first as void Function(LocalOllamaStatus);

        capturedListener(LocalOllamaStatus.ready);

        expect(selector.localOllamaStatus, equals(LocalOllamaStatus.ready));
        expect(selector.localOllamaAvailable, isTrue);
      });

      test('notifica listeners cuando status cambia', () {
        selector = createSelector();

        final capturedListener = verify(
          () => mockLocalOllama.addStatusListener(captureAny()),
        ).captured.first as void Function(LocalOllamaStatus);

        var notified = false;
        selector.addListener(() => notified = true);

        capturedListener(LocalOllamaStatus.initializing);

        expect(notified, isTrue);
      });

      test('localOllamaLoading es true durante estados de carga', () {
        selector = createSelector();

        final capturedListener = verify(
          () => mockLocalOllama.addStatusListener(captureAny()),
        ).captured.first as void Function(LocalOllamaStatus);

        capturedListener(LocalOllamaStatus.downloadingModel);

        expect(selector.localOllamaLoading, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // getCurrentAdapter
    // -------------------------------------------------------------------------
    group('getCurrentAdapter', () {
      test('retorna GeminiServiceAdapter para Gemini', () {
        selector = createSelector();

        final adapter = selector.getCurrentAdapter();

        expect(adapter, isA<GeminiServiceAdapter>());
      });

      test('retorna OpenAIServiceAdapter para OpenAI', () async {
        when(() => mockOpenAI.isAvailable()).thenAnswer((_) async => true);

        selector = createSelector();
        await Future.delayed(Duration.zero);
        await selector.setProvider(AIProvider.openai);

        final adapter = selector.getCurrentAdapter();

        expect(adapter, isA<OpenAIServiceAdapter>());
      });

      test('retorna OllamaServiceAdapter para Ollama', () async {
        when(() => mockOllama.connectionInfo)
            .thenReturn(ConnectionInfo.connected('http://localhost'));
        when(() => mockOllama.getModels()).thenAnswer((_) async => []);

        selector = createSelector();
        await Future.delayed(Duration.zero);
        await selector.setProvider(AIProvider.ollama);

        final adapter = selector.getCurrentAdapter();

        expect(adapter, isA<OllamaServiceAdapter>());
      });

      test('retorna LocalOllamaServiceAdapter para LocalOllama', () async {
        selector = createSelector();

        // Simular que está listo
        final capturedListener = verify(
          () => mockLocalOllama.addStatusListener(captureAny()),
        ).captured.first as void Function(LocalOllamaStatus);

        capturedListener(LocalOllamaStatus.ready);

        await selector.setProvider(AIProvider.localOllama);

        final adapter = selector.getCurrentAdapter();

        expect(adapter, isA<LocalOllamaServiceAdapter>());
      });
    });

    // -------------------------------------------------------------------------
    // dispose
    // -------------------------------------------------------------------------
    group('dispose', () {
      test('cancela suscripción a connection stream', () async {
        selector = createSelector();

        selector.dispose();

        // Verificar que añadir al stream no cause errores
        connectionStreamController.add(ConnectionInfo.disconnected());
        await Future.delayed(Duration.zero);
      });

      test('remueve status listener de localOllama', () {
        selector = createSelector();

        selector.dispose();

        verify(() => mockLocalOllama.removeStatusListener(any())).called(1);
      });

      test('dispone servicios', () {
        when(() => mockLocalOllama.dispose()).thenReturn(null);
        when(() => mockOllama.dispose()).thenReturn(null);

        selector = createSelector();

        selector.dispose();

        verify(() => mockLocalOllama.dispose()).called(1);
        verify(() => mockOllama.dispose()).called(1);
      });
    });

    // -------------------------------------------------------------------------
    // Casos edge
    // -------------------------------------------------------------------------
    group('casos edge', () {
      test('maneja lista de modelos vacía sin error', () async {
        when(() => mockOllama.connectionInfo)
            .thenReturn(ConnectionInfo.connected('http://localhost'));
        when(() => mockOllama.getModels()).thenAnswer((_) async => []);

        selector = createSelector();
        await Future.delayed(Duration.zero);

        expect(selector.availableModels, isEmpty);
        expect(selector.ollamaAvailable, isTrue);
      });

      test('maneja error al cargar modelos', () async {
        when(() => mockOllama.connectionInfo)
            .thenReturn(ConnectionInfo.connected('http://localhost'));
        when(() => mockOllama.getModels()).thenThrow(Exception('Network error'));

        selector = createSelector();
        await Future.delayed(Duration.zero);

        expect(selector.availableModels, isEmpty);
      });

      test('ChangeNotifier notifica correctamente a múltiples listeners', () async {
        selector = createSelector();

        var count1 = 0;
        var count2 = 0;

        selector.addListener(() => count1++);
        selector.addListener(() => count2++);

        await selector.setProvider(AIProvider.gemini);

        expect(count1, equals(1));
        expect(count2, equals(1));
      });

      test('puede cambiar entre proveedores múltiples veces', () async {
        when(() => mockOpenAI.isAvailable()).thenAnswer((_) async => true);
        when(() => mockOllama.connectionInfo)
            .thenReturn(ConnectionInfo.connected('http://localhost'));
        when(() => mockOllama.getModels()).thenAnswer((_) async => []);

        selector = createSelector();
        await Future.delayed(Duration.zero);

        await selector.setProvider(AIProvider.openai);
        expect(selector.currentProvider, equals(AIProvider.openai));

        await selector.setProvider(AIProvider.ollama);
        expect(selector.currentProvider, equals(AIProvider.ollama));

        await selector.setProvider(AIProvider.gemini);
        expect(selector.currentProvider, equals(AIProvider.gemini));
      });
    });
  });
}