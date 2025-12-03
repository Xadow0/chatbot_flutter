import 'package:equatable/equatable.dart';

/// Define si un comando es puramente texto (usuario) o tiene lógica interna (sistema)
enum SystemCommandType {
  none,          // Comando personalizado del usuario (Lógica simple: Prompt + Input)
  evaluarPrompt, // Requiere inyección de {{content}} tras limpieza
  traducir,      // Requiere lógica de detección de idioma e inyección de {{targetLanguage}} y {{content}}
  resumir,       // Requiere inyección de {{content}}
  codigo,        // Requiere inyección de {{content}}
  corregir,      // Requiere inyección de {{content}}
  explicar,      // Requiere inyección de {{content}}
  comparar,      // Requiere inyección de {{content}}
}

class CommandEntity extends Equatable {
  final String id;
  final String trigger;      // El comando (ej: /traducir)
  final String title;        // Nombre legible
  final String description;  // Texto de ayuda
  final String promptTemplate; // El prompt con placeholders {{content}}, {{targetLanguage}}, etc.
  final bool isSystem;       // Si es false, se puede editar/borrar
  final SystemCommandType systemType;
  
  /// Indica si el comando es editable desde quick_responses.
  /// 
  /// - `true` (Editable): Al seleccionar desde quick_responses, se inserta 
  ///   el promptTemplate completo en el input para que el usuario pueda modificarlo.
  /// - `false` (No Editable): Al seleccionar, se inserta "/comando " y se procesa
  ///   automáticamente combinando el promptTemplate con el contenido del usuario.
  /// 
  /// Por defecto es `false` para mantener compatibilidad con comandos existentes.
  final bool isEditable;

  const CommandEntity({
    required this.id,
    required this.trigger,
    required this.title,
    required this.description,
    required this.promptTemplate,
    this.isSystem = false,
    this.systemType = SystemCommandType.none,
    this.isEditable = false,
  });

  /// Crea una copia del comando con algunos campos modificados
  CommandEntity copyWith({
    String? id,
    String? trigger,
    String? title,
    String? description,
    String? promptTemplate,
    bool? isSystem,
    SystemCommandType? systemType,
    bool? isEditable,
  }) {
    return CommandEntity(
      id: id ?? this.id,
      trigger: trigger ?? this.trigger,
      title: title ?? this.title,
      description: description ?? this.description,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      isSystem: isSystem ?? this.isSystem,
      systemType: systemType ?? this.systemType,
      isEditable: isEditable ?? this.isEditable,
    );
  }

  @override
  List<Object?> get props => [
    id, 
    trigger, 
    title, 
    description, 
    promptTemplate, 
    isSystem, 
    systemType,
    isEditable,
  ];
}