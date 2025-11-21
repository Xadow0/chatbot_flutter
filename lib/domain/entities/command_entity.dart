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

  const CommandEntity({
    required this.id,
    required this.trigger,
    required this.title,
    required this.description,
    required this.promptTemplate,
    this.isSystem = false,
    this.systemType = SystemCommandType.none,
  });

  @override
  List<Object?> get props => [id, trigger, title, description, promptTemplate, isSystem, systemType];
}