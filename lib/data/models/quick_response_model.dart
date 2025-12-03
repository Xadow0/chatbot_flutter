import '../../domain/entities/quick_response_entity.dart';

class QuickResponse {
  final String text;
  final String? description;
  
  /// El prompt completo asociado al comando.
  final String? promptTemplate;
  
  /// Indica si el comando es editable.
  final bool isEditable;

  const QuickResponse({
    required this.text,
    this.description,
    this.promptTemplate,
    this.isEditable = false,
  });

  // ============================================================================
  // CONVERSIÓN ENTRE MODELO Y ENTIDAD (Clean Architecture)
  // ============================================================================

  /// Convierte el modelo de datos a una entidad de dominio
  QuickResponseEntity toEntity() {
    return QuickResponseEntity(
      text: text,
      description: description,
      promptTemplate: promptTemplate,
      isEditable: isEditable,
    );
  }

  /// Crea un modelo de datos desde una entidad de dominio
  factory QuickResponse.fromEntity(QuickResponseEntity entity) {
    return QuickResponse(
      text: entity.text,
      description: entity.description,
      promptTemplate: entity.promptTemplate,
      isEditable: entity.isEditable,
    );
  }
}

class QuickResponseProvider {
  // Respuestas por defecto (comandos del sistema)
  // NOTA: Los comandos del sistema siempre son NO editables
  static const List<QuickResponse> defaultResponses = [
    QuickResponse(
      text: '/evaluarprompt',
      description: 'Evalúa y mejora un prompt',
      isEditable: false,
    ),
    QuickResponse(
      text: '/traducir',
      description: 'Traduce texto a otro idioma',
      isEditable: false,
    ),
    QuickResponse(
      text: '/resumir',
      description: 'Resume un texto largo',
      isEditable: false,
    ),
    QuickResponse(
      text: '/codigo',
      description: 'Genera código desde descripción',
      isEditable: false,
    ),
    QuickResponse(
      text: '/corregir',
      description: 'Corrige ortografía y gramática',
      isEditable: false,
    ),
    QuickResponse(
      text: '/explicar',
      description: 'Explica un concepto',
      isEditable: false,
    ),
    QuickResponse(
      text: '/comparar',
      description: 'Compara dos o más opciones',
      isEditable: false,
    ),
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