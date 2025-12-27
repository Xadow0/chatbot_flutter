import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/command_entity.dart';
import '../../domain/entities/command_folder_entity.dart';
import '../../data/repositories/command_repository_impl.dart';
import '../../data/datasources/firebase_command_sync.dart';

class CommandManagementProvider extends ChangeNotifier {
  final CommandRepositoryImpl _repository;
  
  List<CommandEntity> _commands = [];
  List<CommandFolderEntity> _folders = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  bool _hasInitialSyncCompleted = false;
  
  /// Preferencia del usuario para agrupar comandos del sistema en una carpeta
  bool _groupSystemCommands = false;
  
  /// Callback para notificar cuando cambia la preferencia de agrupar sistema
  /// Se usa para actualizar los quick responses en ChatProvider
  VoidCallback? _onGroupSystemCommandsChanged;
  
  static const String _groupSystemCommandsKey = 'group_system_commands';

  CommandManagementProvider(this._repository);

  // ============================================================================
  // GETTERS
  // ============================================================================

  List<CommandEntity> get commands => _commands;
  List<CommandFolderEntity> get folders => _folders;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  bool get groupSystemCommands => _groupSystemCommands;

  /// Comandos del usuario (sin importar carpeta)
  List<CommandEntity> get userCommands => 
      _commands.where((c) => c.systemType == SystemCommandType.none).toList();
  
  /// Comandos del sistema
  List<CommandEntity> get systemCommands => 
      _commands.where((c) => c.systemType != SystemCommandType.none).toList();

  /// Comandos del usuario sin carpeta asignada
  List<CommandEntity> get commandsWithoutFolder =>
      userCommands.where((c) => c.folderId == null).toList();

  /// Obtiene los comandos de una carpeta específica
  List<CommandEntity> getCommandsInFolder(String folderId) {
    return userCommands.where((c) => c.folderId == folderId).toList();
  }

  /// Obtiene una carpeta por su ID
  CommandFolderEntity? getFolderById(String folderId) {
    try {
      return _folders.firstWhere((f) => f.id == folderId);
    } catch (_) {
      return null;
    }
  }

  // ============================================================================
  // CONFIGURACIÓN DE CALLBACKS
  // ============================================================================

  /// Establece el callback que se llamará cuando cambie la preferencia groupSystemCommands
  void setOnGroupSystemCommandsChanged(VoidCallback? callback) {
    _onGroupSystemCommandsChanged = callback;
  }

  // ============================================================================
  // CARGA DE DATOS
  // ============================================================================

 Future<void> loadCommands({bool autoSync = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. PASO CRÍTICO: CARGA "LOCAL-FIRST"
      // Independientemente de si hay internet o sync, cargamos la preferencia local INMEDIATAMENTE.
      // Esto asegura que la UI sepa si debe agrupar o no antes de conectar a Firebase.
      await _loadGroupSystemPreference();
      
      // Notificamos AQUÍ MISMO para que el ChatProvider se actualice 
      // con la preferencia correcta (agrupado/desagrupado) instantáneamente.
      notifyListeners(); 

      // 2. Lógica de Sincronización / Carga de datos
      if (autoSync && !_hasInitialSyncCompleted) {
        // Si hay sync, intentamos actualizar desde la nube
        await syncAllWithFirebase();
        _hasInitialSyncCompleted = true;
      } 
      
      // Nota: Ya no necesitamos el "else" para cargar preferencia, 
      // porque ya lo hicimos arriba en el paso 1.
      
      // 3. Cargar el resto de datos (Carpetas y Comandos)
      // Usamos el repositorio que gestiona la lógica de Local vs Remoto internamente
      _folders = await _repository.getAllFolders();
      _commands = await _repository.getAllCommands();
      _sortCommands();
      
    } catch (e) {
      debugPrint('❌ [CommandProvider] Error en loadCommands: $e');
      _error = 'Error cargando comandos: $e';
    } finally {
      _isLoading = false;
      
      // Notificación final para pintar los comandos cargados
      notifyListeners();
    }
  }

  Future<void> _loadGroupSystemPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loadedPref = prefs.getBool(_groupSystemCommandsKey) ?? false;
      
      // Solo actualizamos y notificamos si el valor cambia para evitar ruido
      if (_groupSystemCommands != loadedPref) {
        _groupSystemCommands = loadedPref;
        debugPrint('⚙️ [CommandProvider] Preferencia local cargada: Agrupar = $_groupSystemCommands');
        // No hacemos notifyListeners aquí porque lo hacemos en loadCommands
      }
    } catch (e) {
      debugPrint('⚠️ [CommandProvider] Error cargando preferencia: $e');
    }
  }

  void _sortCommands() {
    _commands.sort((a, b) {
      // Primero comandos de usuario, luego sistema
      if (a.systemType == SystemCommandType.none && b.systemType != SystemCommandType.none) return -1;
      if (a.systemType != SystemCommandType.none && b.systemType == SystemCommandType.none) return 1;
      return a.title.compareTo(b.title);
    });
  }
  
  void resetSyncStatus() {
    _hasInitialSyncCompleted = false;
  }

  // ============================================================================
  // COMANDOS - CRUD
  // ============================================================================

  Future<void> saveCommand(CommandEntity command) async {
    try {
      await _repository.saveCommand(command);
      await _reloadCommands();
    } catch (e) {
      throw Exception('No se pudo guardar el comando: $e');
    }
  }

  Future<void> deleteCommand(String commandId) async {
    try {
      await _repository.deleteCommand(commandId);
      await _reloadCommands();
    } catch (e) {
      throw Exception('No se pudo eliminar el comando: $e');
    }
  }

  Future<void> moveCommandToFolder(String commandId, String? folderId) async {
    try {
      await _repository.moveCommandToFolder(commandId, folderId);
      await _reloadCommands();
    } catch (e) {
      throw Exception('No se pudo mover el comando: $e');
    }
  }

  // ============================================================================
  // CARPETAS - CRUD
  // ============================================================================

  Future<void> saveFolder(CommandFolderEntity folder) async {
    try {
      await _repository.saveFolder(folder);
      _folders = await _repository.getAllFolders();
      notifyListeners();
    } catch (e) {
      throw Exception('No se pudo guardar la carpeta: $e');
    }
  }

  Future<void> deleteFolder(String folderId) async {
    try {
      await _repository.deleteFolder(folderId);
      _folders = await _repository.getAllFolders();
      await _reloadCommands(); // Los comandos fueron movidos a sin carpeta
    } catch (e) {
      throw Exception('No se pudo eliminar la carpeta: $e');
    }
  }

  Future<void> reorderFolders(List<String> folderIds) async {
    try {
      await _repository.reorderFolders(folderIds);
      _folders = await _repository.getAllFolders();
      notifyListeners();
    } catch (e) {
      throw Exception('No se pudo reordenar las carpetas: $e');
    }
  }

  // ============================================================================
  // PREFERENCIAS
  // ============================================================================

  /// Cambia la preferencia de agrupar comandos del sistema
  /// Guarda en local, sincroniza con Firebase si está habilitado,
  /// y notifica a ChatProvider para actualizar quick responses
  Future<void> setGroupSystemCommands(bool value) async {
    try {
      // Guardar en SharedPreferences (local)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_groupSystemCommandsKey, value);
      
      // Actualizar estado local
      _groupSystemCommands = value;
      
      // Sincronizar con Firebase si está habilitado
      await _repository.saveGroupSystemPreference(value);
      
      // Notificar a los listeners de este provider
      notifyListeners();
      
      // Notificar a ChatProvider para actualizar quick responses
      _onGroupSystemCommandsChanged?.call();
      
      debugPrint('✅ [CommandManagementProvider] Preferencia actualizada: groupSystemCommands=$value');
    } catch (e) {
      debugPrint('❌ [CommandManagementProvider] Error guardando preferencia: $e');
    }
  }

  // ============================================================================
  // SINCRONIZACIÓN
  // ============================================================================

  /// Sincroniza carpetas, comandos Y preferencias con Firebase
  Future<FullSyncResult> syncAllWithFirebase() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _repository.syncAll();
      
      // Si hay preferencia remota, aplicarla
      if (result.remoteGroupSystemCommands != null) {
        final prefs = await SharedPreferences.getInstance();
        final localPref = prefs.getBool(_groupSystemCommandsKey);
        
        // Si no hay preferencia local, usar la remota
        if (localPref == null) {
          _groupSystemCommands = result.remoteGroupSystemCommands!;
          await prefs.setBool(_groupSystemCommandsKey, _groupSystemCommands);
          debugPrint('📥 [CommandManagementProvider] Preferencia sincronizada desde Firebase: $_groupSystemCommands');
        }
      } else {
        // Si no hay preferencia remota pero sí local, subirla
        await _loadGroupSystemPreference();
        await _repository.saveGroupSystemPreference(_groupSystemCommands);
      }
      
      // Recargar datos después de sincronizar
      _folders = await _repository.getAllFolders();
      _commands = await _repository.getAllCommands();
      _sortCommands();
      
      // Notificar para actualizar quick responses
      _onGroupSystemCommandsChanged?.call();
      
      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sincroniza solo comandos (mantener compatibilidad)
  Future<CommandSyncResult> syncWithFirebase() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _repository.syncCommands();
      await _reloadCommands();
      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // ============================================================================
  // LIMPIEZA (para eliminar cuenta)
  // ============================================================================

  /// Elimina todos los comandos y carpetas de usuario locales del dispositivo
  /// Se usa cuando el usuario elimina su cuenta de forma permanente
  Future<void> deleteAllLocalData() async {
    try {
      debugPrint('🗑️ [CommandManagementProvider] Eliminando datos locales...');
      
      // Eliminar carpetas (esto también libera los comandos)
      await _repository.deleteAllLocalFolders();
      
      // Eliminar comandos
      await _repository.deleteAllLocalCommands();
      
      // Limpiar preferencias
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_groupSystemCommandsKey);
      
      // Limpiar estado en memoria
      _folders.clear();
      _commands.removeWhere((cmd) => cmd.systemType == SystemCommandType.none);
      _groupSystemCommands = false;
      
      notifyListeners();
      
      // Notificar para actualizar quick responses
      _onGroupSystemCommandsChanged?.call();
      
      debugPrint('✅ [CommandManagementProvider] Datos locales eliminados');
    } catch (e) {
      debugPrint('❌ [CommandManagementProvider] Error al eliminar datos: $e');
      rethrow;
    }
  }

  /// Elimina todos los comandos de usuario locales del dispositivo
  /// @deprecated Usar deleteAllLocalData() en su lugar
  Future<void> deleteAllLocalCommands() async {
    await deleteAllLocalData();
  }

  // ============================================================================
  // HELPERS PRIVADOS
  // ============================================================================

  Future<void> _reloadCommands() async {
    _commands = await _repository.getAllCommands();
    _sortCommands();
    notifyListeners();
  }
}