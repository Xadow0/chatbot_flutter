/// Entidad de dominio para una respuesta rápida
/// 
/// Representa una respuesta predefinida que el usuario puede seleccionar
/// rápidamente sin necesidad de escribirla.
class QuickResponseEntity {
  final String text;
  final String? description;
  
  /// El prompt completo asociado al comando.
  /// Se usa cuando el comando es editable para insertar el prompt en el input.
  final String? promptTemplate;
  
  /// Indica si el comando es editable.
  /// - `true`: Al seleccionar, se inserta el promptTemplate completo
  /// - `false`: Al seleccionar, se inserta "/comando " (comportamiento tradicional)
  final bool isEditable;

  const QuickResponseEntity({
    required this.text,
    this.description,
    this.promptTemplate,
    this.isEditable = false,
  });

  /// Crea una copia de la respuesta rápida con algunos campos modificados
  QuickResponseEntity copyWith({
    String? text,
    String? description,
    String? promptTemplate,
    bool? isEditable,
  }) {
    return QuickResponseEntity(
      text: text ?? this.text,
      description: description ?? this.description,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      isEditable: isEditable ?? this.isEditable,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickResponseEntity &&
        other.text == text &&
        other.description == description &&
        other.promptTemplate == promptTemplate &&
        other.isEditable == isEditable;
  }

  @override
  int get hashCode => Object.hash(text, description, promptTemplate, isEditable);

  @override
  String toString() {
    return 'QuickResponseEntity(text: $text, description: $description, isEditable: $isEditable)';
  }
}