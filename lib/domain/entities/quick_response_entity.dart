/// Tipo de respuesta rápida
enum QuickResponseType {
  command,  // Comando individual
  folder,   // Carpeta que contiene comandos
}

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

  /// Tipo de respuesta: comando individual o carpeta
  final QuickResponseType type;

  /// ID de la carpeta (solo si type == folder)
  final String? folderId;

  /// Icono de la carpeta (solo si type == folder)
  final String? folderIcon;

  /// Comandos dentro de la carpeta (solo si type == folder)
  final List<QuickResponseEntity>? children;

  /// Indica si es un comando del sistema
  final bool isSystem;

  const QuickResponseEntity({
    required this.text,
    this.description,
    this.promptTemplate,
    this.isEditable = false,
    this.type = QuickResponseType.command,
    this.folderId,
    this.folderIcon,
    this.children,
    this.isSystem = false,
  });

  /// Crea una respuesta rápida de tipo carpeta
  factory QuickResponseEntity.folder({
    required String id,
    required String name,
    String? icon,
    required List<QuickResponseEntity> children,
  }) {
    return QuickResponseEntity(
      text: name,
      folderId: id,
      folderIcon: icon ?? '📁',
      type: QuickResponseType.folder,
      children: children,
    );
  }

  /// Crea una respuesta rápida de tipo comando
  factory QuickResponseEntity.command({
    required String text,
    String? description,
    String? promptTemplate,
    bool isEditable = false,
    bool isSystem = false,
  }) {
    return QuickResponseEntity(
      text: text,
      description: description,
      promptTemplate: promptTemplate,
      isEditable: isEditable,
      type: QuickResponseType.command,
      isSystem: isSystem,
    );
  }

  /// Indica si es una carpeta
  bool get isFolder => type == QuickResponseType.folder;

  /// Indica si es un comando
  bool get isCommand => type == QuickResponseType.command;

  /// Número de comandos en la carpeta (0 si no es carpeta)
  int get childCount => children?.length ?? 0;

  /// Crea una copia de la respuesta rápida con algunos campos modificados
  QuickResponseEntity copyWith({
    String? text,
    String? description,
    String? promptTemplate,
    bool? isEditable,
    QuickResponseType? type,
    String? folderId,
    String? folderIcon,
    List<QuickResponseEntity>? children,
    bool? isSystem,
  }) {
    return QuickResponseEntity(
      text: text ?? this.text,
      description: description ?? this.description,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      isEditable: isEditable ?? this.isEditable,
      type: type ?? this.type,
      folderId: folderId ?? this.folderId,
      folderIcon: folderIcon ?? this.folderIcon,
      children: children ?? this.children,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is QuickResponseEntity &&
        other.text == text &&
        other.description == description &&
        other.promptTemplate == promptTemplate &&
        other.isEditable == isEditable &&
        other.type == type &&
        other.folderId == folderId &&
        other.isSystem == isSystem;
  }

  @override
  int get hashCode => Object.hash(
    text, 
    description, 
    promptTemplate, 
    isEditable, 
    type, 
    folderId,
    isSystem,
  );

  @override
  String toString() {
    if (isFolder) {
      return 'QuickResponseEntity.folder(name: $text, children: ${children?.length ?? 0})';
    }
    return 'QuickResponseEntity.command(text: $text, isEditable: $isEditable)';
  }
}