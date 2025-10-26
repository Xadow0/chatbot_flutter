/// Estados posibles del servicio LLM local
enum LocalLLMStatus {
  /// El modelo está detenido y no consume recursos
  stopped,
  
  /// El modelo se está cargando en memoria
  loading,
  
  /// El modelo está listo para generar respuestas
  ready,
  
  /// Ocurrió un error al cargar o usar el modelo
  error,
}

extension LocalLLMStatusExtension on LocalLLMStatus {
  /// Texto descriptivo del estado
  String get displayText {
    switch (this) {
      case LocalLLMStatus.stopped:
        return 'Detenido';
      case LocalLLMStatus.loading:
        return 'Cargando...';
      case LocalLLMStatus.ready:
        return 'Listo';
      case LocalLLMStatus.error:
        return 'Error';
    }
  }

  /// Emoji representativo del estado
  String get emoji {
    switch (this) {
      case LocalLLMStatus.stopped:
        return '⚫';
      case LocalLLMStatus.loading:
        return '🟡';
      case LocalLLMStatus.ready:
        return '🟢';
      case LocalLLMStatus.error:
        return '🔴';
    }
  }

  /// Indica si el servicio puede usarse
  bool get isUsable => this == LocalLLMStatus.ready;
}

/// Resultado de la inicialización del modelo local
class LocalLLMInitResult {
  final bool success;
  final String? error;
  final String? modelName;
  final String? modelSize;
  final int? loadTimeMs;

  LocalLLMInitResult({
    required this.success,
    this.error,
    this.modelName,
    this.modelSize,
    this.loadTimeMs,
  });

  /// Mensaje amigable para mostrar al usuario
  String get userMessage {
    if (success) {
      return '✅ Modelo "$modelName" cargado correctamente\n'
             '📦 Tamaño: $modelSize\n'
             '⏱️ Tiempo de carga: ${loadTimeMs}ms';
    } else {
      return '❌ Error: ${error ?? "Desconocido"}';
    }
  }
}

/// Información sobre el modelo local
class LocalLLMModelInfo {
  final String name;
  final String displayName;
  final String description;
  final String? filePath;
  final int? fileSizeBytes;
  final bool isDownloaded;
  final String? downloadUrl;

  LocalLLMModelInfo({
    required this.name,
    required this.displayName,
    required this.description,
    this.filePath,
    this.fileSizeBytes,
    required this.isDownloaded,
    this.downloadUrl,
  });

  /// Tamaño formateado del archivo
  String get sizeFormatted {
    if (fileSizeBytes == null) return 'Desconocido';
    final mb = fileSizeBytes! / (1024 * 1024);
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)} GB';
  }

  /// Modelos locales disponibles (predefinidos)
  static List<LocalLLMModelInfo> get availableModels => [
    LocalLLMModelInfo(
      name: 'phi-3-mini',
      displayName: 'Phi-3 Mini',
      description: 'Modelo ligero de Microsoft (2.7B parámetros)\n'
                   'Rápido y eficiente para dispositivos móviles',
      isDownloaded: false,
      downloadUrl: 'https://huggingface.co/microsoft/Phi-3-mini-4k-instruct-gguf',
    ),
    LocalLLMModelInfo(
      name: 'tinyllama',
      displayName: 'TinyLlama',
      description: 'Modelo ultra-ligero (1.1B parámetros)\n'
                   'Óptimo para dispositivos con recursos limitados',
      isDownloaded: false,
      downloadUrl: 'https://huggingface.co/TinyLlama/TinyLlama-1.1B-Chat-v1.0-GGUF',
    ),
    LocalLLMModelInfo(
      name: 'gemma-2b',
      displayName: 'Gemma 2B',
      description: 'Modelo de Google (2B parámetros)\n'
                   'Equilibrio entre tamaño y capacidad',
      isDownloaded: false,
      downloadUrl: 'https://huggingface.co/google/gemma-2b-it-GGUF',
    ),
  ];
}

/// Excepción personalizada para errores del LLM local
class LocalLLMException implements Exception {
  final String message;
  final String? details;

  LocalLLMException(this.message, {this.details});

  @override
  String toString() => 'LocalLLMException: $message${details != null ? '\nDetalles: $details' : ''}';

  /// Mensaje amigable para el usuario
  String get userFriendlyMessage {
    switch (message) {
      case 'Recursos insuficientes':
        return '❌ Tu dispositivo no tiene suficiente memoria RAM\n\n'
               '💡 Solución: Cierra otras aplicaciones e intenta de nuevo';
      
      case 'Modelo no encontrado':
        return '❌ El modelo no está descargado\n\n'
               '💡 Solución: Descarga el modelo Phi-3 primero\n'
               '📁 Ubicación esperada: /models/phi-3-mini-4k-instruct-q4.gguf';
      
      case 'Error al cargar modelo':
        return '❌ No se pudo cargar el modelo en memoria\n\n'
               '💡 Solución: El archivo puede estar corrupto. Descárgalo de nuevo';
      
      case 'Error en test de inferencia':
        return '❌ El modelo no responde correctamente\n\n'
               '💡 Solución: Reinicia la aplicación e intenta de nuevo';
      
      case 'Modelo no disponible':
        return '❌ El modelo debe estar cargado primero\n\n'
               '💡 Solución: Activa el modelo local desde el selector';
      
      default:
        return '❌ $message\n\n${details ?? ""}';
    }
  }
}

/// Configuración del modelo local
class LocalLLMConfig {
  final int contextSize;
  final int maxTokens;
  final double temperature;
  final int numThreads;
  final bool useGPU;

  const LocalLLMConfig({
    this.contextSize = 2048,
    this.maxTokens = 512,
    this.temperature = 0.7,
    this.numThreads = 4,
    this.useGPU = false,
  });

  LocalLLMConfig copyWith({
    int? contextSize,
    int? maxTokens,
    double? temperature,
    int? numThreads,
    bool? useGPU,
  }) {
    return LocalLLMConfig(
      contextSize: contextSize ?? this.contextSize,
      maxTokens: maxTokens ?? this.maxTokens,
      temperature: temperature ?? this.temperature,
      numThreads: numThreads ?? this.numThreads,
      useGPU: useGPU ?? this.useGPU,
    );
  }
}