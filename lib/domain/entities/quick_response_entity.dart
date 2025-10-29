/// Entidad de dominio para una respuesta rápida
/// 
/// Representa una respuesta predefinida que el usuario puede seleccionar
/// rápidamente sin necesidad de escribirla.
class QuickResponseEntity {
  final String text;
  final String? description;

  const QuickResponseEntity({
    required this.text,
    this.description,
  });

  /// Crea una copia de la respuesta rápida con algunos campos modificados
  QuickResponseEntity copyWith({
    String? text,
    String? description,
  }) {
    return QuickResponseEntity(
      text: text ?? this.text,
      description: description ?? this.description,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickResponseEntity &&
        other.text == text &&
        other.description == description;
  }

  @override
  int get hashCode => Object.hash(text, description);

  @override
  String toString() {
    return 'QuickResponseEntity(text: $text, description: $description)';
  }
}