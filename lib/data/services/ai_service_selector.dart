import 'package:flutter/foundation.dart';
import '../models/remote_ollama_models.dart';
import '../models/local_ollama_models.dart';
import 'gemini_service.dart';
import 'ollama_service.dart';
import 'openai_service.dart';
import 'local_ollama_service.dart';
import 'dart:async';
import 'ai_service_adapters.dart';
import '../../domain/usecases/command_processor.dart';

enum AIProvider {
  gemini,
  ollama,
  openai,
  localOllama,
}

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
    _ollamaConnectionSubscription = _ollamaService.connectionStream.listen(_onOllamaConnectionChanged);

    _localOllamaService.addStatusListener(_onLocalOllamaStatusChanged);

    _initializeOpenAI();

    _onOllamaConnectionChanged(_ollamaService.connectionInfo);

    debugPrint('✅ [AIServiceSelector] Servicios inicializados y escuchando cambios...');
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
  bool get localOllamaAvailable => _localOllamaStatus == LocalOllamaStatus.ready;
  bool get localOllamaLoading => _localOllamaStatus.isProcessing;
  String? get localOllamaError => _localOllamaService.errorMessage;

  Stream<ConnectionInfo> get connectionStream => _ollamaService.connectionStream;

  void _onLocalOllamaStatusChanged(LocalOllamaStatus status) {
    debugPrint('📡 [AIServiceSelector] Estado Ollama Local cambió a: ${status.displayText}');
    _localOllamaStatus = status;
    notifyListeners();
  }

  Future<void> refreshOpenAIAvailability() async {
    try {
      debugPrint('🔄 [AIServiceSelector] Verificando disponibilidad de OpenAI...');
      _openaiAvailable = await _openaiService.isAvailable();
      debugPrint('   ${_openaiAvailable ? "✅" : "❌"} OpenAI ${_openaiAvailable ? "disponible" : "no disponible"}');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error verificando OpenAI: $e');
      _openaiAvailable = false;
      notifyListeners();
    }
  }

  Future<void> refreshOllama() async {
    debugPrint('🔄 [AIServiceSelector] Refrescando Ollama...');
    try {
      await _ollamaService.reconnect();
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error refrescando Ollama: $e');
    }
  }

  Future<void> _onOllamaConnectionChanged(ConnectionInfo info) async {
    debugPrint('📡 [AIServiceSelector] Estado Ollama Remoto cambió a: ${info.status}');

    if (info.status == ConnectionStatus.connected) {
      final wasAvailable = _ollamaAvailable;
      _ollamaAvailable = true;

      if (!wasAvailable) {
        debugPrint('   -> Conexión establecida. Cargando modelos...');
        await _loadAvailableModels();
      }
    } else {
      if (_ollamaAvailable) {
        debugPrint('   -> Conexión perdida. Vaciando modelos.');
      }
      _ollamaAvailable = false;
      _availableModels = [];
    }

    notifyListeners();
  }

  Future<void> _initializeOllama() async {
    try {
      debugPrint('🔷 [AIServiceSelector] Inicializando Ollama remoto...');
      await _checkOllamaAvailability();
      if (_ollamaAvailable) {
        await _loadAvailableModels();
      } else {
        debugPrint('   ⚠️ Ollama remoto no disponible en la inicialización');
      }
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error inicializando Ollama: $e');
    }
    notifyListeners();
  }

  Future<void> _initializeOpenAI() async {
    try {
      debugPrint('🔷 [AIServiceSelector] Inicializando OpenAI...');
      _openaiAvailable = await _openaiService.isAvailable();
      debugPrint('   ${_openaiAvailable ? "✅" : "⚠️"} OpenAI ${_openaiAvailable ? "disponible" : "no disponible"}');
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error inicializando OpenAI: $e');
      _openaiAvailable = false;
    }
  }

  Future<LocalOllamaInitResult> initializeLocalOllama() async {
    debugPrint('🚀 [AIServiceSelector] Iniciando Ollama Local...');

    final result = await _localOllamaService.initialize();

    if (result.success) {
      debugPrint('✅ [AIServiceSelector] Ollama Local inicializado correctamente');
      debugPrint('   🤖 Modelo activo: ${result.modelName}');
      debugPrint('   📋 Modelos disponibles: ${result.availableModels?.join(", ")}');
    } else {
      debugPrint('❌ [AIServiceSelector] Error inicializando Ollama Local: ${result.error}');
    }

    notifyListeners();
    return result;
  }

  Future<void> stopLocalOllama() async {
    debugPrint('🛑 [AIServiceSelector] Deteniendo Ollama Local...');

    if (_currentProvider == AIProvider.localOllama) {
      debugPrint('   🔄 Cambiando a Gemini antes de detener');
      await setProvider(AIProvider.gemini);
    }

    await _localOllamaService.stop();
    notifyListeners();
  }

  Future<LocalOllamaInitResult> retryLocalOllama() async {
    debugPrint('🔄 [AIServiceSelector] Reintentando inicialización de Ollama Local...');
    return await _localOllamaService.retry();
  }

  Future<void> _checkOllamaAvailability() async {
    try {
      debugPrint('💓 [AIServiceSelector] Verificando disponibilidad de Ollama remoto...');
      final health = await _ollamaService.checkHealth();
      _ollamaAvailable = health.success && health.ollamaAvailable;
      debugPrint('   ${_ollamaAvailable ? "✅" : "❌"} Ollama remoto ${_ollamaAvailable ? "disponible" : "no disponible"}');
    } catch (e) {
      debugPrint('   ❌ Error en health check: $e');
      _ollamaAvailable = false;
    }
  }

  Future<void> _loadAvailableModels() async {
    try {
      debugPrint('📋 [AIServiceSelector] Cargando modelos de Ollama remoto...');
      _availableModels = await _ollamaService.getModels();

      if (_availableModels.isNotEmpty) {
        final modelExists = _availableModels.any((m) => m.name == _currentOllamaModel);
        if (modelExists) {
          debugPrint('   ✅ Modelo actual $_currentOllamaModel está disponible');
        } else {
          final oldModel = _currentOllamaModel;
          _currentOllamaModel = _availableModels.first.name;
          debugPrint('   ⚠️ Modelo $oldModel no encontrado, usando ${_availableModels.first.name}');
        }
      } else {
        debugPrint('   ❌ No se encontraron modelos en el servidor.');
      }
    } catch (e) {
      debugPrint('❌ [AIServiceSelector] Error cargando modelos: $e');
      _availableModels = [];
    }
  }

  Future<void> setProvider(AIProvider provider) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando proveedor a: $provider');

    if (provider == AIProvider.ollama && !_ollamaAvailable) {
      debugPrint('   ⚠️ Ollama remoto no está disponible');
      throw Exception('Ollama remoto no está disponible');
    }

    if (provider == AIProvider.openai && !_openaiAvailable) {
      debugPrint('   ⚠️ OpenAI no está disponible');
      throw Exception('OpenAI no está disponible. Configure su API Key en Ajustes');
    }

    if (provider == AIProvider.localOllama) {
      if (!isLocalOllamaSupported) {
        debugPrint('   ⚠️ Ollama Local no soportado en esta plataforma');
        throw Exception('Ollama Local no está disponible en este dispositivo.');
      }
      if (!localOllamaAvailable) {
        debugPrint('   ⚠️ Ollama Local no está listo');
        throw Exception('Ollama Local no está listo. Inicialízalo primero.');
      }
    }

    _currentProvider = provider;
    notifyListeners();
    debugPrint('   ✅ Proveedor cambiado a $provider');
  }

  Future<void> setOllamaModel(String modelName) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo Ollama a: $modelName');

    if (!_availableModels.any((m) => m.name == modelName)) {
      debugPrint('   ❌ Modelo $modelName no está disponible');
      throw Exception('Modelo $modelName no está disponible');
    }

    _currentOllamaModel = modelName;
    notifyListeners();
    debugPrint('   ✅ Modelo cambiado a $modelName');
  }

  Future<void> setOpenAIModel(String modelName) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo OpenAI a: $modelName');

    if (!OpenAIService.availableModels.contains(modelName)) {
      debugPrint('   ❌ Modelo $modelName no está disponible');
      throw Exception('Modelo $modelName no está disponible');
    }

    _currentOpenAIModel = modelName;
    notifyListeners();
    debugPrint('   ✅ Modelo OpenAI cambiado a $modelName');
  }

  Future<bool> setLocalOllamaModel(String modelName) async {
    debugPrint('🔄 [AIServiceSelector] Cambiando modelo Ollama Local a: $modelName');

    final success = await _localOllamaService.changeModel(modelName);

    if (success) {
      debugPrint('   ✅ Modelo Ollama Local cambiado a $modelName');
    } else {
      debugPrint('   ❌ Error cambiando modelo Ollama Local');
    }

    return success;
  }

  @override
  void dispose() {
    debugPrint('🔴 [AIServiceSelector] Disposing...');
    _ollamaConnectionSubscription?.cancel();
    _localOllamaService.removeStatusListener(_onLocalOllamaStatusChanged);
    _localOllamaService.dispose();
    _ollamaService.dispose();
    super.dispose();
  }

  AIServiceBase getCurrentAdapter() {
    debugPrint('🔌 [AIServiceSelector] Obteniendo adaptador para: $_currentProvider');

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