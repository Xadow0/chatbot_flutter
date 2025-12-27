import '../../domain/entities/quick_response_entity.dart';
import '../../../commands/domain/entities/command_entity.dart';
import '../../../commands/domain/entities/command_folder_entity.dart';

class QuickResponse {
  final String text;
  final String? description;
  
  /// El prompt completo asociado al comando.
  final String? promptTemplate;
  
  /// Indica si el comando es editable.
  final bool isEditable;

  /// Tipo de respuesta: comando individual o carpeta
  final QuickResponseType type;

  /// ID de la carpeta (solo si type == folder)
  final String? folderId;

  /// Icono de la carpeta (solo si type == folder)
  final String? folderIcon;

  /// Comandos dentro de la carpeta (solo si type == folder)
  final List<QuickResponse>? children;

  /// Indica si es un comando del sistema
  final bool isSystem;

  const QuickResponse({
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

  /// Indica si es una carpeta
  bool get isFolder => type == QuickResponseType.folder;

  /// Indica si es un comando
  bool get isCommand => type == QuickResponseType.command;

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
      type: type,
      folderId: folderId,
      folderIcon: folderIcon,
      children: children?.map((c) => c.toEntity()).toList(),
      isSystem: isSystem,
    );
  }

  /// Crea un modelo de datos desde una entidad de dominio
  factory QuickResponse.fromEntity(QuickResponseEntity entity) {
    return QuickResponse(
      text: entity.text,
      description: entity.description,
      promptTemplate: entity.promptTemplate,
      isEditable: entity.isEditable,
      type: entity.type,
      folderId: entity.folderId,
      folderIcon: entity.folderIcon,
      children: entity.children?.map((c) => QuickResponse.fromEntity(c)).toList(),
      isSystem: entity.isSystem,
    );
  }

  /// Crea un QuickResponse desde un CommandEntity
  factory QuickResponse.fromCommand(CommandEntity command) {
    return QuickResponse(
      text: command.trigger.trim(),
      description: command.description,
      promptTemplate: command.promptTemplate,
      isEditable: command.isEditable,
      type: QuickResponseType.command,
      isSystem: command.isSystem,
    );
  }

  /// Crea un QuickResponse de tipo carpeta
  factory QuickResponse.folder({
    required CommandFolderEntity folder,
    required List<CommandEntity> commands,
  }) {
    return QuickResponse(
      text: folder.name,
      folderId: folder.id,
      folderIcon: folder.icon ?? '📁',
      type: QuickResponseType.folder,
      children: commands.map((c) => QuickResponse.fromCommand(c)).toList(),
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
      isSystem: true,
    ),
    QuickResponse(
      text: '/traducir',
      description: 'Traduce texto a otro idioma',
      isEditable: false,
      isSystem: true,
    ),
    QuickResponse(
      text: '/resumir',
      description: 'Resume un texto largo',
      isEditable: false,
      isSystem: true,
    ),
    QuickResponse(
      text: '/codigo',
      description: 'Genera código desde descripción',
      isEditable: false,
      isSystem: true,
    ),
    QuickResponse(
      text: '/corregir',
      description: 'Corrige ortografía y gramática',
      isEditable: false,
      isSystem: true,
    ),
    QuickResponse(
      text: '/explicar',
      description: 'Explica un concepto',
      isEditable: false,
      isSystem: true,
    ),
    QuickResponse(
      text: '/comparar',
      description: 'Compara dos o más opciones',
      isEditable: false,
      isSystem: true,
    ),
  ];

  /// Respuestas por defecto como entidades
  static List<QuickResponseEntity> get defaultResponsesAsEntities {
    return defaultResponses.map((response) => response.toEntity()).toList();
  }

  /// Genera la lista de QuickResponses organizadas por carpetas
  /// 
  /// [commands] - Lista de todos los comandos (usuario + sistema)
  /// [folders] - Lista de carpetas del usuario
  /// [groupSystemCommands] - Si true, agrupa los comandos del sistema en una carpeta "Sistema"
  static List<QuickResponse> buildOrganizedResponses({
    required List<CommandEntity> commands,
    required List<CommandFolderEntity> folders,
    required bool groupSystemCommands,
  }) {
    final List<QuickResponse> responses = [];
    
    // Separar comandos de usuario y sistema
    final userCommands = commands.where((c) => !c.isSystem).toList();
    final systemCommands = commands.where((c) => c.isSystem).toList();
    
    // 1. Añadir carpetas del usuario con sus comandos
    for (final folder in folders) {
      final commandsInFolder = userCommands
          .where((c) => c.folderId == folder.id)
          .toList();
      
      if (commandsInFolder.isNotEmpty) {
        responses.add(QuickResponse.folder(
          folder: folder,
          commands: commandsInFolder,
        ));
      }
    }
    
    // 2. Añadir comandos de usuario sin carpeta
    final commandsWithoutFolder = userCommands
        .where((c) => c.folderId == null)
        .toList();
    
    for (final command in commandsWithoutFolder) {
      responses.add(QuickResponse.fromCommand(command));
    }
    
    // 3. Añadir comandos del sistema
    if (groupSystemCommands && systemCommands.isNotEmpty) {
      // Agrupar en una carpeta "Sistema"
      responses.add(QuickResponse(
        text: 'Sistema',
        folderId: '_system_folder',
        folderIcon: '🔒',
        type: QuickResponseType.folder,
        children: systemCommands.map((c) => QuickResponse.fromCommand(c)).toList(),
      ));
    } else {
      // Añadir individualmente
      for (final command in systemCommands) {
        responses.add(QuickResponse.fromCommand(command));
      }
    }
    
    return responses;
  }

  // Método para obtener respuestas contextuales (placeholder para futuro)
  static List<QuickResponse> getContextualResponses(List<dynamic> messages) {
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