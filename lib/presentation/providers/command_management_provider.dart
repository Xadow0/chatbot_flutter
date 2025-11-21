import 'package:flutter/foundation.dart';
import '../../domain/entities/command_entity.dart';
import '../../domain/repositories/command_repository.dart';

class CommandManagementProvider extends ChangeNotifier {
  final CommandRepository _repository;
  
  List<CommandEntity> _commands = [];
  bool _isLoading = false;
  String? _error;

  CommandManagementProvider(this._repository);

  List<CommandEntity> get commands => _commands;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Filtra solo los comandos creados por el usuario
  List<CommandEntity> get userCommands => 
      _commands.where((c) => c.systemType == SystemCommandType.none).toList();
      
  // Filtra comandos de sistema (solo lectura)
  List<CommandEntity> get systemCommands => 
      _commands.where((c) => c.systemType != SystemCommandType.none).toList();

  Future<void> loadCommands() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _commands = await _repository.getAllCommands();
      // Ordenamos: Primero usuario, luego sistema
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

  Future<void> saveCommand(CommandEntity command) async {
    try {
      await _repository.saveCommand(command);
      await loadCommands(); // Recargar lista
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
}