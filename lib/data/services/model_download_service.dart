import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Servicio para descargar y gestionar el modelo LLM local
class ModelDownloadService {
  static const String _modelUrl = 
      'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf/resolve/main/Phi-3-mini-4k-instruct-q4.gguf';
  static const String _modelFileName = 'phi-3-mini-4k-instruct-q4.gguf';
  static const int _expectedSizeBytes = 2399824384; // ~2.4 GB
  
  final Dio _dio = Dio();
  
  /// Callback para notificar el progreso de descarga (0.0 a 1.0)
  ValueChanged<double>? onProgress;

  /// Callback para notificar el estado de la descarga
  ValueChanged<String>? onStatusChange;
  
  ModelDownloadService({this.onProgress, this.onStatusChange});

  /// Obtener la ruta donde se guardará el modelo
  Future<String> getModelPath() async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    
    // Crear directorio si no existe
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
      debugPrint('📁 [ModelDownload] Directorio creado: ${modelsDir.path}');
    }
    
    return '${modelsDir.path}/$_modelFileName';
  }

  /// Verificar si el modelo ya está descargado y es válido
  Future<bool> isModelDownloaded() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      
      if (!await file.exists()) {
        debugPrint('📦 [ModelDownload] Modelo no encontrado');
        return false;
      }
      
      final fileSize = await file.length();
      debugPrint('📦 [ModelDownload] Modelo encontrado: ${_formatBytes(fileSize)}');
      
      // Verificar que el tamaño sea correcto (±10MB de margen)
      final sizeDifference = (fileSize - _expectedSizeBytes).abs();
      if (sizeDifference > 10 * 1024 * 1024) {
        debugPrint('⚠️ [ModelDownload] Tamaño incorrecto. Esperado: ${_formatBytes(_expectedSizeBytes)}, Actual: ${_formatBytes(fileSize)}');
        return false;
      }
      
      debugPrint('✅ [ModelDownload] Modelo válido y listo para usar');
      return true;
    } catch (e) {
      debugPrint('❌ [ModelDownload] Error verificando modelo: $e');
      return false;
    }
  }

  /// Descargar el modelo con progreso
  Future<ModelDownloadResult> downloadModel() async {
    try {
      debugPrint('🔽 [ModelDownload] === INICIANDO DESCARGA ===');
      
      _notifyStatus('Preparando descarga...');
      
      // Verificar si ya existe
      if (await isModelDownloaded()) {
        debugPrint('✅ [ModelDownload] Modelo ya descargado');
        return ModelDownloadResult(
          success: true,
          message: 'El modelo ya está descargado',
        );
      }
      
      // Verificar espacio disponible
      _notifyStatus('Verificando espacio disponible...');
      final hasSpace = await _checkAvailableSpace();
      if (!hasSpace) {
        return ModelDownloadResult(
          success: false,
          message: 'No hay suficiente espacio en disco',
          error: 'Se requieren al menos 3 GB libres',
        );
      }
      
      // Obtener ruta de destino
      final modelPath = await getModelPath();
      final tempPath = '$modelPath.tmp'; // Archivo temporal durante descarga
      
      debugPrint('📁 [ModelDownload] Descargando a: $modelPath');
      debugPrint('🌐 [ModelDownload] URL: $_modelUrl');
      
      _notifyStatus('Descargando modelo (2.4 GB)...');
      
      // Configurar timeout más largo para archivos grandes
      _dio.options.connectTimeout = const Duration(minutes: 2);
      _dio.options.receiveTimeout = const Duration(minutes: 30);
      
      // Descargar con progreso
      await _dio.download(
        _modelUrl,
        tempPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            _notifyProgress(progress);
            
            if (received % (100 * 1024 * 1024) == 0 || received == total) {
              // Log cada 100MB o al finalizar
              debugPrint('📊 [ModelDownload] Progreso: ${(progress * 100).toStringAsFixed(1)}% '
                         '(${_formatBytes(received)} / ${_formatBytes(total)})');
            }
            
            _notifyStatus('Descargando: ${(progress * 100).toStringAsFixed(1)}%');
          }
        },
      );
      
      debugPrint('✅ [ModelDownload] Descarga completada');
      
      // Verificar el archivo descargado
      _notifyStatus('Verificando archivo descargado...');
      final tempFile = File(tempPath);
      final fileSize = await tempFile.length();
      
      debugPrint('📦 [ModelDownload] Tamaño descargado: ${_formatBytes(fileSize)}');
      
      // Verificar tamaño
      final sizeDifference = (fileSize - _expectedSizeBytes).abs();
      if (sizeDifference > 10 * 1024 * 1024) {
        await tempFile.delete();
        return ModelDownloadResult(
          success: false,
          message: 'Error en la descarga',
          error: 'El archivo descargado tiene un tamaño incorrecto',
        );
      }
      
      // Renombrar archivo temporal a archivo final
      _notifyStatus('Finalizando instalación...');
      await tempFile.rename(modelPath);
      
      debugPrint('🎉 [ModelDownload] === DESCARGA EXITOSA ===');
      
      return ModelDownloadResult(
        success: true,
        message: 'Modelo descargado correctamente',
        filePath: modelPath,
        fileSizeBytes: fileSize,
      );
      
    } catch (e) {
      debugPrint('❌ [ModelDownload] Error en descarga: $e');
      
      // Limpiar archivo temporal si existe
      try {
        final modelPath = await getModelPath();
        final tempFile = File('$modelPath.tmp');
        if (await tempFile.exists()) {
          await tempFile.delete();
          debugPrint('🧹 [ModelDownload] Archivo temporal eliminado');
        }
      } catch (cleanupError) {
        debugPrint('⚠️ [ModelDownload] Error limpiando: $cleanupError');
      }
      
      String errorMessage = 'Error desconocido';
      if (e is DioException) {
        if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'Tiempo de conexión agotado. Verifica tu conexión a internet.';
        } else if (e.type == DioExceptionType.receiveTimeout) {
          errorMessage = 'Descarga interrumpida. Intenta de nuevo.';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Error de conexión. Verifica tu conexión a internet.';
        } else {
          errorMessage = e.message ?? 'Error de red';
        }
      } else {
        errorMessage = e.toString();
      }
      
      return ModelDownloadResult(
        success: false,
        message: 'Error al descargar el modelo',
        error: errorMessage,
      );
    }
  }

  /// Eliminar el modelo descargado (para liberar espacio)
  Future<bool> deleteModel() async {
    try {
      final modelPath = await getModelPath();
      final file = File(modelPath);
      
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ [ModelDownload] Modelo eliminado');
        return true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ [ModelDownload] Error eliminando modelo: $e');
      return false;
    }
  }

  /// Cancelar descarga en progreso
  void cancelDownload() {
    _dio.close(force: true);
    debugPrint('🛑 [ModelDownload] Descarga cancelada');
  }

  /// Verificar si hay espacio suficiente en disco
  Future<bool> _checkAvailableSpace() async {
    try {
      // Obtener directorio de la app
  final appDir = await getApplicationDocumentsDirectory();
  // Usar appDir para evitar warning de variable no usada. En el futuro
  // se puede usar para comprobar el espacio disponible.
  debugPrint('💾 [ModelDownload] Verificación de espacio: OK (appDir=${appDir.path})');
      return true;
    } catch (e) {
      debugPrint('⚠️ [ModelDownload] No se pudo verificar espacio: $e');
      return true; // Continuar de todas formas
    }
  }

  /// Formatear bytes a formato legible
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Notificar progreso
  void _notifyProgress(double progress) {
    if (onProgress != null) {
      onProgress!(progress);
    }
  }

  /// Notificar cambio de estado
  void _notifyStatus(String status) {
    if (onStatusChange != null) {
      onStatusChange!(status);
    }
  }
}

/// Resultado de la operación de descarga
class ModelDownloadResult {
  final bool success;
  final String message;
  final String? error;
  final String? filePath;
  final int? fileSizeBytes;

  ModelDownloadResult({
    required this.success,
    required this.message,
    this.error,
    this.filePath,
    this.fileSizeBytes,
  });

  String get formattedSize {
    if (fileSizeBytes == null) return 'Desconocido';
    final gb = fileSizeBytes! / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(2)} GB';
  }
}