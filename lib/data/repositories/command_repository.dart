import 'package:flutter/foundation.dart';
import '../../domain/entities/command_entity.dart';
import '../../domain/entities/command_folder_entity.dart';
import '../../domain/repositories/icommand_repository.dart';
import '../models/command_model.dart';
import '../models/command_folder_model.dart';
import '../services/local_command_service.dart';
import '../services/local_folder_service.dart';
import '../services/firebase_command_sync_service.dart';
import '../services/firebase_folder_sync_service.dart';

class CommandRepositoryImpl implements ICommandRepository {
  final LocalCommandService _localCommandService;
  final LocalFolderService _localFolderService;
  final FirebaseCommandSyncService _firebaseCommandSyncService;
  final FirebaseFolderSyncService _firebaseFolderSyncService;
  final bool Function() _isSyncEnabled;

  CommandRepositoryImpl(
    this._localCommandService,
    this._localFolderService,
    this._firebaseCommandSyncService,
    this._firebaseFolderSyncService,
    this._isSyncEnabled,
  );

  // ============================================================================
  // COMANDOS
  // ============================================================================

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
      await _firebaseCommandSyncService.saveCommandToFirebase(commandModel);
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
      await _firebaseCommandSyncService.deleteCommandFromFirebase(commandToDelete.trigger);
    }
  }

  @override
  Future<void> deleteAllLocalCommands() async {
    try {
      await _localCommandService.deleteAllCommands();
      debugPrint('✅ [CommandRepository] Todos los comandos de usuario eliminados localmente');
    } catch (e) {
      debugPrint('❌ [CommandRepository] Error al eliminar comandos locales: $e');
      rethrow;
    }
  }

  @override
  Future<void> moveCommandToFolder(String commandId, String? folderId) async {
    // Verificar que no es un comando del sistema
    final systemCommands = CommandModel.getDefaultCommands();
    final isSystemCommand = systemCommands.any((cmd) => cmd.id == commandId);

    if (isSystemCommand) {
      throw Exception('🛑 Seguridad: No se pueden mover los comandos del sistema.');
    }

    await _localCommandService.moveCommandToFolder(commandId, folderId);
    
    // Sincronizar con Firebase si está habilitado
    if (_isSyncEnabled()) {
      final userCommands = await _localCommandService.getUserCommands();
      final command = userCommands.firstWhere(
        (cmd) => cmd.id == commandId,
        orElse: () => throw Exception('Comando no encontrado'),
      );
      await _firebaseCommandSyncService.saveCommandToFirebase(command);
    }
  }

  // ============================================================================
  // CARPETAS
  // ============================================================================

  @override
  Future<List<CommandFolderEntity>> getAllFolders() async {
    return await _localFolderService.getFolders();
  }

  @override
  Future<void> saveFolder(CommandFolderEntity folder) async {
    final folderModel = CommandFolderModel.fromEntity(folder);
    await _localFolderService.saveFolder(folderModel);
    
    // Sincronizar con Firebase si está habilitado
    if (_isSyncEnabled()) {
      // Obtener la carpeta actualizada (puede tener order asignado)
      final updatedFolder = await _localFolderService.getFolderById(folder.id);
      if (updatedFolder != null) {
        await _firebaseFolderSyncService.saveFolderToFirebase(updatedFolder);
      }
    }
  }

  @override
  Future<void> deleteFolder(String folderId) async {
    // Primero mover todos los comandos de esta carpeta a "sin carpeta"
    await _localCommandService.removeCommandsFromFolder(folderId);
    
    // Luego eliminar la carpeta localmente
    await _localFolderService.deleteFolder(folderId);
    
    // Sincronizar con Firebase si está habilitado
    if (_isSyncEnabled()) {
      // Eliminar carpeta de Firebase
      await _firebaseFolderSyncService.deleteFolderFromFirebase(folderId);
      
      // Actualizar comandos que fueron movidos en Firebase
      final userCommands = await _localCommandService.getUserCommands();
      for (final cmd in userCommands.where((c) => c.folderId == null)) {
        await _firebaseCommandSyncService.saveCommandToFirebase(cmd);
      }
    }
  }

  @override
  Future<void> reorderFolders(List<String> folderIds) async {
    final reorderedFolders = await _localFolderService.reorderFolders(folderIds);
    
    // Sincronizar con Firebase si está habilitado
    if (_isSyncEnabled()) {
      await _firebaseFolderSyncService.reorderFoldersInFirebase(reorderedFolders);
    }
  }

  @override
  Future<void> deleteAllLocalFolders() async {
    try {
      // Primero liberar todos los comandos de todas las carpetas
      final folders = await _localFolderService.getFolders();
      for (final folder in folders) {
        await _localCommandService.removeCommandsFromFolder(folder.id);
      }
      
      // Luego eliminar todas las carpetas
      await _localFolderService.deleteAllFolders();
      
      debugPrint('✅ [CommandRepository] Todas las carpetas eliminadas localmente');
    } catch (e) {
      debugPrint('❌ [CommandRepository] Error al eliminar carpetas locales: $e');
      rethrow;
    }
  }

  // ============================================================================
  // PREFERENCIAS
  // ============================================================================

  /// Guarda la preferencia de agrupar comandos del sistema en Firebase
  Future<void> saveGroupSystemPreference(bool value) async {
    if (_isSyncEnabled()) {
      await _firebaseFolderSyncService.saveGroupSystemPreference(value);
    }
  }

  /// Obtiene la preferencia de agrupar comandos del sistema desde Firebase
  Future<bool?> getGroupSystemPreference() async {
    if (_isSyncEnabled()) {
      return await _firebaseFolderSyncService.getGroupSystemPreference();
    }
    return null;
  }

  // ============================================================================
  // SINCRONIZACIÓN COMPLETA
  // ============================================================================

  /// Sincroniza comandos, carpetas Y preferencias con Firebase
  Future<FullSyncResult> syncAll() async {
    if (!_isSyncEnabled()) {
      return FullSyncResult(
        success: false,
        error: 'Sincronización deshabilitada',
      );
    }

    try {
      // 1. Sincronizar carpetas primero (incluye preferencias)
      final localFolders = await _localFolderService.getFolders();
      final folderSyncResult = await _firebaseFolderSyncService.syncFolders(localFolders);
      
      // Guardar carpetas descargadas localmente
      if (folderSyncResult.success && folderSyncResult.foldersToDownload != null) {
        for (final remoteFolder in folderSyncResult.foldersToDownload!) {
          await _localFolderService.saveFolder(remoteFolder);
        }
      }

      // 2. Sincronizar comandos
      final localCommands = await _localCommandService.getUserCommands();
      final commandSyncResult = await _firebaseCommandSyncService.syncCommands(localCommands);
      
      // Guardar comandos descargados localmente
      if (commandSyncResult.success && commandSyncResult.remoteCommands != null) {
        for (final remoteCmd in commandSyncResult.remoteCommands!) {
          final existsLocally = localCommands.any((c) => c.trigger == remoteCmd.trigger);
          if (!existsLocally) {
            await _localCommandService.saveCommand(remoteCmd);
          }
        }
      }

      debugPrint('✅ [CommandRepository] Sincronización completa finalizada');
      debugPrint('   📁 Carpetas: ↑${folderSyncResult.uploaded} ↓${folderSyncResult.downloaded}');
      debugPrint('   ⚡ Comandos: ↑${commandSyncResult.uploaded} ↓${commandSyncResult.downloaded}');

      return FullSyncResult(
        success: true,
        foldersUploaded: folderSyncResult.uploaded,
        foldersDownloaded: folderSyncResult.downloaded,
        commandsUploaded: commandSyncResult.uploaded,
        commandsDownloaded: commandSyncResult.downloaded,
        remoteGroupSystemCommands: folderSyncResult.remoteGroupSystemCommands,
      );
    } catch (e) {
      debugPrint('❌ [CommandRepository] Error en sincronización completa: $e');
      return FullSyncResult(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Sincroniza solo comandos (mantener compatibilidad)
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
    final syncResult = await _firebaseCommandSyncService.syncCommands(localCommands);
    
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

  // ============================================================================
  // ELIMINACIÓN DE DATOS DE FIREBASE
  // ============================================================================

  /// Elimina todos los datos del usuario de Firebase (carpetas, comandos y preferencias)
  Future<bool> deleteAllFromFirebase() async {
    if (!_isSyncEnabled()) return false;

    try {
      // Eliminar carpetas y preferencias de Firebase
      await _firebaseFolderSyncService.deleteAllFromFirebase();
      
      debugPrint('✅ [CommandRepository] Todos los datos eliminados de Firebase');
      return true;
    } catch (e) {
      debugPrint('❌ [CommandRepository] Error eliminando datos de Firebase: $e');
      return false;
    }
  }
}

/// Resultado de sincronización completa (carpetas + comandos + preferencias)
class FullSyncResult {
  final bool success;
  final int foldersUploaded;
  final int foldersDownloaded;
  final int commandsUploaded;
  final int commandsDownloaded;
  final String? error;
  final bool? remoteGroupSystemCommands;

  FullSyncResult({
    required this.success,
    this.foldersUploaded = 0,
    this.foldersDownloaded = 0,
    this.commandsUploaded = 0,
    this.commandsDownloaded = 0,
    this.error,
    this.remoteGroupSystemCommands,
  });

  @override
  String toString() {
    if (!success) return 'Error: $error';
    return 'Sincronizado - Carpetas: ↑$foldersUploaded ↓$foldersDownloaded, Comandos: ↑$commandsUploaded ↓$commandsDownloaded';
  }
}