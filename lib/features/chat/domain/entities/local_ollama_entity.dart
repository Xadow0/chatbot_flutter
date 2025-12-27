/// Entidad de dominio para el estado de Ollama Local
/// 
/// Representa el estado del servicio Ollama local instalado en el dispositivo.
enum LocalOllamaStatusEntity {
  notInitialized,
  checkingInstallation,
  downloadingInstaller,
  installing,
  downloadingModel,
  starting,
  loading,
  ready,
  error,
}

extension LocalOllamaStatusEntityExtension on LocalOllamaStatusEntity {
  String get displayText {
    switch (this) {
      case LocalOllamaStatusEntity.notInitialized:
        return 'No inicializado';
      case LocalOllamaStatusEntity.checkingInstallation:
        return 'Verificando instalación...';
      case LocalOllamaStatusEntity.downloadingInstaller:
        return 'Descargando Ollama...';
      case LocalOllamaStatusEntity.installing:
        return 'Instalando Ollama...';
      case LocalOllamaStatusEntity.downloadingModel:
        return 'Descargando modelo de IA...';
      case LocalOllamaStatusEntity.starting:
        return 'Iniciando servidor...';
      case LocalOllamaStatusEntity.loading:
        return 'Cargando modelo...';
      case LocalOllamaStatusEntity.ready:
        return 'Listo';
      case LocalOllamaStatusEntity.error:
        return 'Error';
    }
  }

  String get emoji {
    switch (this) {
      case LocalOllamaStatusEntity.notInitialized:
        return '⚫';
      case LocalOllamaStatusEntity.checkingInstallation:
      case LocalOllamaStatusEntity.downloadingInstaller:
      case LocalOllamaStatusEntity.installing:
      case LocalOllamaStatusEntity.downloadingModel:
      case LocalOllamaStatusEntity.starting:
      case LocalOllamaStatusEntity.loading:
        return '🟡';
      case LocalOllamaStatusEntity.ready:
        return '🟢';
      case LocalOllamaStatusEntity.error:
        return '🔴';
    }
  }

  bool get isUsable => this == LocalOllamaStatusEntity.ready;

  bool get isProcessing {
    return this == LocalOllamaStatusEntity.checkingInstallation ||
        this == LocalOllamaStatusEntity.downloadingInstaller ||
        this == LocalOllamaStatusEntity.installing ||
        this == LocalOllamaStatusEntity.downloadingModel ||
        this == LocalOllamaStatusEntity.starting ||
        this == LocalOllamaStatusEntity.loading;
  }
}

/// Entidad de dominio para información de instalación de Ollama
class OllamaInstallationInfoEntity {
  final bool isInstalled;
  final String? installPath;
  final String? version;
  final bool canExecute;

  const OllamaInstallationInfoEntity({
    required this.isInstalled,
    this.installPath,
    this.version,
    required this.canExecute,
  });

  bool get needsInstallation => !isInstalled || !canExecute;

  OllamaInstallationInfoEntity copyWith({
    bool? isInstalled,
    String? installPath,
    String? version,
    bool? canExecute,
  }) {
    return OllamaInstallationInfoEntity(
      isInstalled: isInstalled ?? this.isInstalled,
      installPath: installPath ?? this.installPath,
      version: version ?? this.version,
      canExecute: canExecute ?? this.canExecute,
    );
  }
}

/// Entidad de dominio para progreso de instalación
class LocalOllamaInstallProgressEntity {
  final LocalOllamaStatusEntity status;
  final double progress;
  final String? message;
  final int? bytesDownloaded;
  final int? totalBytes;

  const LocalOllamaInstallProgressEntity({
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

  LocalOllamaInstallProgressEntity copyWith({
    LocalOllamaStatusEntity? status,
    double? progress,
    String? message,
    int? bytesDownloaded,
    int? totalBytes,
  }) {
    return LocalOllamaInstallProgressEntity(
      status: status ?? this.status,
      progress: progress ?? this.progress,
      message: message ?? this.message,
      bytesDownloaded: bytesDownloaded ?? this.bytesDownloaded,
      totalBytes: totalBytes ?? this.totalBytes,
    );
  }
}

/// Entidad de dominio para el resultado de inicialización
class LocalOllamaInitResultEntity {
  final bool success;
  final String? error;
  final String? modelName;
  final List<String>? availableModels;
  final Duration? initTime;
  final bool wasNewInstallation;

  const LocalOllamaInitResultEntity({
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

  LocalOllamaInitResultEntity copyWith({
    bool? success,
    String? error,
    String? modelName,
    List<String>? availableModels,
    Duration? initTime,
    bool? wasNewInstallation,
  }) {
    return LocalOllamaInitResultEntity(
      success: success ?? this.success,
      error: error ?? this.error,
      modelName: modelName ?? this.modelName,
      availableModels: availableModels ?? this.availableModels,
      initTime: initTime ?? this.initTime,
      wasNewInstallation: wasNewInstallation ?? this.wasNewInstallation,
    );
  }
}

/// Entidad de dominio para un modelo de Ollama local
class LocalOllamaModelEntity {
  final String name;
  final String displayName;
  final String description;
  final bool isDownloaded;
  final String estimatedSize;
  final bool isRecommended;
  final int parametersB;

  const LocalOllamaModelEntity({
    required this.name,
    required this.displayName,
    required this.description,
    required this.isDownloaded,
    required this.estimatedSize,
    this.isRecommended = false,
    required this.parametersB,
  });

  LocalOllamaModelEntity copyWith({
    String? name,
    String? displayName,
    String? description,
    bool? isDownloaded,
    String? estimatedSize,
    bool? isRecommended,
    int? parametersB,
  }) {
    return LocalOllamaModelEntity(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      estimatedSize: estimatedSize ?? this.estimatedSize,
      isRecommended: isRecommended ?? this.isRecommended,
      parametersB: parametersB ?? this.parametersB,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalOllamaModelEntity &&
        other.name == name &&
        other.displayName == displayName &&
        other.description == description &&
        other.isDownloaded == isDownloaded &&
        other.estimatedSize == estimatedSize &&
        other.isRecommended == isRecommended &&
        other.parametersB == parametersB;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      displayName,
      description,
      isDownloaded,
      estimatedSize,
      isRecommended,
      parametersB,
    );
  }
}

/// Entidad de dominio para configuración de Ollama local
class LocalOllamaConfigEntity {
  final String baseUrl;
  final int port;
  final double temperature;
  final int maxTokens;
  final Duration timeout;

  const LocalOllamaConfigEntity({
    this.baseUrl = 'http://localhost',
    this.port = 11434,
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.timeout = const Duration(seconds: 60),
  });

  String get fullBaseUrl => '$baseUrl:$port';

  LocalOllamaConfigEntity copyWith({
    String? baseUrl,
    int? port,
    double? temperature,
    int? maxTokens,
    Duration? timeout,
  }) {
    return LocalOllamaConfigEntity(
      baseUrl: baseUrl ?? this.baseUrl,
      port: port ?? this.port,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      timeout: timeout ?? this.timeout,
    );
  }
}