import '../../domain/entities/command_entity.dart';
import '../../domain/repositories/command_repository.dart';
import '../models/command_model.dart';
import '../services/local_command_service.dart';

class CommandRepositoryImpl implements CommandRepository {
  final LocalCommandService _localCommandService;

  CommandRepositoryImpl(this._localCommandService);

  @override
  Future<List<CommandEntity>> getAllCommands() async {
    // 1. Obtener comandos inmutables del sistema
    final systemCommands = CommandModel.getDefaultCommands();

    // 2. Obtener comandos personalizados del usuario (desde SecureStorage)
    final userCommands = await _localCommandService.getUserCommands();

    // 3. Retornar la lista combinada
    // Colocamos primero los del usuario para que aparezcan antes si se ordenan por fecha,
    // o después si prefieres ordenarlos por trigger. Aquí simplemente los concatenamos.
    return [...systemCommands, ...userCommands];
  }

  @override
  Future<void> saveCommand(CommandEntity command) async {
    // GUARDRAIL: No permitir editar comandos de sistema
    if (command.isSystem) {
      throw Exception('⛔ Seguridad: No se pueden modificar los comandos del sistema.');
    }

    // Convertir Entidad a Modelo para almacenamiento
    final commandModel = CommandModel.fromEntity(command);
    
    await _localCommandService.saveCommand(commandModel);
  }

  @override
  Future<void> deleteCommand(String id) async {
    // Verificar primero si es un comando de sistema para protegerlo
    // (Aunque el ID debería ser suficiente, hacemos una doble verificación lógica)
    final systemCommands = CommandModel.getDefaultCommands();
    final isSystemCommand = systemCommands.any((cmd) => cmd.id == id);

    if (isSystemCommand) {
      throw Exception('⛔ Seguridad: No se pueden eliminar los comandos del sistema.');
    }

    await _localCommandService.deleteCommand(id);
  }
}