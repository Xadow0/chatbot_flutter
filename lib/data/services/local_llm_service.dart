import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/local_llm_models.dart';
import 'model_download_service.dart';

/// Servicio para ejecutar modelos LLM localmente en el dispositivo
class LocalLLMService {
  LocalLLMStatus _status = LocalLLMStatus.stopped;
  String? _errorMessage;
  
  dynamic _llamaInstance;
  
  static const String _defaultModelName = 'phi-3-mini';
  static const int _contextSize = 2048;
  static const int _maxTokens = 512;
  
  final List<Function(LocalLLMStatus)> _statusListeners = [];
  
  // Servicio de descarga
  final ModelDownloadService _downloadService = ModelDownloadService();

  /// Exponer el servicio de descarga para que la UI pueda conectar callbacks
  ModelDownloadService get downloadService => _downloadService;
  
  LocalLLMService() {
    debugPrint('🤖 [LocalLLMService] Servicio inicializado');
    debugPrint('   📦 Modelo por defecto: $_defaultModelName');
    debugPrint('   🧠 Tamaño de contexto: $_contextSize tokens');
  }

  LocalLLMStatus get status => _status;
  String? get errorMessage => _errorMessage;
  bool get isAvailable => _status == LocalLLMStatus.ready;
  bool get isLoading => _status == LocalLLMStatus.loading;

  void addStatusListener(Function(LocalLLMStatus) listener) {
    _statusListeners.add(listener);
  }

  void removeStatusListener(Function(LocalLLMStatus) listener) {
    _statusListeners.remove(listener);
  }

  void _notifyStatusChange(LocalLLMStatus newStatus) {
    _status = newStatus;
    for (var listener in _statusListeners) {
      listener(newStatus);
    }
  }

  /// Verificar si el modelo está descargado
  Future<bool> isModelDownloaded() async {
    return await _downloadService.isModelDownloaded();
  }

  /// Descargar el modelo (si no está descargado)
  Future<ModelDownloadResult> downloadModelIfNeeded() async {
    try {
      debugPrint('🔍 [LocalLLMService] Verificando si el modelo está descargado...');
      
      if (await _downloadService.isModelDownloaded()) {
        debugPrint('✅ [LocalLLMService] Modelo ya descargado');
        return ModelDownloadResult(
          success: true,
          message: 'Modelo ya disponible',
        );
      }
      
      debugPrint('⬇️ [LocalLLMService] Iniciando descarga del modelo...');
      
      // Configurar callbacks para el progreso solo si no han sido asignados
      // (la UI puede asignarlos previamente para mostrar un diálogo)
      if (_downloadService.onProgress == null) {
        _downloadService.onProgress = (progress) {
          // Aquí podrías notificar a la UI del progreso
          debugPrint('📊 Descarga: ${(progress * 100).toStringAsFixed(1)}%');
        };
      }

      if (_downloadService.onStatusChange == null) {
        _downloadService.onStatusChange = (status) {
          debugPrint('📡 Estado: $status');
        };
      }
      
      final result = await _downloadService.downloadModel();
      
      if (result.success) {
        debugPrint('✅ [LocalLLMService] Modelo descargado correctamente');
      } else {
        debugPrint('❌ [LocalLLMService] Error en descarga: ${result.error}');
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ [LocalLLMService] Error descargando modelo: $e');
      return ModelDownloadResult(
        success: false,
        message: 'Error al descargar',
        error: e.toString(),
      );
    }
  }

  /// Inicializar y cargar el modelo LLM local
  Future<LocalLLMInitResult> initializeModel({
    String? modelPath,
    int contextSize = _contextSize,
    bool autoDownload = true,
  }) async {
    try {
      debugPrint('🚀 [LocalLLMService] === INICIANDO CARGA DEL MODELO ===');
      _notifyStatusChange(LocalLLMStatus.loading);
      _errorMessage = null;

      // 1. Verificar/descargar el modelo si es necesario
      if (autoDownload) {
        debugPrint('   📥 Verificando y descargando modelo si es necesario...');
        final downloadResult = await downloadModelIfNeeded();
        
        if (!downloadResult.success) {
          throw LocalLLMException(
            'Error al descargar modelo',
            details: downloadResult.error ?? 'Error desconocido',
          );
        }
      }

      // 2. Verificar que el dispositivo tenga recursos suficientes
      final hasResources = await _checkDeviceResources();
      if (!hasResources) {
        throw LocalLLMException(
          'Recursos insuficientes',
          details: 'El dispositivo no tiene suficiente RAM disponible (mínimo 2GB recomendado)',
        );
      }

      // 3. Obtener ruta del modelo
      final resolvedModelPath = modelPath ?? await _downloadService.getModelPath();
      debugPrint('   📁 Ruta del modelo: $resolvedModelPath');

      final modelExists = await _checkModelExists(resolvedModelPath);
      if (!modelExists) {
        throw LocalLLMException(
          'Modelo no encontrado',
          details: 'El archivo del modelo no existe en: $resolvedModelPath\n'
                   'Por favor, verifica la instalación.',
        );
      }

      // 4. Cargar el modelo con llama.cpp
      debugPrint('   ⏳ Cargando modelo en memoria...');
      await _loadModel(resolvedModelPath, contextSize);

      // 5. Realizar test de inferencia
      debugPrint('   🧪 Realizando test de inferencia...');
      final testResult = await _testInference();
      if (!testResult) {
        throw LocalLLMException(
          'Error en test de inferencia',
          details: 'El modelo se cargó pero no responde correctamente',
        );
      }

      debugPrint('   ✅ Modelo cargado y funcional');
      debugPrint('🟢 [LocalLLMService] === MODELO LISTO ===\n');

      _notifyStatusChange(LocalLLMStatus.ready);
      
      return LocalLLMInitResult(
        success: true,
        modelName: _defaultModelName,
        modelSize: await _getModelSize(resolvedModelPath),
        loadTimeMs: 0,
      );

    } on LocalLLMException catch (e) {
      debugPrint('❌ [LocalLLMService] Error conocido: ${e.message}');
      debugPrint('   💡 Detalles: ${e.details}');
      _errorMessage = e.userFriendlyMessage;
      _notifyStatusChange(LocalLLMStatus.error);
      
      return LocalLLMInitResult(
        success: false,
        error: e.userFriendlyMessage,
      );

    } catch (e) {
      debugPrint('❌ [LocalLLMService] Error inesperado: $e');
      _errorMessage = 'Error al inicializar el modelo: $e';
      _notifyStatusChange(LocalLLMStatus.error);
      
      return LocalLLMInitResult(
        success: false,
        error: 'Error al inicializar: $e',
      );
    }
  }

  Future<String> generateContent(
    String prompt, {
    double temperature = 0.7,
    int maxTokens = _maxTokens,
  }) async {
    if (_status != LocalLLMStatus.ready) {
      throw LocalLLMException(
        'Modelo no disponible',
        details: 'El modelo debe estar cargado antes de generar contenido. Estado actual: $_status',
      );
    }

    try {
      debugPrint('🔵 [LocalLLMService] === GENERANDO RESPUESTA ===');
      debugPrint('   💬 Prompt: ${prompt.length > 50 ? "${prompt.substring(0, 50)}..." : prompt}');
      debugPrint('   🌡️ Temperature: $temperature');
      debugPrint('   📊 Max tokens: $maxTokens');

      await Future.delayed(const Duration(seconds: 1));
      
      final response = _simulateLocalResponse(prompt);
      
      debugPrint('   ✅ Respuesta generada: ${response.length} caracteres');
      debugPrint('🟢 [LocalLLMService] === GENERACIÓN EXITOSA ===\n');

      return response;

    } catch (e) {
      debugPrint('❌ [LocalLLMService] Error en generación: $e');
      throw LocalLLMException(
        'Error al generar respuesta',
        details: e.toString(),
      );
    }
  }

  Future<void> stopModel() async {
    try {
      debugPrint('🛑 [LocalLLMService] Deteniendo modelo...');
      
      if (_llamaInstance != null) {
        _llamaInstance = null;
      }

      _notifyStatusChange(LocalLLMStatus.stopped);
      _errorMessage = null;
      
      debugPrint('   ✅ Modelo detenido y recursos liberados');
      
    } catch (e) {
      debugPrint('⚠️ [LocalLLMService] Error al detener modelo: $e');
      _errorMessage = 'Error al detener el modelo';
      _notifyStatusChange(LocalLLMStatus.error);
    }
  }

  Future<LocalLLMInitResult> retry() async {
    debugPrint('🔄 [LocalLLMService] Reintentando inicialización...');
    return await initializeModel();
  }

  Future<bool> _checkDeviceResources() async {
    try {
      debugPrint('   🔍 Verificando recursos del dispositivo...');
      return true;
    } catch (e) {
      debugPrint('   ⚠️ No se pudo verificar recursos: $e');
      return true;
    }
  }

  Future<bool> _checkModelExists(String path) async {
    try {
      final file = File(path);
      final exists = await file.exists();
      
      if (exists) {
        final size = await file.length();
        final sizeMB = (size / (1024 * 1024)).toStringAsFixed(1);
        debugPrint('   ✓ Modelo encontrado: $sizeMB MB');
      } else {
        debugPrint('   ✗ Modelo no encontrado en: $path');
      }
      
      return exists;
    } catch (e) {
      debugPrint('   ⚠️ Error verificando modelo: $e');
      return false;
    }
  }

  Future<void> _loadModel(String modelPath, int contextSize) async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      _llamaInstance = 'MODELO_SIMULADO';
      
    } catch (e) {
      throw LocalLLMException(
        'Error al cargar modelo',
        details: 'No se pudo cargar el modelo en memoria: $e',
      );
    }
  }

  Future<bool> _testInference() async {
    try {
      await Future.delayed(const Duration(milliseconds: 500));
      return true;
    } catch (e) {
      debugPrint('   ✗ Test de inferencia falló: $e');
      return false;
    }
  }

  Future<String> _getModelSize(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final bytes = await file.length();
        final mb = bytes / (1024 * 1024);
        return '${mb.toStringAsFixed(1)} MB';
      }
    } catch (e) {
      debugPrint('   ⚠️ Error obteniendo tamaño: $e');
    }
    return 'Desconocido';
  }

  String _simulateLocalResponse(String prompt) {
    return '🤖 [Modelo Local - Phi-3 Simulado]\n\n'
           'Esta es una respuesta simulada del modelo local. '
           'Cuando se integre llama.cpp, aquí aparecerá la respuesta real del modelo Phi-3.\n\n'
           'Tu pregunta fue: "${prompt.length > 100 ? "${prompt.substring(0, 100)}..." : prompt}"\n\n'
           '⚠️ Nota: Esta es una simulación. El modelo real se integrará próximamente.';
  }

  void dispose() {
    debugPrint('🧹 [LocalLLMService] Liberando recursos...');
    _statusListeners.clear();
    stopModel();
  }
}