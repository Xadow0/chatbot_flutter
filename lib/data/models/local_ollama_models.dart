/// Modelos de datos para Ollama Local Gestionado (instalación automática)
library;

import '../../domain/entities/local_ollama_entity.dart';

/// Estados del servicio Ollama local
enum LocalOllamaStatus {
  /// No inicializado
  notInitialized,
  
  /// Verificando si Ollama está instalado
  checkingInstallation,
  
  /// Descargando instalador de Ollama
  downloadingInstaller,
  
  /// Instalando Ollama
  installing,
  
  /// Descargando modelo de IA
  downloadingModel,
  
  /// Iniciando servidor Ollama
  starting,

  loading,
  
  /// Listo para usar
  ready,
  
  /// Error en el proceso
  error,
}

extension LocalOllamaStatusExtension on LocalOllamaStatus {
  String get displayText {
    switch (this) {
      case LocalOllamaStatus.notInitialized:
        return 'No inicializado';
      case LocalOllamaStatus.checkingInstallation:
        return 'Verificando instalación...';
      case LocalOllamaStatus.downloadingInstaller:
        return 'Descargando Ollama...';
      case LocalOllamaStatus.installing:
        return 'Instalando Ollama...';
      case LocalOllamaStatus.downloadingModel:
        return 'Descargando modelo de IA...';
      case LocalOllamaStatus.starting:
        return 'Iniciando servidor...';
      case LocalOllamaStatus.loading:
        return 'Cargando modelo...';
      case LocalOllamaStatus.ready:
        return 'Listo';
      case LocalOllamaStatus.error:
        return 'Error';
    }
  }

  String get emoji {
    switch (this) {
      case LocalOllamaStatus.notInitialized:
        return '⚫';
      case LocalOllamaStatus.checkingInstallation:
      case LocalOllamaStatus.downloadingInstaller:
      case LocalOllamaStatus.installing:
      case LocalOllamaStatus.downloadingModel:
      case LocalOllamaStatus.starting:
      case LocalOllamaStatus.loading:
        return '🟡';
      case LocalOllamaStatus.ready:
        return '🟢';
      case LocalOllamaStatus.error:
        return '🔴';
    }
  }

  bool get isUsable => this == LocalOllamaStatus.ready;
  
  bool get isProcessing {
    return this == LocalOllamaStatus.checkingInstallation ||
           this == LocalOllamaStatus.downloadingInstaller ||
           this == LocalOllamaStatus.installing ||
           this == LocalOllamaStatus.downloadingModel ||
           this == LocalOllamaStatus.starting ||
           this == LocalOllamaStatus.loading;
  }

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  LocalOllamaStatusEntity toEntity() {
    switch (this) {
      case LocalOllamaStatus.notInitialized:
        return LocalOllamaStatusEntity.notInitialized;
      case LocalOllamaStatus.checkingInstallation:
        return LocalOllamaStatusEntity.checkingInstallation;
      case LocalOllamaStatus.downloadingInstaller:
        return LocalOllamaStatusEntity.downloadingInstaller;
      case LocalOllamaStatus.installing:
        return LocalOllamaStatusEntity.installing;
      case LocalOllamaStatus.downloadingModel:
        return LocalOllamaStatusEntity.downloadingModel;
      case LocalOllamaStatus.starting:
        return LocalOllamaStatusEntity.starting;
      case LocalOllamaStatus.loading:
        return LocalOllamaStatusEntity.loading;
      case LocalOllamaStatus.ready:
        return LocalOllamaStatusEntity.ready;
      case LocalOllamaStatus.error:
        return LocalOllamaStatusEntity.error;
    }
  }

  static LocalOllamaStatus fromEntity(LocalOllamaStatusEntity entity) {
    switch (entity) {
      case LocalOllamaStatusEntity.notInitialized:
        return LocalOllamaStatus.notInitialized;
      case LocalOllamaStatusEntity.checkingInstallation:
        return LocalOllamaStatus.checkingInstallation;
      case LocalOllamaStatusEntity.downloadingInstaller:
        return LocalOllamaStatus.downloadingInstaller;
      case LocalOllamaStatusEntity.installing:
        return LocalOllamaStatus.installing;
      case LocalOllamaStatusEntity.downloadingModel:
        return LocalOllamaStatus.downloadingModel;
      case LocalOllamaStatusEntity.starting:
        return LocalOllamaStatus.starting;
      case LocalOllamaStatusEntity.loading:
        return LocalOllamaStatus.loading;
      case LocalOllamaStatusEntity.ready:
        return LocalOllamaStatus.ready;
      case LocalOllamaStatusEntity.error:
        return LocalOllamaStatus.error;
    }
  }
}

/// Información sobre la instalación de Ollama
class OllamaInstallationInfo {
  final bool isInstalled;
  final String? installPath;
  final String? version;
  final bool canExecute;

  OllamaInstallationInfo({
    required this.isInstalled,
    this.installPath,
    this.version,
    required this.canExecute,
  });

  bool get needsInstallation => !isInstalled || !canExecute;

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  OllamaInstallationInfoEntity toEntity() {
    return OllamaInstallationInfoEntity(
      isInstalled: isInstalled,
      installPath: installPath,
      version: version,
      canExecute: canExecute,
    );
  }

  factory OllamaInstallationInfo.fromEntity(OllamaInstallationInfoEntity entity) {
    return OllamaInstallationInfo(
      isInstalled: entity.isInstalled,
      installPath: entity.installPath,
      version: entity.version,
      canExecute: entity.canExecute,
    );
  }
}

/// Progreso de descarga/instalación
class LocalOllamaInstallProgress {
  final LocalOllamaStatus status;
  final double progress; // 0.0 - 1.0
  final String? message;
  final int? bytesDownloaded;
  final int? totalBytes;

  LocalOllamaInstallProgress({
    required this.status,
    required this.progress,
    this.message,
    this.bytesDownloaded,
    this.totalBytes,
  });

  String get progressText {
    if (bytesDownloaded != null && totalBytes != null) {
      final downloadedMB = (bytesDownloaded! / 1024 / 1024).toStringAsFixed(1);
      final totalMB = (totalBytes! / 1024 / 1024).toStringAsFixed(1);
      return '$downloadedMB MB / $totalMB MB';
    }
    
    final percent = (progress * 100).toStringAsFixed(0);
    return '$percent%';
  }

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  LocalOllamaInstallProgressEntity toEntity() {
    return LocalOllamaInstallProgressEntity(
      status: status.toEntity(),
      progress: progress,
      message: message,
      bytesDownloaded: bytesDownloaded,
      totalBytes: totalBytes,
    );
  }

  factory LocalOllamaInstallProgress.fromEntity(
      LocalOllamaInstallProgressEntity entity) {
    return LocalOllamaInstallProgress(
      status: LocalOllamaStatusExtension.fromEntity(entity.status),
      progress: entity.progress,
      message: entity.message,
      bytesDownloaded: entity.bytesDownloaded,
      totalBytes: entity.totalBytes,
    );
  }
}

/// Resultado de inicialización del servicio local
class LocalOllamaInitResult {
  final bool success;
  final String? error;
  final String? modelName;
  final List<String>? availableModels;
  final Duration? initTime;
  final bool wasNewInstallation;

  LocalOllamaInitResult({
    required this.success,
    this.error,
    this.modelName,
    this.availableModels,
    this.initTime,
    this.wasNewInstallation = false,
  });

  String get userMessage {
    if (success) {
      final installMsg = wasNewInstallation 
          ? '✅ Ollama instalado correctamente\n' 
          : '✅ Conectado a Ollama local\n';
      
      return '$installMsg'
             '🤖 Modelo activo: $modelName\n'
             '📋 Modelos disponibles: ${availableModels?.length ?? 0}\n'
             '⏱️ Tiempo: ${initTime?.inSeconds ?? 0}s';
    } else {
      return '❌ Error: ${error ?? "Desconocido"}';
    }
  }

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  LocalOllamaInitResultEntity toEntity() {
    return LocalOllamaInitResultEntity(
      success: success,
      error: error,
      modelName: modelName,
      availableModels: availableModels,
      initTime: initTime,
      wasNewInstallation: wasNewInstallation,
    );
  }

  factory LocalOllamaInitResult.fromEntity(LocalOllamaInitResultEntity entity) {
    return LocalOllamaInitResult(
      success: entity.success,
      error: entity.error,
      modelName: entity.modelName,
      availableModels: entity.availableModels,
      initTime: entity.initTime,
      wasNewInstallation: entity.wasNewInstallation,
    );
  }
}

/// Información sobre un modelo de Ollama
class LocalOllamaModel {
  final String name;
  final String displayName;
  final String description;
  final bool isDownloaded; // Esto se gestionará dinámicamente en la UI/Servicio
  final String estimatedSize;
  final bool isRecommended;
  final int parametersB;

  LocalOllamaModel({
    required this.name,
    required this.displayName,
    required this.description,
    required this.isDownloaded,
    required this.estimatedSize,
    this.isRecommended = false,
    required this.parametersB,
  });

  /// Modelos recomendados para uso local (Actualizado 2025)
  static List<LocalOllamaModel> get recommendedModels => [
    // --- LIGEROS (< 3GB) ---
    LocalOllamaModel(
      name: 'gemma2:2b',
      displayName: 'Google Gemma 2 (2B)',
      description: 'Ultraligero y muy rápido. Ideal para dispositivos con poca RAM.',
      isDownloaded: false,
      estimatedSize: '1.6 GB',
      parametersB: 2,
    ),
    LocalOllamaModel(
      name: 'llama3.2', 
      displayName: 'Llama 3.2 (3B)',
      description: 'El estándar de eficiencia de Meta. Gran equilibrio velocidad/calidad.',
      isDownloaded: false,
      estimatedSize: '2.0 GB',
      isRecommended: true,
      parametersB: 3,
    ),

    // --- POTENCIA MEDIA (4GB - 6GB) ---
    LocalOllamaModel(
      name: 'qwen2.5:7b',
      displayName: 'Qwen 2.5 (7B)',
      description: 'Rey del código y lógica matemática. Excelente soporte en español.',
      isDownloaded: false,
      estimatedSize: '4.7 GB',
      isRecommended: true,
      parametersB: 7,
    ),
    LocalOllamaModel(
      name: 'gemma2:9b',
      displayName: 'Google Gemma 2 (9B)',
      description: 'Razonamiento superior. Compite con modelos mucho más grandes.',
      isDownloaded: false,
      estimatedSize: '5.4 GB',
      parametersB: 9,
    ),

    // --- ALTA CAPACIDAD (> 7GB) ---
    LocalOllamaModel(
      name: 'mistral-nemo', 
      displayName: 'Mistral Nemo (12B)',
      description: 'Ventana de contexto grande. Ideal para textos largos y RAG.',
      isDownloaded: false,
      estimatedSize: '7.1 GB',
      parametersB: 12,
    ),
  ];

  /// Obtener modelo por defecto
  static String get defaultModel => 'llama3.2';

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  LocalOllamaModelEntity toEntity() {
    return LocalOllamaModelEntity(
      name: name,
      displayName: displayName,
      description: description,
      isDownloaded: isDownloaded,
      estimatedSize: estimatedSize,
      isRecommended: isRecommended,
      parametersB: parametersB,
    );
  }

  factory LocalOllamaModel.fromEntity(LocalOllamaModelEntity entity) {
    return LocalOllamaModel(
      name: entity.name,
      displayName: entity.displayName,
      description: entity.description,
      isDownloaded: entity.isDownloaded,
      estimatedSize: entity.estimatedSize,
      isRecommended: entity.isRecommended,
      parametersB: entity.parametersB,
    );
  }
}

/// Configuración de Ollama local
class LocalOllamaConfig {
  final String baseUrl;
  final int port;
  final double temperature;
  final int maxTokens;
  final Duration timeout;

  const LocalOllamaConfig({
    this.baseUrl = 'http://localhost',
    this.port = 11434,
    this.temperature = 0.7,
    this.maxTokens = 4096,
    this.timeout = const Duration(seconds: 240),
  });

  String get fullBaseUrl => '$baseUrl:$port';

  LocalOllamaConfig copyWith({
    String? baseUrl,
    int? port,
    double? temperature,
    int? maxTokens,
    Duration? timeout,
  }) {
    return LocalOllamaConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      port: port ?? this.port,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      timeout: timeout ?? this.timeout,
    );
  }

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  LocalOllamaConfigEntity toEntity() {
    return LocalOllamaConfigEntity(
      baseUrl: baseUrl,
      port: port,
      temperature: temperature,
      maxTokens: maxTokens,
      timeout: timeout,
    );
  }

  factory LocalOllamaConfig.fromEntity(LocalOllamaConfigEntity entity) {
    return LocalOllamaConfig(
      baseUrl: entity.baseUrl,
      port: entity.port,
      temperature: entity.temperature,
      maxTokens: entity.maxTokens,
      timeout: entity.timeout,
    );
  }
}

/// Excepción para errores de Ollama local
class LocalOllamaException implements Exception {
  final String message;
  final String? details;

  LocalOllamaException(this.message, {this.details});

  @override
  String toString() =>
      'LocalOllamaException: $message${details != null ? '\nDetalles: $details' : ''}';

  String get userFriendlyMessage {
    switch (message) {
      case 'Error descargando instalador':
        return '❌ No se pudo descargar Ollama\n\n'
               'Posibles causas:\n'
               '• Sin conexión a internet\n'
               '• Firewall bloqueando la descarga\n'
               '• Servidor de Ollama no disponible\n\n'
               '💡 Verifica tu conexión e intenta nuevamente';

      case 'Error instalando Ollama':
        return '❌ No se pudo instalar Ollama\n\n'
               '${details ?? ""}\n\n'
               'Posibles causas:\n'
               '• Permisos insuficientes\n'
               '• Espacio en disco insuficiente (~500MB)\n'
               '• Antivirus bloqueando instalación\n\n'
               '💡 Ejecuta la aplicación como administrador';

      case 'Ollama no responde':
        return '❌ Ollama no está respondiendo\n\n'
               'El servicio está instalado pero no responde.\n\n'
               '💡 Soluciones:\n'
               '• Reinicia la aplicación\n'
               '• Verifica que no haya otro Ollama ejecutándose\n'
               '• Revisa que el puerto 11434 esté libre';

      case 'Error descargando modelo':
        return '❌ No se pudo descargar el modelo de IA\n\n'
               '${details ?? ""}\n\n'
               'Posibles causas:\n'
               '• Espacio insuficiente (~2-4GB requeridos)\n'
               '• Conexión interrumpida\n'
               '• Servidor no disponible\n\n'
               '💡 Verifica espacio en disco e intenta nuevamente';

      case 'Puerto en uso':
        return '❌ El puerto 11434 ya está en uso\n\n'
               'Hay otra aplicación usando el puerto de Ollama.\n\n'
               '💡 Soluciones:\n'
               '• Cierra otras instancias de Ollama\n'
               '• Reinicia tu computadora\n'
               '• Usa el Ollama que ya está ejecutándose';

      case 'Timeout':
        return '⏱️ La operación tardó demasiado\n\n'
               'Ollama no respondió a tiempo.\n\n'
               '💡 Posibles causas:\n'
               '• El modelo es muy grande para tu hardware\n'
               '• Falta de recursos (RAM/CPU)\n'
               '• Primera ejecución (tarda más)\n\n'
               'Intenta con un modelo más pequeño';

      default:
        return '❌ $message\n\n${details ?? ""}';
    }
  }
}