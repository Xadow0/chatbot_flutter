import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Importaciones del proyecto (ajustar rutas según estructura real)
// import 'package:tu_app/features/commands/presentation/logic/command_provider.dart';
// import 'package:tu_app/features/commands/domain/entities/command_entity.dart';
// import 'package:tu_app/features/commands/domain/entities/command_folder_entity.dart';
// import 'package:tu_app/features/commands/data/repositories/command_repository_impl.dart';
// import 'package:tu_app/features/commands/data/datasources/firebase_command_sync.dart';

// =============================================================================
// NOTA: Descomenta las importaciones de arriba y ajusta las rutas según tu proyecto.
// Las clases y enums aquí incluidos son para que el archivo sea autocontenido en tests.
// =============================================================================

// -----------------------------------------------------------------------------
// ENUMS Y ENTIDADES (copia del código fuente para referencia en tests)
// -----------------------------------------------------------------------------

enum SystemCommandType {
  none,
  evaluarPrompt,
  traducir,
  resumir,
  codigo,
  corregir,
  explicar,
  comparar,
}

class CommandEntity {
  final String id;
  final String trigger;
  final String title;
  final String description;
  final String promptTemplate;
  final bool isSystem;
  final SystemCommandType systemType;
  final bool isEditable;
  final String? folderId;

  const CommandEntity({
    required this.id,
    required this.trigger,
    required this.title,
    required this.description,
    required this.promptTemplate,
    this.isSystem = false,
    this.systemType = SystemCommandType.none,
    this.isEditable = false,
    this.folderId,
  });

  CommandEntity copyWith({
    String? id,
    String? trigger,
    String? title,
    String? description,
    String? promptTemplate,
    bool? isSystem,
    SystemCommandType? systemType,
    bool? isEditable,
    String? folderId,
    bool clearFolderId = false,
  }) {
    return CommandEntity(
      id: id ?? this.id,
      trigger: trigger ?? this.trigger,
      title: title ?? this.title,
      description: description ?? this.description,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      isSystem: isSystem ?? this.isSystem,
      systemType: systemType ?? this.systemType,
      isEditable: isEditable ?? this.isEditable,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class CommandFolderEntity {
  final String id;
  final String name;
  final String? icon;
  final int order;
  final DateTime createdAt;

  const CommandFolderEntity({
    required this.id,
    required this.name,
    this.icon,
    this.order = 0,
    required this.createdAt,
  });

  CommandFolderEntity copyWith({
    String? id,
    String? name,
    String? icon,
    int? order,
    DateTime? createdAt,
  }) {
    return CommandFolderEntity(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CommandFolderEntity &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

// -----------------------------------------------------------------------------
// RESULT CLASSES
// -----------------------------------------------------------------------------

class CommandSyncResult {
  final bool success;
  final int uploaded;
  final int downloaded;
  final String? error;

  CommandSyncResult({
    required this.success,
    required this.uploaded,
    required this.downloaded,
    this.error,
  });
}

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
}

// -----------------------------------------------------------------------------
// REPOSITORY INTERFACE (para el mock)
// -----------------------------------------------------------------------------

abstract class CommandRepositoryImpl {
  Future<List<CommandEntity>> getAllCommands();
  Future<List<CommandFolderEntity>> getAllFolders();
  Future<void> saveCommand(CommandEntity command);
  Future<void> deleteCommand(String id);
  Future<void> moveCommandToFolder(String commandId, String? folderId);
  Future<void> saveFolder(CommandFolderEntity folder);
  Future<void> deleteFolder(String folderId);
  Future<void> reorderFolders(List<String> folderIds);
  Future<void> saveGroupSystemPreference(bool value);
  Future<bool?> getGroupSystemPreference();
  Future<FullSyncResult> syncAll();
  Future<CommandSyncResult> syncCommands();
  Future<void> deleteAllLocalCommands();
  Future<void> deleteAllLocalFolders();
}

// -----------------------------------------------------------------------------
// PROVIDER (copia del código fuente)
// -----------------------------------------------------------------------------

class CommandManagementProvider extends ChangeNotifier {
  final CommandRepositoryImpl _repository;

  List<CommandEntity> _commands = [];
  List<CommandFolderEntity> _folders = [];
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _error;
  bool _hasInitialSyncCompleted = false;

  bool _groupSystemCommands = false;

  VoidCallback? _onGroupSystemCommandsChanged;

  static const String _groupSystemCommandsKey = 'group_system_commands';

  CommandManagementProvider(this._repository);

  // GETTERS
  List<CommandEntity> get commands => _commands;
  List<CommandFolderEntity> get folders => _folders;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get error => _error;
  bool get groupSystemCommands => _groupSystemCommands;

  List<CommandEntity> get userCommands =>
      _commands.where((c) => c.systemType == SystemCommandType.none).toList();

  List<CommandEntity> get systemCommands =>
      _commands.where((c) => c.systemType != SystemCommandType.none).toList();

  List<CommandEntity> get commandsWithoutFolder =>
      userCommands.where((c) => c.folderId == null).toList();

  List<CommandEntity> getCommandsInFolder(String folderId) {
    return userCommands.where((c) => c.folderId == folderId).toList();
  }

  CommandFolderEntity? getFolderById(String folderId) {
    try {
      return _folders.firstWhere((f) => f.id == folderId);
    } catch (_) {
      return null;
    }
  }

  void setOnGroupSystemCommandsChanged(VoidCallback? callback) {
    _onGroupSystemCommandsChanged = callback;
  }

  Future<void> loadCommands({bool autoSync = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await _loadGroupSystemPreference();
      notifyListeners();

      if (autoSync && !_hasInitialSyncCompleted) {
        await syncAllWithFirebase();
        _hasInitialSyncCompleted = true;
      }

      _folders = await _repository.getAllFolders();
      _commands = await _repository.getAllCommands();
      _sortCommands();
    } catch (e) {
      debugPrint('❌ [CommandProvider] Error en loadCommands: $e');
      _error = 'Error cargando comandos: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadGroupSystemPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final loadedPref = prefs.getBool(_groupSystemCommandsKey) ?? false;

      if (_groupSystemCommands != loadedPref) {
        _groupSystemCommands = loadedPref;
        debugPrint(
            '⚙️ [CommandProvider] Preferencia local cargada: Agrupar = $_groupSystemCommands');
      }
    } catch (e) {
      debugPrint('⚠️ [CommandProvider] Error cargando preferencia: $e');
    }
  }

  void _sortCommands() {
    _commands.sort((a, b) {
      if (a.systemType == SystemCommandType.none &&
          b.systemType != SystemCommandType.none) return -1;
      if (a.systemType != SystemCommandType.none &&
          b.systemType == SystemCommandType.none) return 1;
      return a.title.compareTo(b.title);
    });
  }

  void resetSyncStatus() {
    _hasInitialSyncCompleted = false;
  }

  // COMANDOS - CRUD
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

  // CARPETAS - CRUD
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
      await _reloadCommands();
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

  // PREFERENCIAS
  Future<void> setGroupSystemCommands(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_groupSystemCommandsKey, value);

      _groupSystemCommands = value;

      await _repository.saveGroupSystemPreference(value);

      notifyListeners();

      _onGroupSystemCommandsChanged?.call();

      debugPrint(
          '✅ [CommandManagementProvider] Preferencia actualizada: groupSystemCommands=$value');
    } catch (e) {
      debugPrint('❌ [CommandManagementProvider] Error guardando preferencia: $e');
    }
  }

  // SINCRONIZACIÓN
  Future<FullSyncResult> syncAllWithFirebase() async {
    _isSyncing = true;
    notifyListeners();

    try {
      final result = await _repository.syncAll();

      if (result.remoteGroupSystemCommands != null) {
        final prefs = await SharedPreferences.getInstance();
        final localPref = prefs.getBool(_groupSystemCommandsKey);

        if (localPref == null) {
          _groupSystemCommands = result.remoteGroupSystemCommands!;
          await prefs.setBool(_groupSystemCommandsKey, _groupSystemCommands);
          debugPrint(
              '📥 [CommandManagementProvider] Preferencia sincronizada desde Firebase: $_groupSystemCommands');
        }
      } else {
        await _loadGroupSystemPreference();
        await _repository.saveGroupSystemPreference(_groupSystemCommands);
      }

      _folders = await _repository.getAllFolders();
      _commands = await _repository.getAllCommands();
      _sortCommands();

      _onGroupSystemCommandsChanged?.call();

      return result;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

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

  // LIMPIEZA
  Future<void> deleteAllLocalData() async {
    try {
      debugPrint('🗑️ [CommandManagementProvider] Eliminando datos locales...');

      await _repository.deleteAllLocalFolders();
      await _repository.deleteAllLocalCommands();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_groupSystemCommandsKey);

      _folders.clear();
      _commands.removeWhere((cmd) => cmd.systemType == SystemCommandType.none);
      _groupSystemCommands = false;

      notifyListeners();

      _onGroupSystemCommandsChanged?.call();

      debugPrint('✅ [CommandManagementProvider] Datos locales eliminados');
    } catch (e) {
      debugPrint('❌ [CommandManagementProvider] Error al eliminar datos: $e');
      rethrow;
    }
  }

  @Deprecated('Usar deleteAllLocalData() en su lugar')
  Future<void> deleteAllLocalCommands() async {
    await deleteAllLocalData();
  }

  // HELPERS PRIVADOS
  Future<void> _reloadCommands() async {
    _commands = await _repository.getAllCommands();
    _sortCommands();
    notifyListeners();
  }
}

// =============================================================================
// MOCKS
// =============================================================================

class MockCommandRepository extends Mock implements CommandRepositoryImpl {}

// =============================================================================
// TEST DATA HELPERS
// =============================================================================

/// Comandos de usuario de prueba
List<CommandEntity> createTestUserCommands() {
  return [
    const CommandEntity(
      id: 'user-cmd-1',
      trigger: '/micomando',
      title: 'Mi Comando',
      description: 'Descripción del comando',
      promptTemplate: 'Prompt template',
      isSystem: false,
      systemType: SystemCommandType.none,
    ),
    const CommandEntity(
      id: 'user-cmd-2',
      trigger: '/otro',
      title: 'Otro Comando',
      description: 'Otra descripción',
      promptTemplate: 'Otro prompt',
      isSystem: false,
      systemType: SystemCommandType.none,
      folderId: 'folder-1',
    ),
    const CommandEntity(
      id: 'user-cmd-3',
      trigger: '/tercero',
      title: 'Tercer Comando',
      description: 'Tercera descripción',
      promptTemplate: 'Tercer prompt',
      isSystem: false,
      systemType: SystemCommandType.none,
    ),
  ];
}

/// Comandos del sistema de prueba
List<CommandEntity> createTestSystemCommands() {
  return [
    const CommandEntity(
      id: 'sys-cmd-1',
      trigger: '/traducir',
      title: 'Traducir',
      description: 'Traduce texto',
      promptTemplate: 'Traduce: {{content}}',
      isSystem: true,
      systemType: SystemCommandType.traducir,
    ),
    const CommandEntity(
      id: 'sys-cmd-2',
      trigger: '/resumir',
      title: 'Resumir',
      description: 'Resume texto',
      promptTemplate: 'Resume: {{content}}',
      isSystem: true,
      systemType: SystemCommandType.resumir,
    ),
  ];
}

/// Carpetas de prueba
List<CommandFolderEntity> createTestFolders() {
  return [
    CommandFolderEntity(
      id: 'folder-1',
      name: 'Carpeta 1',
      icon: '📁',
      order: 0,
      createdAt: DateTime(2024, 1, 1),
    ),
    CommandFolderEntity(
      id: 'folder-2',
      name: 'Carpeta 2',
      icon: '📂',
      order: 1,
      createdAt: DateTime(2024, 1, 2),
    ),
  ];
}

/// Todos los comandos (usuario + sistema)
List<CommandEntity> createAllTestCommands() {
  return [...createTestUserCommands(), ...createTestSystemCommands()];
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockCommandRepository mockRepository;
  late CommandManagementProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepository = MockCommandRepository();
    provider = CommandManagementProvider(mockRepository);
  });

  tearDown(() {
    provider.dispose();
  });

  // ===========================================================================
  // GRUPO: Estado inicial
  // ===========================================================================
  group('Estado inicial', () {
    test('debe tener valores por defecto correctos', () {
      expect(provider.commands, isEmpty);
      expect(provider.folders, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.isSyncing, isFalse);
      expect(provider.error, isNull);
      expect(provider.groupSystemCommands, isFalse);
    });

    test('userCommands debe estar vacío inicialmente', () {
      expect(provider.userCommands, isEmpty);
    });

    test('systemCommands debe estar vacío inicialmente', () {
      expect(provider.systemCommands, isEmpty);
    });

    test('commandsWithoutFolder debe estar vacío inicialmente', () {
      expect(provider.commandsWithoutFolder, isEmpty);
    });
  });

  // ===========================================================================
  // GRUPO: Getters computados
  // ===========================================================================
  group('Getters computados', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => createAllTestCommands());
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => createTestFolders());

      await provider.loadCommands();
    });

    test('userCommands debe filtrar solo comandos de usuario', () {
      final userCmds = provider.userCommands;
      expect(userCmds.length, 3);
      expect(
        userCmds.every((c) => c.systemType == SystemCommandType.none),
        isTrue,
      );
    });

    test('systemCommands debe filtrar solo comandos del sistema', () {
      final sysCmds = provider.systemCommands;
      expect(sysCmds.length, 2);
      expect(
        sysCmds.every((c) => c.systemType != SystemCommandType.none),
        isTrue,
      );
    });

    test('commandsWithoutFolder debe filtrar comandos de usuario sin carpeta',
        () {
      final cmdsWithoutFolder = provider.commandsWithoutFolder;
      // user-cmd-1 y user-cmd-3 no tienen folderId
      expect(cmdsWithoutFolder.length, 2);
      expect(
        cmdsWithoutFolder.every((c) => c.folderId == null),
        isTrue,
      );
    });

    test('getCommandsInFolder debe retornar comandos de carpeta específica',
        () {
      final cmdsInFolder = provider.getCommandsInFolder('folder-1');
      expect(cmdsInFolder.length, 1);
      expect(cmdsInFolder.first.id, 'user-cmd-2');
    });

    test('getCommandsInFolder debe retornar lista vacía si no hay comandos',
        () {
      final cmdsInFolder = provider.getCommandsInFolder('folder-inexistente');
      expect(cmdsInFolder, isEmpty);
    });

    test('getFolderById debe retornar carpeta existente', () {
      final folder = provider.getFolderById('folder-1');
      expect(folder, isNotNull);
      expect(folder!.name, 'Carpeta 1');
    });

    test('getFolderById debe retornar null si no existe', () {
      final folder = provider.getFolderById('folder-inexistente');
      expect(folder, isNull);
    });
  });

  // ===========================================================================
  // GRUPO: loadCommands
  // ===========================================================================
  group('loadCommands', () {
    test('debe cargar comandos y carpetas correctamente', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => createAllTestCommands());
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => createTestFolders());

      await provider.loadCommands();

      expect(provider.commands.length, 5);
      expect(provider.folders.length, 2);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
    });

    test('debe cargar preferencia de groupSystemCommands desde SharedPreferences',
        () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': true});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(provider.groupSystemCommands, isTrue);
    });

    test('debe manejar errores y establecer mensaje de error', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllCommands())
          .thenThrow(Exception('Error de test'));
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(provider.error, contains('Error cargando comandos'));
      expect(provider.isLoading, isFalse);
    });

    test('debe ejecutar syncAll cuando autoSync es true y no se ha sincronizado',
        () async {
      SharedPreferences.setMockInitialValues({});

      final syncResult = FullSyncResult(success: true);

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.saveGroupSystemPreference(any()))
          .thenAnswer((_) async {});

      await provider.loadCommands(autoSync: true);

      verify(() => mockRepository.syncAll()).called(1);
    });

    test('no debe ejecutar syncAll si ya se sincronizó previamente', () async {
      SharedPreferences.setMockInitialValues({});

      final syncResult = FullSyncResult(success: true);

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.saveGroupSystemPreference(any()))
          .thenAnswer((_) async {});

      // Primera carga con autoSync
      await provider.loadCommands(autoSync: true);

      // Segunda carga con autoSync
      await provider.loadCommands(autoSync: true);

      // syncAll solo debe haberse llamado una vez
      verify(() => mockRepository.syncAll()).called(1);
    });

    test('debe ordenar comandos (usuario primero, luego sistema)', () async {
      SharedPreferences.setMockInitialValues({});

      // Retornar comandos en orden inverso
      final commands = [
        ...createTestSystemCommands(),
        ...createTestUserCommands(),
      ];

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => commands);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      // Los primeros deben ser de usuario (systemType == none)
      final firstThree = provider.commands.take(3).toList();
      expect(
        firstThree.every((c) => c.systemType == SystemCommandType.none),
        isTrue,
      );
    });
  });

  // ===========================================================================
  // GRUPO: resetSyncStatus
  // ===========================================================================
  group('resetSyncStatus', () {
    test('debe permitir resincronizar después de resetear', () async {
      SharedPreferences.setMockInitialValues({});

      final syncResult = FullSyncResult(success: true);

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.saveGroupSystemPreference(any()))
          .thenAnswer((_) async {});

      // Primera sincronización
      await provider.loadCommands(autoSync: true);

      // Reset del estado
      provider.resetSyncStatus();

      // Segunda sincronización (debería ejecutarse)
      await provider.loadCommands(autoSync: true);

      verify(() => mockRepository.syncAll()).called(2);
    });
  });

  // ===========================================================================
  // GRUPO: CRUD de Comandos
  // ===========================================================================
  group('CRUD de Comandos', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveCommand debe guardar y recargar comandos', () async {
      final command = createTestUserCommands().first;

      when(() => mockRepository.saveCommand(command))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => [command]);

      await provider.saveCommand(command);

      verify(() => mockRepository.saveCommand(command)).called(1);
      verify(() => mockRepository.getAllCommands()).called(1);
      expect(provider.commands.length, 1);
    });

    test('saveCommand debe lanzar excepción si falla', () async {
      final command = createTestUserCommands().first;

      when(() => mockRepository.saveCommand(command))
          .thenThrow(Exception('Error'));

      expect(
        () => provider.saveCommand(command),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteCommand debe eliminar y recargar comandos', () async {
      when(() => mockRepository.deleteCommand('user-cmd-1'))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.deleteCommand('user-cmd-1');

      verify(() => mockRepository.deleteCommand('user-cmd-1')).called(1);
      verify(() => mockRepository.getAllCommands()).called(1);
    });

    test('deleteCommand debe lanzar excepción si falla', () async {
      when(() => mockRepository.deleteCommand('user-cmd-1'))
          .thenThrow(Exception('Error'));

      expect(
        () => provider.deleteCommand('user-cmd-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('moveCommandToFolder debe mover y recargar comandos', () async {
      when(() => mockRepository.moveCommandToFolder('user-cmd-1', 'folder-1'))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.moveCommandToFolder('user-cmd-1', 'folder-1');

      verify(() => mockRepository.moveCommandToFolder('user-cmd-1', 'folder-1'))
          .called(1);
    });

    test('moveCommandToFolder con null debe sacar de carpeta', () async {
      when(() => mockRepository.moveCommandToFolder('user-cmd-2', null))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.moveCommandToFolder('user-cmd-2', null);

      verify(() => mockRepository.moveCommandToFolder('user-cmd-2', null))
          .called(1);
    });

    test('moveCommandToFolder debe lanzar excepción si falla', () async {
      when(() => mockRepository.moveCommandToFolder('user-cmd-1', 'folder-1'))
          .thenThrow(Exception('Error'));

      expect(
        () => provider.moveCommandToFolder('user-cmd-1', 'folder-1'),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ===========================================================================
  // GRUPO: CRUD de Carpetas
  // ===========================================================================
  group('CRUD de Carpetas', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('saveFolder debe guardar y recargar carpetas', () async {
      final folder = createTestFolders().first;

      when(() => mockRepository.saveFolder(folder))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => [folder]);

      await provider.saveFolder(folder);

      verify(() => mockRepository.saveFolder(folder)).called(1);
      verify(() => mockRepository.getAllFolders()).called(1);
      expect(provider.folders.length, 1);
    });

    test('saveFolder debe lanzar excepción si falla', () async {
      final folder = createTestFolders().first;

      when(() => mockRepository.saveFolder(folder))
          .thenThrow(Exception('Error'));

      expect(
        () => provider.saveFolder(folder),
        throwsA(isA<Exception>()),
      );
    });

    test('deleteFolder debe eliminar carpeta y recargar datos', () async {
      when(() => mockRepository.deleteFolder('folder-1'))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.deleteFolder('folder-1');

      verify(() => mockRepository.deleteFolder('folder-1')).called(1);
      verify(() => mockRepository.getAllFolders()).called(1);
      verify(() => mockRepository.getAllCommands()).called(1);
    });

    test('deleteFolder debe lanzar excepción si falla', () async {
      when(() => mockRepository.deleteFolder('folder-1'))
          .thenThrow(Exception('Error'));

      expect(
        () => provider.deleteFolder('folder-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('reorderFolders debe reordenar y recargar carpetas', () async {
      final folderIds = ['folder-2', 'folder-1'];

      when(() => mockRepository.reorderFolders(folderIds))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => createTestFolders().reversed.toList());

      await provider.reorderFolders(folderIds);

      verify(() => mockRepository.reorderFolders(folderIds)).called(1);
      verify(() => mockRepository.getAllFolders()).called(1);
    });

    test('reorderFolders debe lanzar excepción si falla', () async {
      final folderIds = ['folder-2', 'folder-1'];

      when(() => mockRepository.reorderFolders(folderIds))
          .thenThrow(Exception('Error'));

      expect(
        () => provider.reorderFolders(folderIds),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ===========================================================================
  // GRUPO: Preferencias
  // ===========================================================================
  group('Preferencias - groupSystemCommands', () {
    test('setGroupSystemCommands debe actualizar preferencia', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      await provider.setGroupSystemCommands(true);

      expect(provider.groupSystemCommands, isTrue);
      verify(() => mockRepository.saveGroupSystemPreference(true)).called(1);
    });

    test('setGroupSystemCommands debe llamar callback cuando está configurado',
        () async {
      SharedPreferences.setMockInitialValues({});

      var callbackCalled = false;
      provider.setOnGroupSystemCommandsChanged(() {
        callbackCalled = true;
      });

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      await provider.setGroupSystemCommands(true);

      expect(callbackCalled, isTrue);
    });

    test('setOnGroupSystemCommandsChanged debe aceptar null', () {
      provider.setOnGroupSystemCommandsChanged(() {});
      provider.setOnGroupSystemCommandsChanged(null);
      // No debe lanzar excepción
    });
  });

  // ===========================================================================
  // GRUPO: Sincronización
  // ===========================================================================
  group('Sincronización', () {
    test('syncAllWithFirebase debe sincronizar y actualizar estado', () async {
      SharedPreferences.setMockInitialValues({});

      final syncResult = FullSyncResult(
        success: true,
        foldersUploaded: 1,
        foldersDownloaded: 2,
        commandsUploaded: 3,
        commandsDownloaded: 4,
      );

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.saveGroupSystemPreference(any()))
          .thenAnswer((_) async {});

      final result = await provider.syncAllWithFirebase();

      expect(result.success, isTrue);
      expect(provider.isSyncing, isFalse);
      verify(() => mockRepository.syncAll()).called(1);
    });

    test('syncAllWithFirebase debe aplicar preferencia remota si no hay local',
        () async {
      SharedPreferences.setMockInitialValues({});

      final syncResult = FullSyncResult(
        success: true,
        remoteGroupSystemCommands: true,
      );

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.syncAllWithFirebase();

      expect(provider.groupSystemCommands, isTrue);
    });

    test('syncAllWithFirebase debe subir preferencia local si no hay remota',
        () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': true});

      final syncResult = FullSyncResult(
        success: true,
        remoteGroupSystemCommands: null,
      );

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      await provider.syncAllWithFirebase();

      verify(() => mockRepository.saveGroupSystemPreference(true)).called(1);
    });

    test('syncAllWithFirebase debe llamar callback de preferencias', () async {
      SharedPreferences.setMockInitialValues({});

      var callbackCalled = false;
      provider.setOnGroupSystemCommandsChanged(() {
        callbackCalled = true;
      });

      final syncResult = FullSyncResult(success: true);

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.saveGroupSystemPreference(any()))
          .thenAnswer((_) async {});

      await provider.syncAllWithFirebase();

      expect(callbackCalled, isTrue);
    });

    test('syncWithFirebase debe sincronizar solo comandos', () async {
      SharedPreferences.setMockInitialValues({});

      final syncResult = CommandSyncResult(
        success: true,
        uploaded: 2,
        downloaded: 3,
      );

      when(() => mockRepository.syncCommands())
          .thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      final result = await provider.syncWithFirebase();

      expect(result.success, isTrue);
      expect(result.uploaded, 2);
      expect(result.downloaded, 3);
      verify(() => mockRepository.syncCommands()).called(1);
    });

    test('isSyncing debe ser true durante sincronización', () async {
      SharedPreferences.setMockInitialValues({});

      var syncingStates = <bool>[];

      provider.addListener(() {
        syncingStates.add(provider.isSyncing);
      });

      final syncResult = FullSyncResult(success: true);

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.saveGroupSystemPreference(any()))
          .thenAnswer((_) async {});

      await provider.syncAllWithFirebase();

      // Debe haber pasado por true y luego false
      expect(syncingStates.contains(true), isTrue);
      expect(syncingStates.last, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: Limpieza de datos
  // ===========================================================================
  group('Limpieza de datos', () {
    test('deleteAllLocalData debe eliminar todos los datos locales', () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': true});

      // Cargar datos primero
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => createAllTestCommands());
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => createTestFolders());

      await provider.loadCommands();

      expect(provider.folders.isNotEmpty, isTrue);
      expect(provider.commands.isNotEmpty, isTrue);

      // Configurar mocks para eliminación
      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      verify(() => mockRepository.deleteAllLocalFolders()).called(1);
      verify(() => mockRepository.deleteAllLocalCommands()).called(1);
      expect(provider.folders, isEmpty);
      expect(provider.groupSystemCommands, isFalse);

      // Verificar que SharedPreferences se limpió
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('group_system_commands'), isNull);
    });

    test('deleteAllLocalData debe eliminar comandos de usuario pero mantener sistema',
        () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => createAllTestCommands());
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(provider.userCommands.length, 3);
      expect(provider.systemCommands.length, 2);

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      // Comandos de usuario eliminados, sistema permanecen
      expect(provider.userCommands, isEmpty);
      expect(provider.systemCommands.length, 2);
    });

    test('deleteAllLocalData debe llamar callback de preferencias', () async {
      SharedPreferences.setMockInitialValues({});

      var callbackCalled = false;
      provider.setOnGroupSystemCommandsChanged(() {
        callbackCalled = true;
      });

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      expect(callbackCalled, isTrue);
    });

    test('deleteAllLocalData debe propagar errores', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.deleteAllLocalFolders())
          .thenThrow(Exception('Error de prueba'));

      expect(
        () => provider.deleteAllLocalData(),
        throwsA(isA<Exception>()),
      );
    });

    // ignore: deprecated_member_use_from_same_package
    test('deleteAllLocalCommands (deprecated) debe llamar a deleteAllLocalData',
        () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      // ignore: deprecated_member_use_from_same_package
      await provider.deleteAllLocalCommands();

      verify(() => mockRepository.deleteAllLocalFolders()).called(1);
      verify(() => mockRepository.deleteAllLocalCommands()).called(1);
    });
  });

  // ===========================================================================
  // GRUPO: Notificaciones a listeners
  // ===========================================================================
  group('Notificaciones a listeners', () {
    test('loadCommands debe notificar múltiples veces', () async {
      SharedPreferences.setMockInitialValues({});

      var notificationCount = 0;
      provider.addListener(() => notificationCount++);

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      // Debe notificar al menos:
      // 1. Al iniciar (isLoading = true)
      // 2. Después de cargar preferencia
      // 3. Al finalizar (isLoading = false)
      expect(notificationCount, greaterThanOrEqualTo(3));
    });

    test('saveCommand debe notificar después de recargar', () async {
      SharedPreferences.setMockInitialValues({});

      var notified = false;
      provider.addListener(() => notified = true);

      final command = createTestUserCommands().first;

      when(() => mockRepository.saveCommand(command))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => [command]);

      await provider.saveCommand(command);

      expect(notified, isTrue);
    });

    test('setGroupSystemCommands debe notificar', () async {
      SharedPreferences.setMockInitialValues({});

      var notified = false;
      provider.addListener(() => notified = true);

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      await provider.setGroupSystemCommands(true);

      expect(notified, isTrue);
    });
  });

  // ===========================================================================
  // GRUPO: Casos edge
  // ===========================================================================
  group('Casos edge', () {
    test('getFolderById con lista vacía debe retornar null', () {
      final folder = provider.getFolderById('cualquier-id');
      expect(folder, isNull);
    });

    test('getCommandsInFolder con lista vacía debe retornar lista vacía', () {
      final commands = provider.getCommandsInFolder('cualquier-id');
      expect(commands, isEmpty);
    });

    test('loadCommands debe manejar SharedPreferences vacíos', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(provider.groupSystemCommands, isFalse);
      expect(provider.error, isNull);
    });

    test('_sortCommands debe ordenar correctamente comandos mixtos', () async {
      SharedPreferences.setMockInitialValues({});

      // Crear lista con orden específico para verificar ordenamiento
      final commands = [
        const CommandEntity(
          id: '1',
          trigger: '/z',
          title: 'Z Command',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.traducir,
        ),
        const CommandEntity(
          id: '2',
          trigger: '/a',
          title: 'A Command',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.none,
        ),
        const CommandEntity(
          id: '3',
          trigger: '/m',
          title: 'M Command',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.none,
        ),
        const CommandEntity(
          id: '4',
          trigger: '/b',
          title: 'B System',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.resumir,
        ),
      ];

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => commands);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      // Verificar orden: usuario primero (alfabético), luego sistema (alfabético)
      expect(provider.commands[0].title, 'A Command');
      expect(provider.commands[1].title, 'M Command');
      expect(provider.commands[2].title, 'B System');
      expect(provider.commands[3].title, 'Z Command');
    });

    test('syncAllWithFirebase debe preservar preferencia local sobre remota',
        () async {
      // Si ya existe preferencia local, no debe sobrescribirse con remota
      SharedPreferences.setMockInitialValues({'group_system_commands': false});

      final syncResult = FullSyncResult(
        success: true,
        remoteGroupSystemCommands: true, // Remoto dice true
      );

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.syncAllWithFirebase();

      // Debe mantener el valor local (false), no el remoto (true)
      expect(provider.groupSystemCommands, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: Manejo de errores en preferencias
  // ===========================================================================
  group('Manejo de errores en preferencias', () {
    test('setGroupSystemCommands debe manejar errores silenciosamente',
        () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenThrow(Exception('Error de Firebase'));

      // No debe lanzar excepción
      await provider.setGroupSystemCommands(true);

      // El valor local debe haberse actualizado aunque Firebase falle
      expect(provider.groupSystemCommands, isTrue);
    });
  });
}