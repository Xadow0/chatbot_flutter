import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../models/local_ollama_models.dart';
import 'local_ollama_installer.dart';

class OllamaManagedService {
  LocalOllamaStatus _status = LocalOllamaStatus.notInitialized;
  String? _errorMessage;
  List<String> _availableModels = [];
  String? _currentModel;

  final LocalOllamaConfig _config;
  Timer? _healthCheckTimer;
  Timer? _inactivityTimer;
  DateTime? _lastActivityTime;
  http.Client? _downloadClient;

  final List<ValueChanged<LocalOllamaStatus>> _statusListeners = [];
  final List<ValueChanged<LocalOllamaInstallProgress>> _installProgressListeners = [];
  final List<VoidCallback> _modelsChangedListeners = [];
  final List<Map<String, String>> _conversationHistory = [];

  Stream<LocalOllamaInstallProgress>? _currentInstallStream;

  OllamaManagedService({LocalOllamaConfig? config}) : _config = config ?? const LocalOllamaConfig() {
    debugPrint('🤖 [OllamaManaged] Servicio inicializado');
    debugPrint('   🔌 URL base: ${_config.fullBaseUrl}');
  }

  LocalOllamaStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => _status == LocalOllamaStatus.ready;
  bool get isProcessing => _status.isProcessing;
  List<String> get availableModels => _availableModels;
  String? get currentModel => _currentModel;
  String get baseUrl => _config.fullBaseUrl;
  Stream<LocalOllamaInstallProgress>? get installProgressStream => _currentInstallStream;

  bool get isPlatformSupported {
    return Platform.isWindows || Platform.isMacOS || Platform.isLinux;
  }

  void addStatusListener(ValueChanged<LocalOllamaStatus> listener) {
    _statusListeners.add(listener);
  }

  void removeStatusListener(ValueChanged<LocalOllamaStatus> listener) {
    _statusListeners.remove(listener);
  }

  void addInstallProgressListener(ValueChanged<LocalOllamaInstallProgress> listener) {
    _installProgressListeners.add(listener);
  }

  void removeInstallProgressListener(ValueChanged<LocalOllamaInstallProgress> listener) {
    _installProgressListeners.remove(listener);
  }

  void _updateStatus(LocalOllamaStatus newStatus, {String? error}) {
    _status = newStatus;
    _errorMessage = error;

    debugPrint('📊 [OllamaManaged] Estado: ${newStatus.displayText}');
    if (error != null) {
      debugPrint('   ❌ Error: $error');
    }

    for (var listener in _statusListeners) {
      try {
        listener(newStatus);
      } catch (e) {
        debugPrint('⚠️ [OllamaManaged] Error notificando listener: $e');
      }
    }
  }

  void _notifyInstallProgress(LocalOllamaInstallProgress progress) {
    for (var listener in _installProgressListeners) {
      try {
        listener(progress);
      } catch (e) {
        debugPrint('⚠️ [OllamaManaged] Error notificando progreso: $e');
      }
    }
  }

  void _notifyModelsChanged() {
    for (var listener in _modelsChangedListeners) {
      try {
        listener();
      } catch (e) {
        debugPrint('⚠️ [OllamaManaged] Error notificando cambio de modelos: $e');
      }
    }
  }

  Future<LocalOllamaInitResult> initialize({String? modelName}) async {
    if (!isPlatformSupported) {
      debugPrint('❌ [OllamaManaged] Plataforma no soportada: ${Platform.operatingSystem}');
      return LocalOllamaInitResult(
        success: false,
        error: 'Ollama Local no está disponible en ${Platform.operatingSystem}',
      );
    }

    final startTime = DateTime.now();
    debugPrint('🚀 [OllamaManaged] ========================================');
    debugPrint('🚀 [OllamaManaged] INICIALIZANDO SERVICIO');
    debugPrint('🚀 [OllamaManaged] ========================================');

    try {
      _updateStatus(LocalOllamaStatus.checkingInstallation);

      debugPrint('🔍 [OllamaManaged] Paso 1: Verificando instalación...');
      final installInfo = await LocalOllamaInstaller.checkInstallation();

      bool wasNewInstallation = false;

      if (installInfo.needsInstallation) {
        debugPrint('   📦 Ollama no instalado, iniciando instalación...');

        _updateStatus(LocalOllamaStatus.downloadingInstaller);

        final installStream = LocalOllamaInstaller.installOllama();
        _currentInstallStream = installStream;

        await for (var progress in installStream) {
          _notifyInstallProgress(progress);

          if (progress.status != _status) {
            final errorMessage = (progress.status == LocalOllamaStatus.error) ? progress.message : null;

            _updateStatus(progress.status, error: errorMessage);
          }

          if (progress.status == LocalOllamaStatus.error) {
            throw LocalOllamaException(
              'Error instalando Ollama',
              details: progress.message,
            );
          }
        }

        wasNewInstallation = true;
        debugPrint('   ✅ Ollama instalado correctamente');
      } else {
        debugPrint('   ✅ Ollama ya está instalado');
        debugPrint('   📍 Ubicación: ${installInfo.installPath}');
        debugPrint('   📌 Versión: ${installInfo.version}');
      }

      debugPrint('🔍 [OllamaManaged] Paso 2: Verificando servidor...');
      _updateStatus(LocalOllamaStatus.starting);

      bool serverRunning = await LocalOllamaInstaller.isOllamaRunning(
        port: _config.port,
      );

      if (!serverRunning) {
        debugPrint('   🚀 Iniciando servidor Ollama...');
        final started = await LocalOllamaInstaller.startOllamaService();

        if (!started) {
          throw LocalOllamaException(
            'Ollama no responde',
            details: 'El servidor no inició correctamente',
          );
        }

        debugPrint('   ✅ Servidor iniciado');

        debugPrint('   ⏳ Esperando a que el servidor esté listo...');
        await _waitForServerReady();
      } else {
        debugPrint('   ✅ Servidor ya está corriendo');
      }

      debugPrint('🔍 [OllamaManaged] Paso 3: Obteniendo modelos...');
      await _refreshAvailableModels();

      final targetModel = modelName ?? LocalOllamaModel.defaultModel;

      final modelExists = _availableModels.any((m) => m == targetModel || m.startsWith('$targetModel:'));

      if (!modelExists) {
        debugPrint('   📥 Modelo $targetModel no disponible, descargando...');
        _updateStatus(LocalOllamaStatus.downloadingModel);

        await _downloadModel(targetModel);

        if (_status == LocalOllamaStatus.error) {
          throw LocalOllamaException(_errorMessage ?? 'Error desconocido durante la descarga');
        }

        debugPrint('   ✅ Descarga completada, refrescando modelos...');
        await _refreshAvailableModels();
      }

      _currentModel = _availableModels.firstWhere(
        (m) => m == targetModel || m.startsWith('$targetModel:'),
        orElse: () {
          if (_availableModels.isNotEmpty) return _availableModels.first;

          throw LocalOllamaException(
            'Modelo no encontrado',
            details: 'No se encontró $targetModel ni ningún otro modelo disponible.',
          );
        },
      );

      debugPrint('   ✅ Modelo seleccionado: $_currentModel');
      debugPrint('   📋 Modelos disponibles: ${_availableModels.join(", ")}');

      _updateStatus(LocalOllamaStatus.ready);

      debugPrint('🔍 [OllamaManaged] Paso 4: Probando inferencia...');
      await _testInference();

      final initTime = DateTime.now().difference(startTime);

      _startHealthCheckTimer();
      _updateLastActivity();

      debugPrint('✅ [OllamaManaged] ========================================');
      debugPrint('✅ [OllamaManaged] INICIALIZACIÓN EXITOSA');
      debugPrint('✅ [OllamaManaged] Tiempo: ${initTime.inSeconds}s');
      debugPrint('✅ [OllamaManaged] Modelo: $_currentModel');
      debugPrint('✅ [OllamaManaged] Modelos disponibles: ${_availableModels.length}');
      debugPrint('✅ [OllamaManaged] ========================================');

      return LocalOllamaInitResult(
        success: true,
        modelName: _currentModel,
        availableModels: _availableModels,
        initTime: initTime,
        wasNewInstallation: wasNewInstallation,
      );
    } catch (e) {
      debugPrint('❌ [OllamaManaged] ========================================');
      debugPrint('❌ [OllamaManaged] ERROR EN INICIALIZACIÓN');
      debugPrint('❌ [OllamaManaged] $e');
      debugPrint('❌ [OllamaManaged] ========================================');

      _downloadClient?.close();
      _downloadClient = null;

      final errorMsg = (e is LocalOllamaException) ? e.toString() : e.toString();
      _updateStatus(LocalOllamaStatus.error, error: errorMsg);

      return LocalOllamaInitResult(
        success: false,
        error: errorMsg,
      );
    }
  }

  Future<List<InstalledModelInfo>> getInstalledModelsInfo() async {
    try {
      final response = await http
          .get(
            Uri.parse('${_config.fullBaseUrl}/api/tags'),
          )
          .timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = data['models'] as List? ?? [];

        return models.map((m) {
          final sizeBytes = m['size'] as int? ?? 0;
          final modifiedAt = m['modified_at'] as String?;

          return InstalledModelInfo(
            name: m['name'] as String? ?? 'unknown',
            size: sizeBytes,
            modifiedAt: modifiedAt != null ? DateTime.tryParse(modifiedAt) : null,
            details: m['details'] as Map<String, dynamic>?,
          );
        }).toList();
      }

      return [];
    } catch (e) {
      debugPrint('   ⚠️ Error obteniendo info de modelos: $e');
      return [];
    }
  }

  Future<DeleteModelResult> deleteModel(String modelName) async {
    debugPrint('🗑️ [OllamaManaged] Eliminando modelo: $modelName');

    if (_status != LocalOllamaStatus.ready) {
      return DeleteModelResult(
        success: false,
        error: 'El servicio de Ollama no está disponible',
      );
    }

    if (_availableModels.length <= 1) {
      return DeleteModelResult(
        success: false,
        error: 'No puedes eliminar el único modelo disponible',
      );
    }

    try {
      final response = await http
          .delete(
            Uri.parse('${_config.fullBaseUrl}/api/delete'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'name': modelName}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        debugPrint('   ✅ Modelo eliminado: $modelName');

        await _refreshAvailableModels();

        if (_currentModel == modelName || (_currentModel != null && _currentModel!.startsWith('$modelName:'))) {
          if (_availableModels.isNotEmpty) {
            _currentModel = _availableModels.first;
            debugPrint('   🔄 Nuevo modelo activo: $_currentModel');
          } else {
            _currentModel = null;
          }
        }

        _notifyModelsChanged();

        return DeleteModelResult(
          success: true,
          deletedModel: modelName,
          newCurrentModel: _currentModel,
        );
      } else {
        return DeleteModelResult(
          success: false,
          error: 'Error del servidor: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('   ❌ Error eliminando modelo: $e');
      return DeleteModelResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  Future<void> refreshModels() async {
    await _refreshAvailableModels();
    _notifyModelsChanged();
  }

  Future<void> _waitForServerReady({int maxAttempts = 10}) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await http
            .get(
              Uri.parse('${_config.fullBaseUrl}/api/version'),
            )
            .timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          debugPrint('   ✅ Servidor listo después de ${i + 1} intentos');
          return;
        }
      } catch (e) {
        debugPrint('   ⏳ Intento ${i + 1}/$maxAttempts - Servidor aún no listo');
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    throw LocalOllamaException(
      'Timeout esperando al servidor',
      details: 'El servidor no respondió después de $maxAttempts intentos',
    );
  }

  Future<void> _refreshAvailableModels() async {
    try {
      final response = await http
          .get(
            Uri.parse('${_config.fullBaseUrl}/api/tags'),
          )
          .timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = data['models'] as List? ?? [];

        _availableModels = models.map((m) => m['name'] as String).where((name) => name.isNotEmpty).toList();

        debugPrint('   📋 Modelos disponibles: ${_availableModels.join(", ")}');
      } else {
        debugPrint('   ⚠️ No se pudieron obtener modelos (${response.statusCode})');
        _availableModels = [];
      }
    } catch (e) {
      debugPrint('   ⚠️ Error obteniendo modelos: $e');
      _availableModels = [];
    }
  }

  Future<void> _downloadModel(String modelName) async {
    debugPrint('   📥 Iniciando descarga de modelo (stream): $modelName');
    _updateStatus(LocalOllamaStatus.downloadingModel);

    final request = http.Request(
      'POST',
      Uri.parse('${_config.fullBaseUrl}/api/pull'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({'name': modelName, 'stream': true});

    _downloadClient = http.Client();

    try {
      final response = await _downloadClient!.send(request).timeout(
            const Duration(minutes: 60),
          );

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        throw LocalOllamaException(
          'Error del servidor de Ollama',
          details: 'HTTP ${response.statusCode}: $errorBody',
        );
      }

      String lastStatus = '';
      final streamLines = response.stream.transform(utf8.decoder).transform(const LineSplitter());

      await for (final line in streamLines) {
        if (line.isEmpty) continue;

        try {
          final data = json.decode(line);

          if (data['error'] != null) {
            throw LocalOllamaException(
              'Error durante la descarga',
              details: data['error'],
            );
          }

          if (data['status'] != null) {
            final status = data['status'] as String;

            if (status != lastStatus) {
              debugPrint('   [Ollama Pull] $status');
              lastStatus = status;
            }

            int? downloaded = data['completed'] as int?;
            int? total = data['total'] as int?;
            double progress = 0.0;

            if (downloaded != null && total != null && total > 0) {
              progress = downloaded / total;
            } else if (status.contains('pulling')) {
              progress = 0.0;
            } else if (status.contains('verifying')) {
              progress = 1.0;
            } else if (status.contains('success')) {
              progress = 1.0;
            }

            _notifyInstallProgress(LocalOllamaInstallProgress(
              status: LocalOllamaStatus.downloadingModel,
              progress: progress,
              message: status,
              bytesDownloaded: downloaded,
              totalBytes: total,
            ));
          }
        } catch (e) {
          if (e is LocalOllamaException) rethrow;
          debugPrint('   ⚠️ Error parseando línea de stream: $line | Error: $e');
        }
      }

      debugPrint('   ✅ Stream de descarga completado: $modelName');

      _notifyInstallProgress(LocalOllamaInstallProgress(
        status: LocalOllamaStatus.downloadingModel,
        progress: 1.0,
        message: 'Descarga completada',
      ));
    } catch (e) {
      if (e is http.ClientException) {
        debugPrint('   🛑 Descarga cancelada (cliente cerrado).');
        return;
      }

      debugPrint('   ❌ Error en _downloadModel: $e');
      if (e is LocalOllamaException) rethrow;
      if (e is TimeoutException) {
        throw LocalOllamaException(
          'Timeout de descarga',
          details: 'La descarga del modelo tardó más de 60 minutos.',
        );
      }
      throw LocalOllamaException(
        'Error descargando modelo',
        details: e.toString(),
      );
    } finally {
      _downloadClient?.close();
      _downloadClient = null;
    }
  }

  void cancelModelDownload() {
    if (_status != LocalOllamaStatus.downloadingModel && _status != LocalOllamaStatus.downloadingInstaller) {
      debugPrint('   ℹ️ No hay descarga activa para cancelar');
      return;
    }

    debugPrint('🛑 [OllamaManaged] Solicitud de cancelación de descarga...');

    _downloadClient?.close();
    _downloadClient = null;

    _updateStatus(LocalOllamaStatus.error, error: 'Descarga cancelada por el usuario');
  }

  Future<void> _testInference() async {
    try {
      debugPrint('   🧪 Ejecutando test de inferencia...');
      debugPrint('   🤖 Usando modelo: $_currentModel');

      final buffer = StringBuffer();
      await for (final chunk in generateContentStream('Responde solo con "OK"', maxTokens: 10)) {
        buffer.write(chunk);
      }

      if (buffer.isEmpty) {
        throw LocalOllamaException('El modelo no generó respuesta');
      }

      debugPrint('   ✅ Test de inferencia exitoso: ${buffer.toString().trim()}');
    } catch (e) {
      debugPrint('   ❌ Test de inferencia falló: $e');
      throw LocalOllamaException(
        'Error en test de inferencia',
        details: e.toString(),
      );
    }
  }

  Future<bool> changeModel(String modelName) async {
    debugPrint('🔄 [OllamaManaged] Solicitud para cambiar modelo a: $modelName');

    if (_currentModel != null && (_currentModel == modelName || _currentModel!.startsWith('$modelName:'))) {
      debugPrint('   ℹ️ Modelo $modelName ya está activo.');
      if (_status != LocalOllamaStatus.ready) {
        _updateStatus(LocalOllamaStatus.ready);
      }
      return true;
    }

    try {
      final modelExists = _availableModels.any((m) => m == modelName || m.startsWith('$modelName:'));

      if (!modelExists) {
        debugPrint('   📥 Modelo $modelName no encontrado localmente, descargando...');
        await _downloadModel(modelName);
        await _refreshAvailableModels();
        debugPrint('   ✅ Descarga de $modelName completada.');
      } else {
        debugPrint('   ℹ️ Modelo $modelName ya está descargado.');
      }

      final fullModelName = _availableModels.firstWhere(
        (m) => m == modelName || m.startsWith('$modelName:'),
        orElse: () =>
            throw LocalOllamaException('Modelo no encontrado', details: 'No se pudo encontrar $modelName después de descargar.'),
      );

      debugPrint('   ⏳ Cargando modelo $fullModelName en memoria...');
      _currentModel = fullModelName;
      _updateStatus(LocalOllamaStatus.loading);

      await _testInference();

      debugPrint('   ✅ [OllamaManaged] Modelo cambiado y listo: $_currentModel');
      _updateStatus(LocalOllamaStatus.ready);

      return true;
    } catch (e) {
      debugPrint('   ❌ Error en changeModel: $e');
      final errorMsg = (e is LocalOllamaException) ? e.toString() : e.toString();
      _updateStatus(LocalOllamaStatus.error, error: errorMsg);
      return false;
    }
  }

  Future<void> pause() async {
    if (_status != LocalOllamaStatus.ready) return;

    debugPrint('⏸️ [OllamaManaged] Pausando servicio...');
    _stopHealthCheckTimer();
    _stopInactivityTimer();

    _updateStatus(LocalOllamaStatus.notInitialized);
  }

  Future<void> resume() async {
    debugPrint('▶️ [OllamaManaged] Reanudando servicio...');

    final serverRunning = await LocalOllamaInstaller.isOllamaRunning(
      port: _config.port,
    );

    if (!serverRunning) {
      debugPrint('   🚀 Reiniciando servidor...');
      await LocalOllamaInstaller.startOllamaService();
    }

    _updateStatus(LocalOllamaStatus.ready);
    _startHealthCheckTimer();
    _updateLastActivity();
  }

  Future<void> stop() async {
    debugPrint('🛑 [OllamaManaged] Deteniendo servicio...');

    _stopHealthCheckTimer();
    _stopInactivityTimer();

    await LocalOllamaInstaller.stopOllamaService();

    _updateStatus(LocalOllamaStatus.notInitialized);
    _availableModels.clear();
    _currentModel = null;

    debugPrint('   ✅ Servicio detenido');
  }

  Future<LocalOllamaInitResult> retry() async {
    debugPrint('🔄 [OllamaManaged] Reintentando inicialización...');
    return await initialize(modelName: _currentModel ?? LocalOllamaModel.defaultModel);
  }

  Future<bool> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('${_config.fullBaseUrl}/api/version'),
          )
          .timeout(const Duration(seconds: 3));

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  void _startHealthCheckTimer() {
    _stopHealthCheckTimer();

    _healthCheckTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) async {
        final healthy = await checkHealth();

        if (!healthy && _status == LocalOllamaStatus.ready) {
          debugPrint('⚠️ [OllamaManaged] Health check falló');
          _updateStatus(LocalOllamaStatus.error, error: 'Servicio no responde');
        }
      },
    );
  }

  void _stopHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;
  }

  void _updateLastActivity() {
    _lastActivityTime = DateTime.now();
    _restartInactivityTimer();
  }

  void _restartInactivityTimer() {
    _stopInactivityTimer();
  }

  void _stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  void dispose() {
    debugPrint('🔴 [OllamaManaged] Disposing...');

    _stopHealthCheckTimer();
    _stopInactivityTimer();
    _statusListeners.clear();
    _installProgressListeners.clear();
  }

  Stream<String> generateContentStream(
    String prompt, {
    double? temperature,
    int? maxTokens,
  }) async* {
    if (!isAvailable) {
      throw LocalOllamaException(
        'Modelo no disponible',
        details: 'Estado actual: ${_status.displayText}',
      );
    }

    _updateLastActivity();

    debugPrint('🌊 [OllamaManaged] generateContentStream (sin historial)');
    debugPrint('   🤖 Modelo: $_currentModel');

    final client = http.Client();

    try {
      final request = http.Request(
        'POST',
        Uri.parse('${_config.fullBaseUrl}/api/generate'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({
        'model': _currentModel,
        'prompt': prompt,
        'stream': true,
        'options': {
          'temperature': temperature ?? _config.temperature,
          'num_predict': maxTokens ?? _config.maxTokens,
        },
      });

      final response = await client.send(request);

      if (response.statusCode != 200) {
        throw LocalOllamaException('Error HTTP ${response.statusCode}');
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;

        try {
          final data = json.decode(chunk);
          final text = data['response'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
          if (data['done'] == true) break;
        } catch (e) {
          debugPrint('   ⚠️ Error parseando chunk: $e');
        }
      }

      debugPrint('✅ [OllamaManaged] Stream completado');
    } finally {
      client.close();
    }
  }

  Stream<String> generateContentStreamContext(
    String prompt, {
    double? temperature,
    int? maxTokens,
  }) async* {
    if (!isAvailable) {
      throw LocalOllamaException(
        'Modelo no disponible',
        details: 'Estado actual: ${_status.displayText}',
      );
    }

    _updateLastActivity();

    debugPrint('🌊 [OllamaManaged] generateContentStreamContext');
    debugPrint('   🤖 Modelo: $_currentModel');
    debugPrint('   📚 Historial: ${_conversationHistory.length} mensajes');

    _conversationHistory.add({
      'role': 'user',
      'content': prompt,
    });

    final messages = List<Map<String, String>>.from(_conversationHistory);

    final client = http.Client();
    final fullResponse = StringBuffer();
    bool hasError = false;

    try {
      final request = http.Request(
        'POST',
        Uri.parse('${_config.fullBaseUrl}/api/chat'),
      );
      request.headers['Content-Type'] = 'application/json';
      request.body = json.encode({
        'model': _currentModel,
        'messages': messages,
        'stream': true,
        'options': {
          'temperature': temperature ?? _config.temperature,
          'num_predict': maxTokens ?? _config.maxTokens,
        },
      });

      final response = await client.send(request);

      if (response.statusCode != 200) {
        hasError = true;
        throw LocalOllamaException('Error HTTP ${response.statusCode}');
      }

      await for (final chunk in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (chunk.trim().isEmpty) continue;

        try {
          final data = json.decode(chunk);
          final message = data['message'] as Map<String, dynamic>?;
          final text = message?['content'] as String?;
          if (text != null && text.isNotEmpty) {
            fullResponse.write(text);
            yield text;
          }
          if (data['done'] == true) break;
        } catch (e) {
          debugPrint('   ⚠️ Error parseando chunk: $e');
        }
      }

      _conversationHistory.add({
        'role': 'assistant',
        'content': fullResponse.toString(),
      });

      debugPrint('✅ [OllamaManaged] Stream completado: ${fullResponse.length} chars');
    } catch (e) {
      hasError = true;
      debugPrint('❌ [OllamaManaged] Error en stream: $e');
      rethrow;
    } finally {
      client.close();
      if (hasError && _conversationHistory.isNotEmpty) {
        _conversationHistory.removeLast();
      }
    }
  }

  void clearConversation() {
    _conversationHistory.clear();
    debugPrint('🧹 [OllamaManaged] Historial de conversación limpiado');
  }

  void addUserMessage(String content) {
    _conversationHistory.add({
      'role': 'user',
      'content': content,
    });
    debugPrint('📝 [LocalOllamaService] Mensaje de usuario añadido al historial');
  }

  void addBotMessage(String content) {
    _conversationHistory.add({
      'role': 'assistant',
      'content': content,
    });
    debugPrint('📝 [LocalOllamaService] Mensaje del bot añadido al historial');
  }
}

class InstalledModelInfo {
  final String name;
  final int size;
  final DateTime? modifiedAt;
  final Map<String, dynamic>? details;

  InstalledModelInfo({
    required this.name,
    required this.size,
    this.modifiedAt,
    this.details,
  });

  String get sizeFormatted {
    if (size >= 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    } else if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(0)} MB';
    } else {
      return '${(size / 1024).toStringAsFixed(0)} KB';
    }
  }

  String get displayName {
    final parts = name.split(':');
    return parts.first;
  }

  String get tag {
    final parts = name.split(':');
    return parts.length > 1 ? parts[1] : 'latest';
  }
}

class DeleteModelResult {
  final bool success;
  final String? error;
  final String? deletedModel;
  final String? newCurrentModel;

  DeleteModelResult({
    required this.success,
    this.error,
    this.deletedModel,
    this.newCurrentModel,
  });
}