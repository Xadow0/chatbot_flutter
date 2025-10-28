/// Modelos de datos para Ollama Local Gestionado (instalación automática)
library;

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
           this == LocalOllamaStatus.starting;
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
}

/// Información sobre un modelo de Ollama
class LocalOllamaModel {
  final String name;
  final String displayName;
  final String description;
  final bool isDownloaded;
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

  /// Modelos recomendados para uso local
  static List<LocalOllamaModel> get recommendedModels => [
    LocalOllamaModel(
      name: 'phi3', // Nombre para 'ollama pull'
      displayName: 'Phi-3 (Rápido y Ligero)',
      description: 'Ideal para tareas rápidas. Menor precisión pero muy eficiente.',
      isDownloaded: false,
      estimatedSize: '2.3 GB',
      isRecommended: true,
      parametersB: 4,
    ),
    LocalOllamaModel(
      name: 'llama3', // Nombre para 'ollama pull'
      displayName: 'Llama 3 (Potente)',
      description: 'Resultados de mayor calidad. Requiere más recursos y una descarga más larga.',
      isDownloaded: false,
      estimatedSize: '4.7 GB',
      parametersB: 8,
    ),
  ];

  /// Obtener modelo por defecto
  static String get defaultModel => 'phi3';
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
    this.maxTokens = 2048,
    this.timeout = const Duration(seconds: 60),
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