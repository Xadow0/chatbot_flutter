// lib/data/services/local_ollama_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/local_ollama_models.dart';
import 'local_ollama_installer.dart';

/// Servicio para gestionar Ollama localmente con instalación automática
/// 
/// Este servicio:
/// 1. Verifica si Ollama está instalado
/// 2. Si no está instalado, lo instala automáticamente
/// 3. Gestiona el ciclo de vida (inicio/pausa/detención)
/// 4. Descarga modelos necesarios automáticamente
/// 5. Provee API para inferencia
/// 
/// GPU es gestionada automáticamente por Ollama (sin detección manual)
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
  
  Stream<LocalOllamaInstallProgress>? _currentInstallStream;

  OllamaManagedService({LocalOllamaConfig? config})
      : _config = config ?? const LocalOllamaConfig() {
    debugPrint('🤖 [OllamaManaged] Servicio inicializado');
    debugPrint('   🔌 URL base: ${_config.fullBaseUrl}');
  }

  // Getters
  LocalOllamaStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => _status == LocalOllamaStatus.ready;
  bool get isProcessing => _status.isProcessing;
  List<String> get availableModels => _availableModels;
  String? get currentModel => _currentModel;
  String get baseUrl => _config.fullBaseUrl;
  Stream<LocalOllamaInstallProgress>? get installProgressStream => _currentInstallStream;

  // Listeners
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

  /// Inicializar el servicio completo
  /// 
  /// Flujo:
  /// 1. Verifica instalación de Ollama
  /// 2. Instala si es necesario
  /// 3. Inicia servidor
  /// 4. Descarga modelo por defecto
  /// 5. Verifica funcionamiento
  Future<LocalOllamaInitResult> initialize({String? modelName}) async {
    final startTime = DateTime.now();
    debugPrint('🚀 [OllamaManaged] ========================================');
    debugPrint('🚀 [OllamaManaged] INICIALIZANDO SERVICIO');
    debugPrint('🚀 [OllamaManaged] ========================================');
    
    try {
      _updateStatus(LocalOllamaStatus.checkingInstallation);
      
      // 1. Verificar instalación
      debugPrint('🔍 [OllamaManaged] Paso 1: Verificando instalación...');
      final installInfo = await LocalOllamaInstaller.checkInstallation();
      
      bool wasNewInstallation = false;
      
      if (installInfo.needsInstallation) {
        debugPrint('   📦 Ollama no instalado, iniciando instalación...');
        
        // 2. Instalar Ollama
        _updateStatus(LocalOllamaStatus.downloadingInstaller);
        
        final installStream = LocalOllamaInstaller.installOllama();
        _currentInstallStream = installStream;
        
        await for (var progress in installStream) {
          _updateStatus(progress.status, error: progress.message);
          _notifyInstallProgress(progress);
          
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
      
      // 3. Verificar que el servidor esté corriendo
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
        
        // Esperar a que el servidor esté completamente listo
        debugPrint('   ⏳ Esperando a que el servidor esté listo...');
        await _waitForServerReady();
      } else {
        debugPrint('   ✅ Servidor ya está corriendo');
      }
      
      // 4. Obtener modelos disponibles
      debugPrint('🔍 [OllamaManaged] Paso 3: Obteniendo modelos...');
      await _refreshAvailableModels();
      
      // 5. Asegurar que hay al menos un modelo
      final targetModel = modelName ?? LocalOllamaModel.defaultModel;
      
      final modelExists = _availableModels.any((m) => m == targetModel || m.startsWith('$targetModel:'));
      
      if (!modelExists) {
        debugPrint('   📥 Modelo $targetModel no disponible, descargando...');
        _updateStatus(LocalOllamaStatus.downloadingModel);
        
        await _downloadModel(targetModel); // Esto ahora puede ser cancelado
        
        // Si _downloadModel fue cancelado, el estado será 'error'
        // y esta parte no debería continuar.
        if (_status == LocalOllamaStatus.error) {
           throw LocalOllamaException(_errorMessage ?? 'Error desconocido durante la descarga');
        }

        debugPrint('   ✅ Descarga completada, refrescando modelos...');
        await _refreshAvailableModels();
        // ... (resto del método sin cambios) ...
      }
      
      // Asegurarse de usar el nombre correcto del modelo (con o sin :latest)
      _currentModel = _availableModels.firstWhere(
        (m) => m == targetModel || m.startsWith('$targetModel:'),
        orElse: () {
          // Si después de descargar sigue sin encontrarlo, es un error grave
          debugPrint('   ❌ ¡Error crítico! No se encontró el modelo $targetModel después de descargar');
          // Intenta usar el primero disponible para no fallar
          if (_availableModels.isNotEmpty) return _availableModels.first;
          
          throw LocalOllamaException(
            'Modelo no encontrado',
            details: 'No se encontró $targetModel ni ningún otro modelo disponible.',
          );
        },
      );
      
      debugPrint('   ✅ Modelo seleccionado: $_currentModel');
      debugPrint('   📋 Modelos disponibles: ${_availableModels.join(", ")}');
      
      // 6. IMPORTANTE: Actualizar estado a ready ANTES del test
      _updateStatus(LocalOllamaStatus.ready);
      
      // 7. Test de inferencia
      debugPrint('🔍 [OllamaManaged] Paso 4: Probando inferencia...');
      await _testInference();
      
      // 8. Éxito
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

      // Limpiar el cliente si la inicialización falla por cualquier motivo
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

  /// Esperar a que el servidor de Ollama esté completamente listo
  Future<void> _waitForServerReady({int maxAttempts = 10}) async {
    for (int i = 0; i < maxAttempts; i++) {
      try {
        final response = await http.get(
          Uri.parse('${_config.fullBaseUrl}/api/version'),
        ).timeout(const Duration(seconds: 2));
        
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

  /// Refrescar lista de modelos disponibles
  Future<void> _refreshAvailableModels() async {
    try {
      final response = await http.get(
        Uri.parse('${_config.fullBaseUrl}/api/tags'),
      ).timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final models = data['models'] as List? ?? [];
        
        _availableModels = models
            .map((m) => m['name'] as String)
            .where((name) => name.isNotEmpty)
            .toList();
        
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

  // --- MÉTODO _downloadModel COMPLETAMENTE MODIFICADO ---
  /// Descargar un modelo usando stream: true
  Future<void> _downloadModel(String modelName) async {
    debugPrint('   📥 Iniciando descarga de modelo (stream): $modelName');
    _updateStatus(LocalOllamaStatus.downloadingModel);

    final request = http.Request(
      'POST',
      Uri.parse('${_config.fullBaseUrl}/api/pull'),
    );
    request.headers['Content-Type'] = 'application/json';
    request.body = json.encode({'name': modelName, 'stream': true});
    
    // Asignar el cliente a la variable de clase
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
      final streamLines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in streamLines) {
        if (line.isEmpty) continue;
        
        try {
          final data = json.decode(line);
          
          if (data['error'] != null) {
            debugPrint('   ❌ Error en stream: ${data['error']}');
            throw LocalOllamaException( 
              'Error durante la descarga',
              details: data['error'],
            );
          }

          if (data['status'] != null) {
            // ... (lógica de progreso sin cambios) ...
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
      // --- MODIFICADO: Capturar ClientException (cancelación) ---
      if (e is http.ClientException) {
        debugPrint('   🛑 Descarga cancelada (cliente cerrado).');
        // El estado ya fue (o será) actualizado por cancelModelDownload()
        // Simplemente salimos sin lanzar un nuevo error.
        return;
      }
      // --- FIN MODIFICACIÓN ---
      
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
      // Limpiar el cliente
      _downloadClient?.close();
      _downloadClient = null;
    }
  }

  /// Cancela la descarga del modelo en curso
  void cancelModelDownload() {
    if (_status != LocalOllamaStatus.downloadingModel && 
        _status != LocalOllamaStatus.downloadingInstaller) {
      debugPrint('   ℹ️ No hay descarga activa para cancelar');
      return;
    }
    
    debugPrint('🛑 [OllamaManaged] Solicitud de cancelación de descarga...');
    
    // Cerrar el cliente HTTP. Esto causará una ClientException
    // en el stream de _downloadModel, que será capturada.
    _downloadClient?.close();
    _downloadClient = null;
    
    // Actualizar el estado para que la UI reaccione
    _updateStatus(LocalOllamaStatus.error, error: 'Descarga cancelada por el usuario');
  }

  /// Test de inferencia básico
  Future<void> _testInference() async {
    try {
      debugPrint('   🧪 Ejecutando test de inferencia...');
      debugPrint('   🤖 Usando modelo: $_currentModel');
      
      final response = await generateContent(
        'Responde solo con "OK"',
        maxTokens: 10,
      );
      
      if (response.isEmpty) {
        throw LocalOllamaException('El modelo no generó respuesta');
      }
      
      debugPrint('   ✅ Test de inferencia exitoso: ${response.trim()}');
    } catch (e) {
      debugPrint('   ❌ Test de inferencia falló: $e');
      throw LocalOllamaException(
        'Error en test de inferencia',
        details: e.toString(),
      );
    }
  }

  /// Generar contenido con el modelo
  Future<String> generateContent(
    String prompt, {
    double? temperature,
    int? maxTokens,
  }) async {
    if (!isAvailable) {
      throw LocalOllamaException(
        'Modelo no disponible',
        details: 'Estado actual: ${_status.displayText}',
      );
    }
    
    _updateLastActivity();
    
    try {
      debugPrint('💬 [OllamaManaged] Generando respuesta...');
      debugPrint('   🤖 Modelo: $_currentModel');
      debugPrint('   📝 Prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}');
      
      final response = await http.post(
        Uri.parse('${_config.fullBaseUrl}/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': _currentModel,
          'prompt': prompt,
          'stream': false,
          'options': {
            'temperature': temperature ?? _config.temperature,
            'num_predict': maxTokens ?? _config.maxTokens,
          },
        }),
      ).timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['response'] as String;
        
        debugPrint('   ✅ Respuesta generada (${content.length} chars)');
        return content;
      } else {
        throw LocalOllamaException(
          'Error HTTP ${response.statusCode}',
          details: response.body,
        );
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      if (e is LocalOllamaException) rethrow;
      throw LocalOllamaException('Error generando contenido', details: e.toString());
    }
  }

  /// Chat con historial
  Future<String> chatWithHistory({
    required String prompt,
    required List<Map<String, String>> history,
    double? temperature,
    int? maxTokens,
  }) async {
    if (!isAvailable) {
      throw LocalOllamaException(
        'Modelo no disponible',
        details: 'Estado actual: ${_status.displayText}',
      );
    }
    
    _updateLastActivity();
    
    try {
      debugPrint('💬 [OllamaManaged] Chat con historial...');
      debugPrint('   🤖 Modelo: $_currentModel');
      debugPrint('   📚 Historial: ${history.length} mensajes');
      
      // Convertir historial al formato de Ollama
      final messages = <Map<String, String>>[];
      
      // Agregar mensaje de sistema
      messages.add({
        'role': 'system',
        'content': 'Eres un asistente de IA útil y educativo.',
      });
      
      // Agregar historial
      messages.addAll(history);
      
      // Agregar nuevo prompt
      messages.add({
        'role': 'user',
        'content': prompt,
      });
      
      final response = await http.post(
        Uri.parse('${_config.fullBaseUrl}/api/chat'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': _currentModel,
          'messages': messages,
          'stream': false,
          'options': {
            'temperature': temperature ?? _config.temperature,
            'num_predict': maxTokens ?? _config.maxTokens,
          },
        }),
      ).timeout(_config.timeout);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['message']['content'] as String;
        
        debugPrint('   ✅ Respuesta generada (${content.length} chars)');
        return content;
      } else {
        throw LocalOllamaException(
          'Error HTTP ${response.statusCode}',
          details: response.body,
        );
      }
    } catch (e) {
      debugPrint('   ❌ Error: $e');
      if (e is LocalOllamaException) rethrow;
      throw LocalOllamaException('Error en chat', details: e.toString());
    }
  }

  /// Cambiar modelo activo
  Future<bool> changeModel(String modelName) async {
    debugPrint('🔄 [OllamaManaged] Solicitud para cambiar modelo a: $modelName');

    // 1. Comprobar si ya está activo
    if (_currentModel != null && (_currentModel == modelName || _currentModel!.startsWith('$modelName:'))) {
      debugPrint('   ℹ️ Modelo $modelName ya está activo.');
      // Asegurarse de que el estado sea 'listo'
      if (_status != LocalOllamaStatus.ready) {
        _updateStatus(LocalOllamaStatus.ready);
      }
      return true;
    }

    try {
      // 2. Comprobar si el modelo existe
      final modelExists = _availableModels.any((m) => m == modelName || m.startsWith('$modelName:'));

      if (!modelExists) {
        debugPrint('   📥 Modelo $modelName no encontrado localmente, descargando...');
        // El estado se actualiza a downloadingModel y se notifica el progreso
        // automáticamente desde _downloadModel
        await _downloadModel(modelName);
        await _refreshAvailableModels();
        debugPrint('   ✅ Descarga de $modelName completada.');
      } else {
        debugPrint('   ℹ️ Modelo $modelName ya está descargado.');
      }

      // 3. Encontrar el nombre completo del modelo (ej. 'llama3:latest')
      final fullModelName = _availableModels.firstWhere(
        (m) => m == modelName || m.startsWith('$modelName:'),
        orElse: () => throw LocalOllamaException('Modelo no encontrado', details: 'No se pudo encontrar $modelName después de descargar.'),
      );

      // 4. Cargar el modelo en memoria (el paso que faltaba)
      debugPrint('   ⏳ Cargando modelo $fullModelName en memoria...');
      _currentModel = fullModelName; // Asignar *antes* de testInference
      _updateStatus(LocalOllamaStatus.loading); // <<< NUEVO ESTADO
      
      await _testInference(); // Esto fuerza a Ollama a cargar el modelo

      // 5. Éxito
      debugPrint('   ✅ [OllamaManaged] Modelo cambiado y listo: $_currentModel');
      _updateStatus(LocalOllamaStatus.ready); // <<< ESTADO FINAL CORRECTO
      
      return true;

    } catch (e) {
      debugPrint('   ❌ Error en changeModel: $e');
      final errorMsg = (e is LocalOllamaException) ? e.toString() : e.toString();
      _updateStatus(LocalOllamaStatus.error, error: errorMsg);
      return false;
    }
  }

  /// Pausar servicio (liberar recursos)
  Future<void> pause() async {
    if (_status != LocalOllamaStatus.ready) return;
    
    debugPrint('⏸️ [OllamaManaged] Pausando servicio...');
    _stopHealthCheckTimer();
    _stopInactivityTimer();
    
    // El servidor sigue corriendo pero dejamos de monitorearlo
    _updateStatus(LocalOllamaStatus.notInitialized);
  }

  /// Reanudar servicio
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

  /// Detener servicio completamente
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

  /// Reintentar inicialización después de un error
  Future<LocalOllamaInitResult> retry() async {
    debugPrint('🔄 [OllamaManaged] Reintentando inicialización...');
    return await initialize(modelName: _currentModel ?? LocalOllamaModel.defaultModel);
  }

  /// Verificar salud del servicio
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('${_config.fullBaseUrl}/api/version'),
      ).timeout(const Duration(seconds: 3));
      
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
    // Timer de inactividad deshabilitado por defecto
    // Se puede habilitar si se necesita auto-pausa
  }

  void _stopInactivityTimer() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
  }

  /// Limpiar recursos
  void dispose() {
    debugPrint('🔴 [OllamaManaged] Disposing...');
    
    _stopHealthCheckTimer();
    _stopInactivityTimer();
    _statusListeners.clear();
    _installProgressListeners.clear();
  }
}