import '../entities/command_entity.dart';
import '../entities/command_folder_entity.dart';

/// Interfaz del repositorio de comandos.
/// Define las operaciones disponibles para gestionar comandos del sistema y del usuario.
abstract class CommandRepository {
  // ============================================================================
  // COMANDOS
  // ============================================================================
  
  /// Obtiene la lista unificada de comandos (Sistema + Usuario)
  Future<List<CommandEntity>> getAllCommands();

  /// Guarda un comando personalizado (Crear o Editar).
  /// Lanza una excepción si se intenta modificar un comando de sistema.
  Future<void> saveCommand(CommandEntity command);

  /// Elimina un comando personalizado por su ID.
  /// Lanza una excepción si se intenta eliminar un comando de sistema.
  Future<void> deleteCommand(String id);

  /// Elimina todos los comandos personalizados locales del usuario.
  /// Se usa cuando el usuario elimina su cuenta.
  /// Los comandos del sistema NO se ven afectados.
  Future<void> deleteAllLocalCommands();

  /// Mueve un comando a una carpeta específica.
  /// Si folderId es null, el comando queda sin carpeta.
  Future<void> moveCommandToFolder(String commandId, String? folderId);

  // ============================================================================
  // CARPETAS
  // ============================================================================

  /// Obtiene todas las carpetas del usuario
  Future<List<CommandFolderEntity>> getAllFolders();

  /// Guarda una carpeta (Crear o Editar)
  Future<void> saveFolder(CommandFolderEntity folder);

  /// Elimina una carpeta por su ID.
  /// Los comandos dentro de la carpeta se mueven a "sin carpeta".
  Future<void> deleteFolder(String folderId);

  /// Reordena las carpetas según la lista de IDs proporcionada
  Future<void> reorderFolders(List<String> folderIds);

  /// Elimina todas las carpetas del usuario.
  /// Se usa cuando el usuario elimina su cuenta.
  Future<void> deleteAllLocalFolders();
}