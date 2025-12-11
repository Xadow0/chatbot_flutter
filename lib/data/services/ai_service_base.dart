/// ============================================================================
/// INTERFAZ BASE PARA SERVICIOS DE IA
/// ============================================================================
/// 
/// Define el contrato que todos los adaptadores de servicios de IA deben
/// implementar. Incluye métodos tanto para generación tradicional (bloque
/// completo) como para streaming (token por token).
/// 
/// UBICACIÓN: lib/data/services/ai_service_base.dart
/// ============================================================================
library;

/// Interfaz base para todos los servicios de IA
/// 
/// Los adaptadores (GeminiServiceAdapter, OpenAIServiceAdapter, etc.)
/// implementan esta interfaz para uniformar el acceso a diferentes
/// proveedores de IA.
abstract class AIServiceBase {
  // ==========================================================================
  // MÉTODOS DE GENERACIÓN TRADICIONAL (sin streaming)
  // ==========================================================================

  /// Genera contenido CON historial de conversación
  /// 
  /// Este método mantiene el contexto de la conversación previa,
  /// permitiendo respuestas coherentes en conversaciones multi-turno.
  /// 
  /// [prompt] El mensaje del usuario
  /// Returns: La respuesta completa del modelo
  Future<String> generateContent(String prompt);

  /// Genera contenido SIN historial de conversación
  /// 
  /// Útil para comandos y operaciones que no requieren contexto previo.
  /// Cada llamada es independiente de las anteriores.
  /// 
  /// [prompt] El mensaje/comando del usuario
  /// Returns: La respuesta completa del modelo
  Future<String> generateContentWithoutHistory(String prompt);

  // ==========================================================================
  // MÉTODOS DE GENERACIÓN CON STREAMING
  // ==========================================================================

  /// Genera contenido con streaming CON historial
  /// 
  /// El Stream emite fragmentos de texto conforme llegan del servidor.
  /// Mantiene el contexto de la conversación previa.
  /// 
  /// [prompt] El mensaje del usuario
  /// Returns: Stream de strings con fragmentos de la respuesta
  Stream<String> generateContentStream(String prompt);

  /// Genera contenido con streaming SIN historial
  /// 
  /// Para operaciones aisladas que requieren respuesta progresiva
  /// pero no necesitan contexto de conversación previo.
  /// 
  /// [prompt] El mensaje del usuario
  /// Returns: Stream de strings con fragmentos de la respuesta
  Stream<String> generateContentStreamWithoutHistory(String prompt);
}

/// ============================================================================
/// CLASES AUXILIARES PARA STREAMING (opcionales, para uso futuro)
/// ============================================================================

/// Representa un fragmento de respuesta en streaming
/// 
/// Contiene tanto el texto parcial como metadatos opcionales
/// sobre el estado del stream.
class StreamChunk {
  /// El texto recibido en este chunk
  final String text;
  
  /// Indica si este es el último chunk del stream
  final bool isComplete;
  
  /// Mensaje de error si algo salió mal (null si todo OK)
  final String? error;
  
  /// Tokens consumidos hasta ahora (si el proveedor lo reporta)
  final int? tokensUsed;

  StreamChunk({
    required this.text,
    this.isComplete = false,
    this.error,
    this.tokensUsed,
  });

  /// Crea un chunk parcial (respuesta en progreso)
  factory StreamChunk.partial(String text) => StreamChunk(text: text);
  
  /// Crea un chunk final (stream completado)
  factory StreamChunk.complete(String text) => StreamChunk(
    text: text,
    isComplete: true,
  );
  
  /// Crea un chunk de error
  factory StreamChunk.error(String errorMessage) => StreamChunk(
    text: '',
    error: errorMessage,
    isComplete: true,
  );

  /// Indica si hubo un error
  bool get hasError => error != null;

  @override
  String toString() {
    if (hasError) return 'StreamChunk.error($error)';
    if (isComplete) return 'StreamChunk.complete(${text.length} chars)';
    return 'StreamChunk.partial(${text.length} chars)';
  }
}

/// Estado del streaming para tracking en la UI
enum StreamingState {
  /// No hay streaming activo
  idle,
  
  /// Conectando con el servidor
  connecting,
  
  /// Recibiendo datos
  streaming,
  
  /// Stream completado exitosamente
  completed,
  
  /// Error durante el streaming
  error,
  
  /// Stream cancelado por el usuario
  cancelled,
}

/// Información sobre el progreso del streaming
class StreamingProgress {
  final StreamingState state;
  final String? currentText;
  final int chunksReceived;
  final Duration elapsed;
  final String? errorMessage;

  StreamingProgress({
    required this.state,
    this.currentText,
    this.chunksReceived = 0,
    this.elapsed = Duration.zero,
    this.errorMessage,
  });

  factory StreamingProgress.idle() => StreamingProgress(
    state: StreamingState.idle,
  );

  factory StreamingProgress.connecting() => StreamingProgress(
    state: StreamingState.connecting,
  );

  factory StreamingProgress.streaming(String text, int chunks, Duration elapsed) =>
    StreamingProgress(
      state: StreamingState.streaming,
      currentText: text,
      chunksReceived: chunks,
      elapsed: elapsed,
    );

  factory StreamingProgress.completed(String text, int chunks, Duration elapsed) =>
    StreamingProgress(
      state: StreamingState.completed,
      currentText: text,
      chunksReceived: chunks,
      elapsed: elapsed,
    );

  factory StreamingProgress.error(String message) => StreamingProgress(
    state: StreamingState.error,
    errorMessage: message,
  );

  bool get isActive => 
    state == StreamingState.connecting || 
    state == StreamingState.streaming;
}