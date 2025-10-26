/// Modelos de datos para Ollama Local (LLM ejecutándose en la máquina local)

/// Estados posibles del servicio Ollama Local
enum OllamaLocalStatus {
  /// El servicio Ollama no está ejecutándose
  stopped,
  
  /// Verificando conexión con Ollama
  connecting,
  
  /// Conectado y listo para usar
  ready,
  
  /// Ocurrió un error
  error,
}

extension OllamaLocalStatusExtension on OllamaLocalStatus {
  /// Texto descriptivo del estado
  String get displayText {
    switch (this) {
      case OllamaLocalStatus.stopped:
        return 'Detenido';
      case OllamaLocalStatus.connecting:
        return 'Conectando...';
      case OllamaLocalStatus.ready:
        return 'Listo';
      case OllamaLocalStatus.error:
        return 'Error';
    }
  }

  /// Emoji representativo del estado
  String get emoji {
    switch (this) {
      case OllamaLocalStatus.stopped:
        return '⚫';
      case OllamaLocalStatus.connecting:
        return '🟡';
      case OllamaLocalStatus.ready:
        return '🟢';
      case OllamaLocalStatus.error:
        return '🔴';
    }
  }

  /// Indica si el servicio puede usarse
  bool get isUsable => this == OllamaLocalStatus.ready;
}

/// Resultado de la inicialización de Ollama Local
class OllamaLocalInitResult {
  final bool success;
  final String? error;
  final String? modelName;
  final List<String>? availableModels;

  OllamaLocalInitResult({
    required this.success,
    this.error,
    this.modelName,
    this.availableModels,
  });

  /// Mensaje amigable para mostrar al usuario
  String get userMessage {
    if (success) {
      return '✅ Ollama Local conectado correctamente\n'
             '🤖 Modelo activo: $modelName\n'
             '📋 Modelos disponibles: ${availableModels?.length ?? 0}';
    } else {
      return '❌ Error: ${error ?? "Desconocido"}';
    }
  }
}

/// Información sobre un modelo de Ollama Local
class OllamaLocalModelInfo {
  final String name;
  final String displayName;
  final String description;
  final bool isDownloaded;
  final String size;

  OllamaLocalModelInfo({
    required this.name,
    required this.displayName,
    required this.description,
    required this.isDownloaded,
    required this.size,
  });

  /// Modelos recomendados para Ollama Local
  static List<OllamaLocalModelInfo> get recommendedModels => [
    OllamaLocalModelInfo(
      name: 'phi3',
      displayName: 'Phi-3 Mini',
      description: 'Modelo ligero de Microsoft (3.8B parámetros)\n'
                   'Rápido y eficiente para uso local',
      isDownloaded: false,
      size: '2.3 GB',
    ),
    OllamaLocalModelInfo(
      name: 'mistral',
      displayName: 'Mistral 7B',
      description: 'Modelo de alto rendimiento (7B parámetros)\n'
                   'Excelente balance entre calidad y velocidad',
      isDownloaded: false,
      size: '4.1 GB',
    ),
    OllamaLocalModelInfo(
      name: 'llama3.2',
      displayName: 'Llama 3.2',
      description: 'Modelo de Meta (3B parámetros)\n'
                   'Muy eficiente para tareas generales',
      isDownloaded: false,
      size: '2.0 GB',
    ),
    OllamaLocalModelInfo(
      name: 'gemma2:2b',
      displayName: 'Gemma 2 2B',
      description: 'Modelo de Google (2B parámetros)\n'
                   'Ultraligero y rápido',
      isDownloaded: false,
      size: '1.6 GB',
    ),
  ];
}

/// Excepción personalizada para errores de Ollama Local
class OllamaLocalException implements Exception {
  final String message;
  final String? details;

  OllamaLocalException(this.message, {this.details});

  @override
  String toString() => 'OllamaLocalException: $message${details != null ? '\nDetalles: $details' : ''}';

  /// Mensaje amigable para el usuario
  String get userFriendlyMessage {
    switch (message) {
      case 'Ollama no está ejecutándose':
        return '❌ Ollama no está ejecutándose en tu computadora\n\n'
               '💡 Solución:\n'
               '1. Abre PowerShell o Terminal\n'
               '2. Ejecuta: ollama serve\n'
               '3. Mantén la terminal abierta\n'
               '4. Intenta conectar de nuevo';
      
      case 'Modelo no encontrado':
        return '❌ El modelo "$details" no está descargado\n\n'
               '💡 Solución:\n'
               '1. Abre PowerShell o Terminal\n'
               '2. Ejecuta: ollama pull $details\n'
               '3. Espera a que termine la descarga\n'
               '4. Intenta de nuevo';
      
      case 'Error de conexión':
        return '❌ No se pudo conectar a Ollama\n\n'
               '💡 Soluciones:\n'
               '• Verifica que Ollama esté ejecutándose (ollama serve)\n'
               '• Comprueba que no haya un firewall bloqueando el puerto 11434\n'
               '• Reinicia Ollama';
      
      case 'Timeout':
        return '❌ Ollama tardó demasiado en responder\n\n'
               '💡 Posibles causas:\n'
               '• El modelo se está cargando por primera vez (puede tardar)\n'
               '• Tu computadora necesita más recursos\n'
               '• El prompt es muy complejo\n\n'
               'Intenta de nuevo en unos segundos';
      
      default:
        return '❌ $message\n\n${details ?? ""}';
    }
  }
}

/// Configuración de Ollama Local
class OllamaLocalConfig {
  final String baseUrl;
  final String defaultModel;
  final double temperature;
  final int maxTokens;
  final Duration timeout;

  const OllamaLocalConfig({
    this.baseUrl = 'http://localhost:11434',
    this.defaultModel = 'phi3',
    this.temperature = 0.7,
    this.maxTokens = 2048,
    this.timeout = const Duration(seconds: 60),
  });

  OllamaLocalConfig copyWith({
    String? baseUrl,
    String? defaultModel,
    double? temperature,
    int? maxTokens,
    Duration? timeout,
  }) {
    return OllamaLocalConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      defaultModel: defaultModel ?? this.defaultModel,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      timeout: timeout ?? this.timeout,
    );
  }
}