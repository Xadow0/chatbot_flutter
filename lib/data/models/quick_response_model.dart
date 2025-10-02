class QuickResponse {
  final String text;
  final String? description;

  const QuickResponse({
    required this.text,
    this.description,
  });
}

class QuickResponseProvider {
  // Respuestas por defecto
  static const List<QuickResponse> defaultResponses = [
    QuickResponse(text: 'Sí'),
    QuickResponse(text: 'Hola'),
    QuickResponse(text: 'Siguiente'),
  ];

  // Método para obtener respuestas contextuales (placeholder para futuro)
  static List<QuickResponse> getContextualResponses(List<dynamic> messages) {
    // TODO: Implementar lógica de respuestas contextuales
    // Por ahora devolvemos las respuestas por defecto
    return defaultResponses;
  }
}