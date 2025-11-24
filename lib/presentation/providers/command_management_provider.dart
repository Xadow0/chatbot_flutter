import 'package:flutter/foundation.dart';
import '../../domain/entities/command_entity.dart';
import '../../data/repositories/command_repository.dart';
import '../../data/services/firebase_command_sync_service.dart';

class CommandManagementProvider extends ChangeNotifier {
  final CommandRepositoryImpl _repository;
  
  List<CommandEntity> _commands = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  bool _hasInitialSyncCompleted = false;

  CommandManagementProvider(this._repository);

  List<CommandEntity> get commands => _commands;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  List<CommandEntity> get userCommands => 
      _commands.where((c) => c.systemType == SystemCommandType.none).toList();
      
  List<CommandEntity> get systemCommands => 
      _commands.where((c) => c.systemType != SystemCommandType.none).toList();

  Future<void> loadCommands({bool autoSync = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      if (autoSync && !_hasInitialSyncCompleted) {
        await syncWithFirebase();
        _hasInitialSyncCompleted = true;
      }
      
      _commands = await _repository.getAllCommands();
      _commands.sort((a, b) {
        if (a.systemType == SystemCommandType.none && b.systemType != SystemCommandType.none) return -1;
        if (a.systemType != SystemCommandType.none && b.systemType == SystemCommandType.none) return 1;
        return a.title.compareTo(b.title);
      });
    } catch (e) {
      _error = 'Error cargando comandos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  void resetSyncStatus() {
    _hasInitialSyncCompleted = false;
  }

  Future<void> saveCommand(CommandEntity command) async {
    try {
      await _repository.saveCommand(command);
      await loadCommands();
    } catch (e) {
      throw Exception('No se pudo guardar el comando: $e');
    }
  }

  Future<void> deleteCommand(String commandId) async {
    try {
      await _repository.deleteCommand(commandId);
      await loadCommands();
    } catch (e) {
      throw Exception('No se pudo eliminar el comando: $e');
    }
  }

  Future<CommandSyncResult> syncWithFirebase() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _repository.syncCommands();
      await loadCommands();
      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}