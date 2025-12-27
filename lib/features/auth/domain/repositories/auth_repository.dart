// lib/features/auth/domain/repositories/auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/datasources/firebase_sync_service.dart' show SyncResult;

// Re-exportamos SyncResult para que quien use auth_repository tenga acceso
export '../../data/datasources/firebase_sync_service.dart' show SyncResult;

/// Contrato abstracto para el repositorio de autenticación
/// 
/// Define las operaciones disponibles para:
/// - Autenticación (login, registro, logout)
/// - Gestión de cuenta (eliminación)
/// - Sincronización con Firebase
/// - Estado de la sesión
abstract class AuthRepository {
  /// Stream que emite cambios en el estado de autenticación
  Stream<User?> get authStateChanges;

  /// Usuario actualmente autenticado (null si no hay sesión)
  User? get currentUser;

  /// Indica si hay un usuario autenticado
  bool get isAuthenticated;

  /// Inicia sesión con email y contraseña
  /// 
  /// Throws [String] con mensaje de error si falla
  Future<UserCredential> signIn({
    required String email,
    required String password,
  });

  /// Crea una nueva cuenta con email y contraseña
  /// 
  /// Throws [String] con mensaje de error si falla
  Future<UserCredential> signUp({
    required String email,
    required String password,
  });

  /// Cierra la sesión del usuario actual
  Future<void> signOut();

  /// Elimina la cuenta del usuario de forma permanente
  /// 
  /// ORDEN DE OPERACIONES:
  /// 1. Elimina datos de Firestore (conversaciones en la nube)
  /// 2. Elimina datos locales
  /// 3. Elimina cuenta de Firebase Auth
  /// 
  /// Throws [String] con mensaje de error si falla
  Future<void> deleteAccount({
    required String password,
  });

  /// Obtiene el estado actual de sincronización con la nube
  Future<bool> getCloudSyncEnabled();

  /// Activa o desactiva la sincronización con la nube
  /// 
  /// Si se activa, realiza una sincronización inmediata
  Future<void> setCloudSyncEnabled(bool enabled);

  /// Realiza una sincronización manual con Firebase
  /// 
  /// Returns [SyncResult] con el resultado de la operación
  Future<SyncResult> syncConversations();

  /// Elimina todos los datos locales del usuario
  /// (conversaciones, comandos, preferencias)
  Future<void> deleteAllLocalData();

  /// Elimina todos los datos del usuario en Firebase
  Future<bool> deleteAllUserData();
}