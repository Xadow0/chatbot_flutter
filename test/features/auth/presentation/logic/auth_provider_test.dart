import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
// Ocultar AuthProvider de firebase_auth para evitar conflicto de nombres
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

// =============================================================================
// IMPORTACIONES DEL PROYECTO - AJUSTA ESTAS RUTAS SEGÚN TU ESTRUCTURA
// =============================================================================
import 'package:chatbot_app/features/auth/presentation/logic/auth_provider.dart';
import 'package:chatbot_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:chatbot_app/features/auth/data/datasources/firebase_sync_service.dart';
import 'package:chatbot_app/features/commands/presentation/logic/command_provider.dart';
import 'package:chatbot_app/features/commands/data/datasources/firebase_command_sync.dart';

// =============================================================================
// MOCKS
// =============================================================================

class MockAuthRepository extends Mock implements AuthRepository {}

class MockCommandManagementProvider extends Mock
    implements CommandManagementProvider {}

class MockUser extends Mock implements User {}

class MockUserCredential extends Mock implements UserCredential {}

// =============================================================================
// FAKES PARA FALLBACK VALUES
// =============================================================================

class FakeCommandSyncResult extends Fake implements CommandSyncResult {}

class FakeSyncResult extends Fake implements SyncResult {}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository mockAuthRepository;
  late MockCommandManagementProvider mockCommandProvider;
  late AuthProvider authProvider;
  late StreamController<User?> authStateController;
  late MockUserCredential mockUserCredential;

  setUpAll(() {
    registerFallbackValue(FakeCommandSyncResult());
    registerFallbackValue(FakeSyncResult());
  });

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    mockCommandProvider = MockCommandManagementProvider();
    authStateController = StreamController<User?>.broadcast();
    mockUserCredential = MockUserCredential();

    // Configurar el stream de authStateChanges por defecto
    when(() => mockAuthRepository.authStateChanges)
        .thenAnswer((_) => authStateController.stream);
    when(() => mockAuthRepository.getCloudSyncEnabled())
        .thenAnswer((_) async => false);

    authProvider = AuthProvider(authRepository: mockAuthRepository);
  });

  tearDown(() {
    authStateController.close();
    authProvider.dispose();
  });

  // ===========================================================================
  // GRUPO: Estado inicial
  // ===========================================================================
  group('Estado inicial', () {
    test('debe tener valores por defecto correctos', () {
      expect(authProvider.user, isNull);
      expect(authProvider.isCloudSyncEnabled, isFalse);
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.isSyncing, isFalse);
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.syncMessage, isNull);
      expect(authProvider.isAuthenticated, isFalse);
      expect(authProvider.canActivateSyncWithoutPassword, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: authStateChanges listener
  // ===========================================================================
  group('authStateChanges listener', () {
    test('debe actualizar user cuando el stream emite un usuario', () async {
      final mockUser = MockUser();

      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      authStateController.add(mockUser);

      await Future.delayed(const Duration(milliseconds: 50));

      expect(authProvider.user, mockUser);
      expect(authProvider.isAuthenticated, isTrue);
    });

    test('debe limpiar user y sync cuando el stream emite null', () async {
      final mockUser = MockUser();

      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => true);

      // Primero emitir un usuario
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authProvider.user, mockUser);

      // Luego emitir null (logout)
      authStateController.add(null);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authProvider.user, isNull);
      expect(authProvider.isCloudSyncEnabled, isFalse);
      expect(authProvider.isAuthenticated, isFalse);
    });

    test('debe cargar estado de cloudSync cuando hay usuario', () async {
      final mockUser = MockUser();

      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => true);

      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      expect(authProvider.isCloudSyncEnabled, isTrue);
    });
  });

  // ===========================================================================
  // GRUPO: setCommandProvider
  // ===========================================================================
  group('setCommandProvider', () {
    test('debe configurar el commandProvider', () {
      authProvider.setCommandProvider(mockCommandProvider);
      // No hay forma directa de verificar, pero no debe lanzar excepción
    });
  });

  // ===========================================================================
  // GRUPO: signIn
  // ===========================================================================
  group('signIn', () {
    test('debe iniciar sesión correctamente', () async {
      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'password123');

      verify(() => mockAuthRepository.signIn(
            email: 'test@test.com',
            password: 'password123',
          )).called(1);
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('debe sincronizar si cloudSync estaba activo', () async {
      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => true);
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.signIn('test@test.com', 'password123');

      expect(authProvider.isCloudSyncEnabled, isTrue);
      verify(() => mockAuthRepository.syncConversations()).called(1);
    });

    test('debe sincronizar con commandProvider si está configurado', () async {
      authProvider.setCommandProvider(mockCommandProvider);

      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => true);
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 1, downloaded: 2),
      );
      when(() => mockCommandProvider.resetSyncStatus()).thenReturn(null);
      when(() => mockCommandProvider.syncWithFirebase()).thenAnswer(
        (_) async => CommandSyncResult(
          success: true,
          uploaded: 1,
          downloaded: 1,
        ),
      );

      await authProvider.signIn('test@test.com', 'password123');

      verify(() => mockCommandProvider.resetSyncStatus()).called(1);
      verify(() => mockCommandProvider.syncWithFirebase()).called(1);
    });

    test('debe manejar errores de autenticación', () async {
      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Invalid credentials'));
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'wrongpassword');

      expect(authProvider.errorMessage, contains('Invalid credentials'));
      expect(authProvider.isLoading, isFalse);
      expect(authProvider.canActivateSyncWithoutPassword, isFalse);
    });

    test('isLoading debe ser true durante la operación', () async {
      final completer = Completer<UserCredential>();
      var loadingStates = <bool>[];

      authProvider.addListener(() {
        loadingStates.add(authProvider.isLoading);
      });

      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) => completer.future);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      final future = authProvider.signIn('test@test.com', 'password123');

      await Future.delayed(const Duration(milliseconds: 10));
      expect(loadingStates.contains(true), isTrue);

      completer.complete(mockUserCredential);
      await future;

      expect(authProvider.isLoading, isFalse);
    });

    test('debe habilitar canActivateSyncWithoutPassword después del login', () async {
      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'password123');

      expect(authProvider.canActivateSyncWithoutPassword, isTrue);
    });
  });

  // ===========================================================================
  // GRUPO: signUp
  // ===========================================================================
  group('signUp', () {
    test('debe registrar usuario y activar sync automáticamente', () async {
      when(() => mockAuthRepository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.setCloudSyncEnabled(
            any(),
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.signUp('test@test.com', 'password123');

      verify(() => mockAuthRepository.signUp(
            email: 'test@test.com',
            password: 'password123',
          )).called(1);
      expect(authProvider.errorMessage, isNull);
      expect(authProvider.isLoading, isFalse);
    });

    test('debe manejar errores de registro', () async {
      when(() => mockAuthRepository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Email already in use'));

      await authProvider.signUp('test@test.com', 'password123');

      expect(authProvider.errorMessage, contains('Email already in use'));
      expect(authProvider.isLoading, isFalse);
    });

    test('debe limpiar contraseña temporal después del registro', () async {
      when(() => mockAuthRepository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.setCloudSyncEnabled(
            any(),
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.signUp('test@test.com', 'password123');

      expect(authProvider.canActivateSyncWithoutPassword, isFalse);
    });

    test('isLoading debe ser true durante la operación', () async {
      var loadingStates = <bool>[];

      authProvider.addListener(() {
        loadingStates.add(authProvider.isLoading);
      });

      when(() => mockAuthRepository.signUp(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.setCloudSyncEnabled(
            any(),
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.signUp('test@test.com', 'password123');

      expect(loadingStates.contains(true), isTrue);
      expect(authProvider.isLoading, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: signOut
  // ===========================================================================
  group('signOut', () {
    test('debe cerrar sesión correctamente', () async {
      when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

      await authProvider.signOut();

      verify(() => mockAuthRepository.signOut()).called(1);
      expect(authProvider.isCloudSyncEnabled, isFalse);
      expect(authProvider.isLoading, isFalse);
    });

    test('debe limpiar contraseña temporal', () async {
      // Primero hacer login para tener contraseña temporal
      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'password123');
      expect(authProvider.canActivateSyncWithoutPassword, isTrue);

      when(() => mockAuthRepository.signOut()).thenAnswer((_) async {});

      await authProvider.signOut();

      expect(authProvider.canActivateSyncWithoutPassword, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: deleteAccount
  // ===========================================================================
  group('deleteAccount', () {
    test('debe mostrar error si no hay usuario autenticado', () async {
      await authProvider.deleteAccount('password123');

      expect(authProvider.errorMessage, contains('No hay usuario autenticado'));
    });

    test('debe eliminar cuenta correctamente', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenAnswer((_) async {});

      await authProvider.deleteAccount('password123');

      verify(() => mockAuthRepository.deleteAccount(password: 'password123'))
          .called(1);
      expect(authProvider.user, isNull);
      expect(authProvider.isCloudSyncEnabled, isFalse);
      expect(authProvider.errorMessage, isNull);
    });

    test('debe eliminar comandos locales si hay commandProvider', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      authProvider.setCommandProvider(mockCommandProvider);

      when(() => mockCommandProvider.deleteAllLocalCommands())
          .thenAnswer((_) async {});
      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenAnswer((_) async {});

      await authProvider.deleteAccount('password123');

      verify(() => mockCommandProvider.deleteAllLocalCommands()).called(1);
    });

    test('debe manejar error wrong-password', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'wrong-password', message: 'The password is invalid or the user does not have a password.'));

      await authProvider.deleteAccount('wrongpassword');

      expect(authProvider.errorMessage, contains('Contraseña incorrecta'));
    });

    test('debe manejar error requires-recent-login', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'requires-recent-login', message: 'This operation is sensitive and requires recent authentication. Log in again before retrying this request.'));

      await authProvider.deleteAccount('password123');

      expect(authProvider.errorMessage, contains('cerrar sesión'));
    });

    test('debe manejar error timeout', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'timeout', message: 'The operation has timed out.'));

      await authProvider.deleteAccount('password123');

      expect(authProvider.errorMessage, contains('tardó demasiado'));
    });

    test('debe manejar error network-request-failed', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'network-request-failed', message: 'A network error occurred.'));

      await authProvider.deleteAccount('password123');

      expect(authProvider.errorMessage, contains('conexión'));
    });

    test('debe manejar otros errores de FirebaseAuth', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenThrow(FirebaseAuthException(code: 'unknown-error', message: 'An unknown error occurred.'));

      await authProvider.deleteAccount('password123');

      expect(authProvider.errorMessage, isNotNull);
    });

    test('debe manejar errores inesperados', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenThrow(Exception('Unexpected error'));

      await authProvider.deleteAccount('password123');

      expect(authProvider.errorMessage, contains('inesperado'));
    });

    test('isLoading debe ser true durante la operación', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      var loadingStates = <bool>[];

      authProvider.addListener(() {
        loadingStates.add(authProvider.isLoading);
      });

      when(() => mockAuthRepository.deleteAccount(password: any(named: 'password')))
          .thenAnswer((_) async {});

      await authProvider.deleteAccount('password123');

      expect(loadingStates.contains(true), isTrue);
      expect(authProvider.isLoading, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: toggleCloudSync
  // ===========================================================================
  group('toggleCloudSync', () {
    test('debe mostrar error si no hay usuario', () async {
      await authProvider.toggleCloudSync(true);

      expect(authProvider.errorMessage, contains('iniciar sesión'));
    });

    test('debe desactivar sync sin requerir contraseña', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(false))
          .thenAnswer((_) async {});

      await authProvider.toggleCloudSync(false);

      verify(() => mockAuthRepository.setCloudSyncEnabled(false)).called(1);
      expect(authProvider.isCloudSyncEnabled, isFalse);
      expect(authProvider.syncMessage, isNull);
    });

    test('debe activar sync con contraseña temporal si está disponible', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      // Login para obtener contraseña temporal
      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'password123');

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: 'password123',
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSync(true);

      verify(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: 'password123',
          )).called(1);
      expect(authProvider.isCloudSyncEnabled, isTrue);
    });

    test('debe solicitar contraseña si no hay temporal', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      await authProvider.toggleCloudSync(true);

      expect(authProvider.errorMessage, contains('contraseña'));
    });
  });

  // ===========================================================================
  // GRUPO: toggleCloudSyncWithPassword
  // ===========================================================================
  group('toggleCloudSyncWithPassword', () {
    test('debe mostrar error si no hay usuario', () async {
      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.errorMessage, contains('iniciar sesión'));
    });

    test('debe desactivar sync correctamente', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(false))
          .thenAnswer((_) async {});

      await authProvider.toggleCloudSyncWithPassword(false, 'password123');

      verify(() => mockAuthRepository.setCloudSyncEnabled(false)).called(1);
      expect(authProvider.isCloudSyncEnabled, isFalse);
    });

    test('debe activar sync con contraseña', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: 'password123',
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      verify(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: 'password123',
          )).called(1);
      expect(authProvider.isCloudSyncEnabled, isTrue);
    });

    test('debe sincronizar después de activar', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 2, downloaded: 3),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      verify(() => mockAuthRepository.syncConversations()).called(1);
    });

    test('debe manejar errores al activar sync', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenThrow(Exception('Encryption error'));

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.errorMessage, contains('Encryption error'));
      expect(authProvider.isCloudSyncEnabled, isFalse);
    });

    test('isSyncing debe ser true durante la activación', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      var syncingStates = <bool>[];

      authProvider.addListener(() {
        syncingStates.add(authProvider.isSyncing);
      });

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(syncingStates.contains(true), isTrue);
      expect(authProvider.isSyncing, isFalse);
    });

    test('debe limpiar contraseña temporal después de activar sync', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      // Login para tener contraseña temporal
      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'password123');
      expect(authProvider.canActivateSyncWithoutPassword, isTrue);

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.canActivateSyncWithoutPassword, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: manualSync / _performSync
  // ===========================================================================
  group('manualSync / _performSync', () {
    test('debe mostrar error si sync no está activado', () async {
      await authProvider.manualSync();

      expect(authProvider.errorMessage, contains('no está activada'));
    });

    test('debe sincronizar cuando está activo', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      // Activar sync
      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      // Hacer manual sync
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 1, downloaded: 2),
      );

      await authProvider.manualSync();

      // Verificar que se llamó syncConversations (además de la activación)
      verify(() => mockAuthRepository.syncConversations()).called(2);
    });

    test('debe mostrar mensaje cuando hay subidas/descargas', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 5, downloaded: 3),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.syncMessage, contains('Sincronizado'));
    });

    test('debe mostrar "Todo sincronizado" cuando no hay cambios', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.syncMessage, contains('Todo sincronizado'));
    });

    test('debe mostrar error cuando falla la sincronización', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(
          success: false,
          uploaded: 0,
          downloaded: 0,
          error: 'Network error',
        ),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.syncMessage, contains('Error'));
    });

    test('debe sincronizar comandos con commandProvider', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      authProvider.setCommandProvider(mockCommandProvider);

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 1, downloaded: 1),
      );
      when(() => mockCommandProvider.resetSyncStatus()).thenReturn(null);
      when(() => mockCommandProvider.syncWithFirebase()).thenAnswer(
        (_) async => CommandSyncResult(
          success: true,
          uploaded: 2,
          downloaded: 2,
        ),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      verify(() => mockCommandProvider.syncWithFirebase()).called(1);
      expect(authProvider.syncMessage, contains('Sincronizado'));
    });

    test('debe mostrar errores combinados de conversaciones y comandos', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      authProvider.setCommandProvider(mockCommandProvider);

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(
          success: false,
          uploaded: 0,
          downloaded: 0,
          error: 'Conv error',
        ),
      );
      when(() => mockCommandProvider.resetSyncStatus()).thenReturn(null);
      when(() => mockCommandProvider.syncWithFirebase()).thenAnswer(
        (_) async => CommandSyncResult(
          success: false,
          uploaded: 0,
          downloaded: 0,
          error: 'Cmd error',
        ),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.syncMessage, contains('Error'));
    });

    test('debe manejar excepciones durante sync', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations())
          .thenThrow(Exception('Sync exception'));

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.syncMessage, contains('Error'));
    });

    test('isSyncing debe ser true durante la sincronización', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      // Primero activar sync
      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      var syncingStates = <bool>[];
      authProvider.addListener(() {
        syncingStates.add(authProvider.isSyncing);
      });

      // Luego hacer manual sync
      final completer = Completer<SyncResult>();
      when(() => mockAuthRepository.syncConversations())
          .thenAnswer((_) => completer.future);

      final future = authProvider.manualSync();

      await Future.delayed(const Duration(milliseconds: 10));
      expect(syncingStates.contains(true), isTrue);

      completer.complete(SyncResult(success: true, uploaded: 0, downloaded: 0));
      await future;

      expect(authProvider.isSyncing, isFalse);
    });
  });

  // ===========================================================================
  // GRUPO: clearError y clearSyncMessage
  // ===========================================================================
  group('clearError y clearSyncMessage', () {
    test('clearError debe limpiar el mensaje de error', () async {
      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenThrow(Exception('Error'));
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'wrong');
      expect(authProvider.errorMessage, isNotNull);

      authProvider.clearError();

      expect(authProvider.errorMessage, isNull);
    });

    test('clearSyncMessage debe limpiar el mensaje de sync', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 1, downloaded: 1),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');
      expect(authProvider.syncMessage, isNotNull);

      authProvider.clearSyncMessage();

      expect(authProvider.syncMessage, isNull);
    });

    test('clearError debe notificar a listeners', () {
      var notified = false;
      authProvider.addListener(() => notified = true);

      authProvider.clearError();

      expect(notified, isTrue);
    });

    test('clearSyncMessage debe notificar a listeners', () {
      var notified = false;
      authProvider.addListener(() => notified = true);

      authProvider.clearSyncMessage();

      expect(notified, isTrue);
    });
  });

  // ===========================================================================
  // GRUPO: Notificaciones a listeners
  // ===========================================================================
  group('Notificaciones a listeners', () {
    test('signIn debe notificar múltiples veces', () async {
      var notificationCount = 0;
      authProvider.addListener(() => notificationCount++);

      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'password123');

      expect(notificationCount, greaterThanOrEqualTo(2));
    });

    test('toggleCloudSyncWithPassword debe notificar múltiples veces', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      var notificationCount = 0;
      authProvider.addListener(() => notificationCount++);

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(notificationCount, greaterThanOrEqualTo(3));
    });
  });

  // ===========================================================================
  // GRUPO: Casos edge
  // ===========================================================================
  group('Casos edge', () {
    test('múltiples listeners son notificados', () async {
      var listener1Called = false;
      var listener2Called = false;

      authProvider.addListener(() => listener1Called = true);
      authProvider.addListener(() => listener2Called = true);

      when(() => mockAuthRepository.signIn(
            email: any(named: 'email'),
            password: any(named: 'password'),
          )).thenAnswer((_) async => mockUserCredential);
      when(() => mockAuthRepository.getCloudSyncEnabled())
          .thenAnswer((_) async => false);

      await authProvider.signIn('test@test.com', 'password123');

      expect(listener1Called, isTrue);
      expect(listener2Called, isTrue);
    });

    test('syncMessage muestra total combinado de comandos y conversaciones', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      authProvider.setCommandProvider(mockCommandProvider);

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 2, downloaded: 3),
      );
      when(() => mockCommandProvider.resetSyncStatus()).thenReturn(null);
      when(() => mockCommandProvider.syncWithFirebase()).thenAnswer(
        (_) async => CommandSyncResult(
          success: true,
          uploaded: 1,
          downloaded: 1,
        ),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      // Total: 3 subidas, 4 descargadas
      expect(authProvider.syncMessage, contains('3'));
      expect(authProvider.syncMessage, contains('4'));
    });

    test('_handleConversationOnlySync muestra mensaje correcto para éxito sin cambios', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      // Sin commandProvider para forzar _handleConversationOnlySync
      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 0, downloaded: 0),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.syncMessage, contains('Todo sincronizado'));
    });

    test('_handleConversationOnlySync muestra mensaje correcto para éxito con cambios', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(success: true, uploaded: 5, downloaded: 3),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.syncMessage, contains('5'));
      expect(authProvider.syncMessage, contains('3'));
    });

    test('_handleConversationOnlySync muestra error cuando falla', () async {
      final mockUser = MockUser();
      authStateController.add(mockUser);
      await Future.delayed(const Duration(milliseconds: 50));

      when(() => mockAuthRepository.setCloudSyncEnabled(
            true,
            password: any(named: 'password'),
          )).thenAnswer((_) async {});
      when(() => mockAuthRepository.syncConversations()).thenAnswer(
        (_) async => SyncResult(
          success: false,
          uploaded: 0,
          downloaded: 0,
          error: 'Network failed',
        ),
      );

      await authProvider.toggleCloudSyncWithPassword(true, 'password123');

      expect(authProvider.syncMessage, contains('Error'));
      expect(authProvider.syncMessage, contains('Network failed'));
    });
  });
}