import '../../domain/entities/quick_response_entity.dart';

class QuickResponse {
  final String text;
  final String? description;

  const QuickResponse({
    required this.text,
    this.description,
  });

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  /// Convierte el modelo de datos a una entidad de dominio
  QuickResponseEntity toEntity() {
    return QuickResponseEntity(
      text: text,
      description: description,
    );
  }

  /// Crea un modelo de datos desde una entidad de dominio
  factory QuickResponse.fromEntity(QuickResponseEntity entity) {
    return QuickResponse(
      text: entity.text,
      description: entity.description,
    );
  }
}

class QuickResponseProvider {
  // Respuestas por defecto
  static const List<QuickResponse> defaultResponses = [
    QuickResponse(text: '/tryprompt'),
    QuickResponse(text: 'Hola'),
    QuickResponse(text: 'Siguiente'),
  ];

  /// Respuestas por defecto como entidades
  static List<QuickResponseEntity> get defaultResponsesAsEntities {
    return defaultResponses
        .map((response) => response.toEntity())
        .toList();
  }

  // Método para obtener respuestas contextuales (placeholder para futuro)
  static List<QuickResponse> getContextualResponses(List<dynamic> messages) {
    // TODO: Implementar lógica de respuestas contextuales
    // Por ahora devolvemos las respuestas por defecto
    return defaultResponses;
  }

  /// Obtiene respuestas contextuales como entidades
  static List<QuickResponseEntity> getContextualResponsesAsEntities(
      List<dynamic> messages) {
    return getContextualResponses(messages)
        .map((response) => response.toEntity())
        .toList();
  }
}