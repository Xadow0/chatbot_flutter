/// Entidad de dominio para el estado del LLM remoto
enum LocalLLMStatusEntity {
  stopped,
  loading,
  ready,
  error,
}

extension LocalLLMStatusEntityExtension on LocalLLMStatusEntity {
  String get displayText {
    switch (this) {
      case LocalLLMStatusEntity.stopped:
        return 'Detenido';
      case LocalLLMStatusEntity.loading:
        return 'Cargando...';
      case LocalLLMStatusEntity.ready:
        return 'Listo';
      case LocalLLMStatusEntity.error:
        return 'Error';
    }
  }

  String get emoji {
    switch (this) {
      case LocalLLMStatusEntity.stopped:
        return '⚫';
      case LocalLLMStatusEntity.loading:
        return '🟡';
      case LocalLLMStatusEntity.ready:
        return '🟢';
      case LocalLLMStatusEntity.error:
        return '🔴';
    }
  }

  bool get isUsable => this == LocalLLMStatusEntity.ready;
}

/// Entidad de dominio para el resultado de inicialización del LLM
class LocalLLMInitResultEntity {
  final bool success;
  final String? error;
  final String? modelName;
  final String? modelSize;
  final int? loadTimeMs;

  const LocalLLMInitResultEntity({
    required this.success,
    this.error,
    this.modelName,
    this.modelSize,
    this.loadTimeMs,
  });

  String get userMessage {
    if (success) {
      return '✅ Modelo "$modelName" cargado correctamente\n'
          '📦 Tamaño: $modelSize\n'
          '⏱️ Tiempo de carga: ${loadTimeMs}ms';
    } else {
      return '❌ Error: ${error ?? "Desconocido"}';
    }
  }

  LocalLLMInitResultEntity copyWith({
    bool? success,
    String? error,
    String? modelName,
    String? modelSize,
    int? loadTimeMs,
  }) {
    return LocalLLMInitResultEntity(
      success: success ?? this.success,
      error: error ?? this.error,
      modelName: modelName ?? this.modelName,
      modelSize: modelSize ?? this.modelSize,
      loadTimeMs: loadTimeMs ?? this.loadTimeMs,
    );
  }
}

/// Entidad de dominio para información del modelo LLM
class LocalLLMModelInfoEntity {
  final String name;
  final String displayName;
  final String description;
  final String? filePath;
  final int? fileSizeBytes;
  final bool isDownloaded;
  final String? downloadUrl;

  const LocalLLMModelInfoEntity({
    required this.name,
    required this.displayName,
    required this.description,
    this.filePath,
    this.fileSizeBytes,
    required this.isDownloaded,
    this.downloadUrl,
  });

  String get sizeFormatted {
    if (fileSizeBytes == null) return 'Desconocido';
    final mb = fileSizeBytes! / (1024 * 1024);
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  LocalLLMModelInfoEntity copyWith({
    String? name,
    String? displayName,
    String? description,
    String? filePath,
    int? fileSizeBytes,
    bool? isDownloaded,
    String? downloadUrl,
  }) {
    return LocalLLMModelInfoEntity(
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      filePath: filePath ?? this.filePath,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isDownloaded: isDownloaded ?? this.isDownloaded,
      downloadUrl: downloadUrl ?? this.downloadUrl,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocalLLMModelInfoEntity &&
        other.name == name &&
        other.displayName == displayName &&
        other.description == description &&
        other.filePath == filePath &&
        other.fileSizeBytes == fileSizeBytes &&
        other.isDownloaded == isDownloaded &&
        other.downloadUrl == downloadUrl;
  }

  @override
  int get hashCode {
    return Object.hash(
      name,
      displayName,
      description,
      filePath,
      fileSizeBytes,
      isDownloaded,
      downloadUrl,
    );
  }
}

/// Entidad de dominio para configuración del LLM local
class LocalLLMConfigEntity {
  final int contextSize;
  final int maxTokens;
  final double temperature;
  final int numThreads;
  final bool useGPU;

  const LocalLLMConfigEntity({
    this.contextSize = 2048,
    this.maxTokens = 512,
    this.temperature = 0.7,
    this.numThreads = 4,
    this.useGPU = false,
  });

  LocalLLMConfigEntity copyWith({
    int? contextSize,
    int? maxTokens,
    double? temperature,
    int? numThreads,
    bool? useGPU,
  }) {
    return LocalLLMConfigEntity(
      contextSize: contextSize ?? this.contextSize,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      numThreads: numThreads ?? this.numThreads,
      useGPU: useGPU ?? this.useGPU,
    );
  }
}