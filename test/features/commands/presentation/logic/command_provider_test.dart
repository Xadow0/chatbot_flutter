import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =============================================================================
// IMPORTACIONES DEL PROYECTO - AJUSTA ESTAS RUTAS SEGÚN TU ESTRUCTURA
// =============================================================================
import 'package:chatbot_app/features/commands/presentation/logic/command_provider.dart';
import 'package:chatbot_app/features/commands/domain/entities/command_entity.dart';
import 'package:chatbot_app/features/commands/domain/entities/command_folder_entity.dart';
import 'package:chatbot_app/features/commands/data/repositories/command_repository_impl.dart';
import 'package:chatbot_app/features/commands/data/datasources/firebase_command_sync.dart';
// =============================================================================
// MOCKS
// =============================================================================

class MockCommandRepositoryImpl extends Mock implements CommandRepositoryImpl {}

// =============================================================================
// FAKE CLASSES PARA REGISTERFALBACKVALUE
// =============================================================================

class FakeCommandEntity extends Fake implements CommandEntity {}

class FakeCommandFolderEntity extends Fake implements CommandFolderEntity {}

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

  late MockCommandRepositoryImpl mockRepository;
  late CommandManagementProvider provider;

  setUpAll(() {
    registerFallbackValue(FakeCommandEntity());
    registerFallbackValue(FakeCommandFolderEntity());
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    mockRepository = MockCommandRepositoryImpl();
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

    test('commandsWithoutFolder debe filtrar comandos de usuario sin carpeta', () {
      final cmdsWithoutFolder = provider.commandsWithoutFolder;
      expect(cmdsWithoutFolder.length, 2);
      expect(
        cmdsWithoutFolder.every((c) => c.folderId == null),
        isTrue,
      );
    });

    test('getCommandsInFolder debe retornar comandos de carpeta específica', () {
      final cmdsInFolder = provider.getCommandsInFolder('folder-1');
      expect(cmdsInFolder.length, 1);
      expect(cmdsInFolder.first.id, 'user-cmd-2');
    });

    test('getCommandsInFolder debe retornar lista vacía si no hay comandos', () {
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

    test('debe cargar preferencia groupSystemCommands=true desde SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': true});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(provider.groupSystemCommands, isTrue);
    });

    test('debe cargar preferencia groupSystemCommands=false por defecto', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(provider.groupSystemCommands, isFalse);
    });

    test('debe manejar errores en getAllFolders y establecer mensaje de error', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllFolders())
          .thenThrow(Exception('Error de folders'));

      await provider.loadCommands();

      expect(provider.error, contains('Error cargando comandos'));
      expect(provider.isLoading, isFalse);
    });

    test('debe manejar errores en getAllCommands y establecer mensaje de error', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllCommands())
          .thenThrow(Exception('Error de commands'));

      await provider.loadCommands();

      expect(provider.error, contains('Error cargando comandos'));
      expect(provider.isLoading, isFalse);
    });

    test('debe ejecutar syncAll cuando autoSync es true y no se ha sincronizado', () async {
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

      await provider.loadCommands(autoSync: true);
      await provider.loadCommands(autoSync: true);

      verify(() => mockRepository.syncAll()).called(1);
    });

    test('no debe ejecutar syncAll si autoSync es false', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands(autoSync: false);

      verifyNever(() => mockRepository.syncAll());
    });

    test('debe ordenar comandos (usuario primero, luego sistema, alfabético)', () async {
      SharedPreferences.setMockInitialValues({});

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

      expect(provider.commands[0].title, 'A Command');
      expect(provider.commands[1].title, 'M Command');
      expect(provider.commands[2].title, 'B System');
      expect(provider.commands[3].title, 'Z Command');
    });

    test('isLoading debe ser true durante la carga', () async {
      SharedPreferences.setMockInitialValues({});

      var loadingStates = <bool>[];

      provider.addListener(() {
        loadingStates.add(provider.isLoading);
      });

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(loadingStates.contains(true), isTrue);
      expect(loadingStates.last, isFalse);
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

      await provider.loadCommands(autoSync: true);

      provider.resetSyncStatus();

      await provider.loadCommands(autoSync: true);

      verify(() => mockRepository.syncAll()).called(2);
    });
  });

  // ===========================================================================
  // GRUPO: setOnGroupSystemCommandsChanged
  // ===========================================================================
  group('setOnGroupSystemCommandsChanged', () {
    test('debe aceptar un callback', () {
      var called = false;
      provider.setOnGroupSystemCommandsChanged(() {
        called = true;
      });

      expect(called, isFalse);
    });

    test('debe aceptar null', () {
      provider.setOnGroupSystemCommandsChanged(() {});
      provider.setOnGroupSystemCommandsChanged(null);
      // No debe lanzar excepción
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

    test('saveCommand debe lanzar excepción si el repositorio falla', () async {
      final command = createTestUserCommands().first;

      when(() => mockRepository.saveCommand(command))
          .thenThrow(Exception('Error de repositorio'));

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

    test('deleteCommand debe lanzar excepción si el repositorio falla', () async {
      when(() => mockRepository.deleteCommand('user-cmd-1'))
          .thenThrow(Exception('Error de repositorio'));

      expect(
        () => provider.deleteCommand('user-cmd-1'),
        throwsA(isA<Exception>()),
      );
    });

    test('moveCommandToFolder debe mover comando a carpeta', () async {
      when(() => mockRepository.moveCommandToFolder('user-cmd-1', 'folder-1'))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.moveCommandToFolder('user-cmd-1', 'folder-1');

      verify(() => mockRepository.moveCommandToFolder('user-cmd-1', 'folder-1'))
          .called(1);
      verify(() => mockRepository.getAllCommands()).called(1);
    });

    test('moveCommandToFolder con null debe sacar comando de carpeta', () async {
      when(() => mockRepository.moveCommandToFolder('user-cmd-2', null))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.moveCommandToFolder('user-cmd-2', null);

      verify(() => mockRepository.moveCommandToFolder('user-cmd-2', null))
          .called(1);
    });

    test('moveCommandToFolder debe lanzar excepción si el repositorio falla', () async {
      when(() => mockRepository.moveCommandToFolder('user-cmd-1', 'folder-1'))
          .thenThrow(Exception('Error de repositorio'));

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

    test('saveFolder debe lanzar excepción si el repositorio falla', () async {
      final folder = createTestFolders().first;

      when(() => mockRepository.saveFolder(folder))
          .thenThrow(Exception('Error de repositorio'));

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

    test('deleteFolder debe lanzar excepción si el repositorio falla', () async {
      when(() => mockRepository.deleteFolder('folder-1'))
          .thenThrow(Exception('Error de repositorio'));

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

    test('reorderFolders debe lanzar excepción si el repositorio falla', () async {
      final folderIds = ['folder-2', 'folder-1'];

      when(() => mockRepository.reorderFolders(folderIds))
          .thenThrow(Exception('Error de repositorio'));

      expect(
        () => provider.reorderFolders(folderIds),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ===========================================================================
  // GRUPO: Preferencias - setGroupSystemCommands
  // ===========================================================================
  group('Preferencias - setGroupSystemCommands', () {
    test('debe actualizar preferencia a true', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      await provider.setGroupSystemCommands(true);

      expect(provider.groupSystemCommands, isTrue);
      verify(() => mockRepository.saveGroupSystemPreference(true)).called(1);
    });

    test('debe actualizar preferencia a false', () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': true});

      when(() => mockRepository.saveGroupSystemPreference(false))
          .thenAnswer((_) async {});

      await provider.setGroupSystemCommands(false);

      expect(provider.groupSystemCommands, isFalse);
      verify(() => mockRepository.saveGroupSystemPreference(false)).called(1);
    });

    test('debe llamar callback cuando está configurado', () async {
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

    test('debe notificar a listeners', () async {
      SharedPreferences.setMockInitialValues({});

      var notified = false;
      provider.addListener(() => notified = true);

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      await provider.setGroupSystemCommands(true);

      expect(notified, isTrue);
    });

    test('debe guardar en SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      await provider.setGroupSystemCommands(true);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('group_system_commands'), isTrue);
    });

    test('debe manejar errores del repositorio silenciosamente', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenThrow(Exception('Error de Firebase'));

      // No debe lanzar excepción
      await provider.setGroupSystemCommands(true);

      // El valor local debe haberse actualizado
      expect(provider.groupSystemCommands, isTrue);
    });
  });

  // ===========================================================================
  // GRUPO: syncAllWithFirebase
  // ===========================================================================
  group('syncAllWithFirebase', () {
    test('debe sincronizar y actualizar estado correctamente', () async {
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
      expect(result.foldersUploaded, 1);
      expect(result.foldersDownloaded, 2);
      expect(result.commandsUploaded, 3);
      expect(result.commandsDownloaded, 4);
      expect(provider.isSyncing, isFalse);
    });

    test('debe aplicar preferencia remota si no hay preferencia local', () async {
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

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('group_system_commands'), isTrue);
    });

    test('debe preservar preferencia local si ya existe', () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': false});

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

      expect(provider.groupSystemCommands, isFalse);
    });

    test('debe subir preferencia local si no hay remota', () async {
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

    test('debe subir preferencia local false si no hay remota', () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': false});

      final syncResult = FullSyncResult(
        success: true,
        remoteGroupSystemCommands: null,
      );

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.saveGroupSystemPreference(false))
          .thenAnswer((_) async {});

      await provider.syncAllWithFirebase();

      verify(() => mockRepository.saveGroupSystemPreference(false)).called(1);
    });

    test('debe llamar callback de preferencias', () async {
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

      expect(syncingStates.contains(true), isTrue);
      expect(syncingStates.last, isFalse);
    });

    test('debe recargar comandos y carpetas después de sincronizar', () async {
      SharedPreferences.setMockInitialValues({});

      final syncResult = FullSyncResult(success: true);
      final testCommands = createAllTestCommands();
      final testFolders = createTestFolders();

      when(() => mockRepository.syncAll()).thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => testCommands);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => testFolders);
      when(() => mockRepository.saveGroupSystemPreference(any()))
          .thenAnswer((_) async {});

      await provider.syncAllWithFirebase();

      expect(provider.commands.length, testCommands.length);
      expect(provider.folders.length, testFolders.length);
    });

    test('isSyncing debe ser false incluso si ocurre error', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.syncAll())
          .thenThrow(Exception('Error de sync'));

      try {
        await provider.syncAllWithFirebase();
      } catch (_) {}

      expect(provider.isSyncing, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: syncWithFirebase
  // ===========================================================================
  group('syncWithFirebase', () {
    test('debe sincronizar solo comandos', () async {
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

    test('debe recargar comandos después de sincronizar', () async {
      SharedPreferences.setMockInitialValues({});

      final syncResult = CommandSyncResult(
        success: true,
        uploaded: 0,
        downloaded: 0,
      );
      final testCommands = createTestUserCommands();

      when(() => mockRepository.syncCommands())
          .thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => testCommands);

      await provider.syncWithFirebase();

      verify(() => mockRepository.getAllCommands()).called(1);
      expect(provider.commands.length, testCommands.length);
    });

    test('isSyncing debe ser true durante sincronización', () async {
      SharedPreferences.setMockInitialValues({});

      var syncingStates = <bool>[];

      provider.addListener(() {
        syncingStates.add(provider.isSyncing);
      });

      final syncResult = CommandSyncResult(
        success: true,
        uploaded: 0,
        downloaded: 0,
      );

      when(() => mockRepository.syncCommands())
          .thenAnswer((_) async => syncResult);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.syncWithFirebase();

      expect(syncingStates.contains(true), isTrue);
      expect(syncingStates.last, isFalse);
    });

    test('isSyncing debe ser false incluso si ocurre error', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.syncCommands())
          .thenThrow(Exception('Error de sync'));

      try {
        await provider.syncWithFirebase();
      } catch (_) {}

      expect(provider.isSyncing, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: deleteAllLocalData
  // ===========================================================================
  group('deleteAllLocalData', () {
    test('debe eliminar carpetas locales', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      verify(() => mockRepository.deleteAllLocalFolders()).called(1);
    });

    test('debe eliminar comandos locales', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      verify(() => mockRepository.deleteAllLocalCommands()).called(1);
    });

    test('debe limpiar SharedPreferences', () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': true});

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('group_system_commands'), isNull);
    });

    test('debe limpiar lista de folders en memoria', () async {
      SharedPreferences.setMockInitialValues({});

      // Cargar datos primero
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => createAllTestCommands());
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => createTestFolders());

      await provider.loadCommands();
      expect(provider.folders.isNotEmpty, isTrue);

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      expect(provider.folders, isEmpty);
    });

    test('debe eliminar comandos de usuario pero mantener sistema', () async {
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

      expect(provider.userCommands, isEmpty);
      expect(provider.systemCommands.length, 2);
    });

    test('debe resetear groupSystemCommands a false', () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': true});

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      await provider.setGroupSystemCommands(true);
      expect(provider.groupSystemCommands, isTrue);

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      expect(provider.groupSystemCommands, isFalse);
    });

    test('debe llamar callback de preferencias', () async {
      SharedPreferences.setMockInitialValues({});

      var callbackCalled = false;
      provider.setOnGroupSystemCommandsChanged(() {
        callbackCalled = true;
      });

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      expect(callbackCalled, isTrue);
    });

    test('debe notificar a listeners', () async {
      SharedPreferences.setMockInitialValues({});

      var notified = false;
      provider.addListener(() => notified = true);

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenAnswer((_) async {});

      await provider.deleteAllLocalData();

      expect(notified, isTrue);
    });

    test('debe propagar errores de deleteAllLocalFolders', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.deleteAllLocalFolders())
          .thenThrow(Exception('Error de prueba'));

      expect(
        () => provider.deleteAllLocalData(),
        throwsA(isA<Exception>()),
      );
    });

    test('debe propagar errores de deleteAllLocalCommands', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.deleteAllLocalFolders())
          .thenAnswer((_) async {});
      when(() => mockRepository.deleteAllLocalCommands())
          .thenThrow(Exception('Error de prueba'));

      expect(
        () => provider.deleteAllLocalData(),
        throwsA(isA<Exception>()),
      );
    });
  });

  // ===========================================================================
  // GRUPO: deleteAllLocalCommands (deprecated)
  // ===========================================================================
  group('deleteAllLocalCommands (deprecated)', () {
    test('debe llamar a deleteAllLocalData', () async {
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

      expect(notificationCount, greaterThanOrEqualTo(3));
    });

    test('saveCommand debe notificar después de guardar', () async {
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

    test('deleteCommand debe notificar después de eliminar', () async {
      SharedPreferences.setMockInitialValues({});

      var notified = false;
      provider.addListener(() => notified = true);

      when(() => mockRepository.deleteCommand('cmd-1'))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.deleteCommand('cmd-1');

      expect(notified, isTrue);
    });

    test('saveFolder debe notificar después de guardar', () async {
      SharedPreferences.setMockInitialValues({});

      var notified = false;
      provider.addListener(() => notified = true);

      final folder = createTestFolders().first;

      when(() => mockRepository.saveFolder(folder))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => [folder]);

      await provider.saveFolder(folder);

      expect(notified, isTrue);
    });

    test('deleteFolder debe notificar después de eliminar', () async {
      SharedPreferences.setMockInitialValues({});

      var notified = false;
      provider.addListener(() => notified = true);

      when(() => mockRepository.deleteFolder('folder-1'))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);

      await provider.deleteFolder('folder-1');

      expect(notified, isTrue);
    });

    test('reorderFolders debe notificar después de reordenar', () async {
      SharedPreferences.setMockInitialValues({});

      var notified = false;
      provider.addListener(() => notified = true);

      when(() => mockRepository.reorderFolders(any()))
          .thenAnswer((_) async {});
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.reorderFolders(['folder-1', 'folder-2']);

      expect(notified, isTrue);
    });
  });

  // ===========================================================================
  // GRUPO: Casos edge y cobertura adicional
  // ===========================================================================
  group('Casos edge y cobertura adicional', () {
    test('getFolderById con lista vacía debe retornar null', () {
      final folder = provider.getFolderById('cualquier-id');
      expect(folder, isNull);
    });

    test('getCommandsInFolder con lista vacía debe retornar lista vacía', () {
      final commands = provider.getCommandsInFolder('cualquier-id');
      expect(commands, isEmpty);
    });

    test('_loadGroupSystemPreference no debe cambiar valor si es igual', () async {
      SharedPreferences.setMockInitialValues({'group_system_commands': false});

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      // Cargar con valor por defecto (false)
      await provider.loadCommands();

      expect(provider.groupSystemCommands, isFalse);

      // Cargar de nuevo - el valor no debería cambiar
      await provider.loadCommands();

      expect(provider.groupSystemCommands, isFalse);
    });

    test('comandos deben ordenarse alfabéticamente dentro de su tipo', () async {
      SharedPreferences.setMockInitialValues({});

      final commands = [
        const CommandEntity(
          id: '1',
          trigger: '/c',
          title: 'C User',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.none,
        ),
        const CommandEntity(
          id: '2',
          trigger: '/a',
          title: 'A User',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.none,
        ),
        const CommandEntity(
          id: '3',
          trigger: '/b',
          title: 'B User',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.none,
        ),
      ];

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => commands);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(provider.commands[0].title, 'A User');
      expect(provider.commands[1].title, 'B User');
      expect(provider.commands[2].title, 'C User');
    });

    test('sistema antes de usuario cuando tienen el mismo título', () async {
      SharedPreferences.setMockInitialValues({});

      final commands = [
        const CommandEntity(
          id: '1',
          trigger: '/a',
          title: 'Same Title',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.traducir,
        ),
        const CommandEntity(
          id: '2',
          trigger: '/b',
          title: 'Same Title',
          description: '',
          promptTemplate: '',
          systemType: SystemCommandType.none,
        ),
      ];

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => commands);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      // Usuario debe ir primero
      expect(provider.commands[0].systemType, SystemCommandType.none);
      expect(provider.commands[1].systemType, SystemCommandType.traducir);
    });

    test('callback no se llama si no está configurado', () async {
      SharedPreferences.setMockInitialValues({});

      when(() => mockRepository.saveGroupSystemPreference(true))
          .thenAnswer((_) async {});

      // No configurar callback
      await provider.setGroupSystemCommands(true);

      // No debe lanzar excepción
      expect(provider.groupSystemCommands, isTrue);
    });

    test('múltiples listeners son notificados', () async {
      SharedPreferences.setMockInitialValues({});

      var listener1Called = false;
      var listener2Called = false;

      provider.addListener(() => listener1Called = true);
      provider.addListener(() => listener2Called = true);

      when(() => mockRepository.getAllCommands())
          .thenAnswer((_) async => []);
      when(() => mockRepository.getAllFolders())
          .thenAnswer((_) async => []);

      await provider.loadCommands();

      expect(listener1Called, isTrue);
      expect(listener2Called, isTrue);
    });
  });
}