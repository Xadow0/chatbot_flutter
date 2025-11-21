import '../entities/command_entity.dart';

/// Interfaz del repositorio de comandos.
/// Define las operaciones disponibles para gestionar comandos del sistema y del usuario.
abstract class CommandRepository {
  /// Obtiene la lista unificada de comandos (Sistema + Usuario)
  Future<List<CommandEntity>> getAllCommands();

  /// Guarda un comando personalizado (Crear o Editar).
  /// Lanza una excepción si se intenta modificar un comando de sistema.
  Future<void> saveCommand(CommandEntity command);

  /// Elimina un comando personalizado por su ID.
  /// Lanza una excepción si se intenta eliminar un comando de sistema.
  Future<void> deleteCommand(String id);
}