import 'package:flutter/foundation.dart';
import '../../domain/entities/command_entity.dart';
import '../../domain/repositories/command_repository.dart';
import '../models/command_model.dart';
import '../services/local_command_service.dart';
import '../services/firebase_command_sync_service.dart';

class CommandRepositoryImpl implements CommandRepository {
  final LocalCommandService _localCommandService;
  final FirebaseCommandSyncService _firebaseSyncService;
  final bool Function() _isSyncEnabled;

  CommandRepositoryImpl(
    this._localCommandService,
    this._firebaseSyncService,
    this._isSyncEnabled,
  );

  @override
  Future<List<CommandEntity>> getAllCommands() async {
    final systemCommands = CommandModel.getDefaultCommands();
    final userCommands = await _localCommandService.getUserCommands();
    
    return [...systemCommands, ...userCommands];
  }

  @override
  Future<void> saveCommand(CommandEntity command) async {
    if (command.isSystem) {
      throw Exception('🛑 Seguridad: No se pueden modificar los comandos del sistema.');
    }

    final commandModel = CommandModel.fromEntity(command);
    
    await _localCommandService.saveCommand(commandModel);
    
    if (_isSyncEnabled()) {
      await _firebaseSyncService.saveCommandToFirebase(commandModel);
    }
  }

  @override
  Future<void> deleteCommand(String id) async {
    final systemCommands = CommandModel.getDefaultCommands();
    final isSystemCommand = systemCommands.any((cmd) => cmd.id == id);

    if (isSystemCommand) {
      throw Exception('🛑 Seguridad: No se pueden eliminar los comandos del sistema.');
    }

    final userCommands = await _localCommandService.getUserCommands();
    final commandToDelete = userCommands.firstWhere(
      (cmd) => cmd.id == id,
      orElse: () => throw Exception('Comando no encontrado'),
    );

    await _localCommandService.deleteCommand(id);
    
    if (_isSyncEnabled()) {
      await _firebaseSyncService.deleteCommandFromFirebase(commandToDelete.trigger);
    }
  }

  @override
  Future<void> deleteAllLocalCommands() async {
    try {
      // Eliminar todos los comandos locales del usuario
      await _localCommandService.deleteAllCommands();
      
      debugPrint('✅ [CommandRepository] Todos los comandos de usuario eliminados localmente');
    } catch (e) {
      debugPrint('❌ [CommandRepository] Error al eliminar comandos locales: $e');
      rethrow;
    }
  }

  Future<CommandSyncResult> syncCommands() async {
    if (!_isSyncEnabled()) {
      return CommandSyncResult(
        success: false,
        uploaded: 0,
        downloaded: 0,
        error: 'Sincronización deshabilitada',
      );
    }

    final localCommands = await _localCommandService.getUserCommands();
    final syncResult = await _firebaseSyncService.syncCommands(localCommands);
    
    if (syncResult.success && syncResult.remoteCommands != null) {
      for (final remoteCmd in syncResult.remoteCommands!) {
        final existsLocally = localCommands.any((c) => c.trigger == remoteCmd.trigger);
        if (!existsLocally) {
          await _localCommandService.saveCommand(remoteCmd);
        }
      }
    }
    
    return syncResult;
  }
}