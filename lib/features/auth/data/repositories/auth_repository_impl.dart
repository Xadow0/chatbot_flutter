// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_source.dart';
import '../datasources/firebase_sync_service.dart';
import '../../../settings/data/datasources/preferences_service.dart';

/// Implementación concreta del repositorio de autenticación
/// 
/// Coordina las operaciones entre:
/// - [AuthService]: Autenticación con Firebase Auth
/// - [FirebaseSyncService]: Sincronización de datos con Firestore
/// - [PreferencesService]: Preferencias locales del usuario
class AuthRepositoryImpl implements AuthRepository {
  final AuthService _authService;
  final PreferencesService _preferencesService;
  final FirebaseSyncService _syncService;

  AuthRepositoryImpl({
    required AuthService authService,
    required PreferencesService preferencesService,
    required FirebaseSyncService syncService,
  })  : _authService = authService,
        _preferencesService = preferencesService,
        _syncService = syncService;

  @override
  Stream<User?> get authStateChanges => _authService.authStateChanges;

  @override
  User? get currentUser => _authService.currentUser;

  @override
  bool get isAuthenticated => _authService.currentUser != null;

  @override
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.signIn(
        email: email,
        password: password,
      );
      debugPrint('✅ [AuthRepository] Usuario logueado: ${credential.user?.email}');
      return credential;
    } catch (e) {
      debugPrint('❌ [AuthRepository] Error en signIn: $e');
      rethrow;
    }
  }

  @override
  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _authService.signUp(
        email: email,
        password: password,
      );
      debugPrint('✅ [AuthRepository] Usuario registrado: ${credential.user?.email}');
      return credential;
    } catch (e) {
      debugPrint('❌ [AuthRepository] Error en signUp: $e');
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    await _authService.signOut();
    debugPrint('👋 [AuthRepository] Sesión cerrada');
  }

  @override
  Future<void> deleteAccount({required String password}) async {
    final user = currentUser;
    if (user == null) {
      throw 'No hay usuario autenticado';
    }

    final email = user.email!;

    try {
      // 1. PRIMERO: Eliminar datos de Firestore
      debugPrint('☁️ [AuthRepository] Eliminando datos de Firestore...');
      try {
        await _syncService.deleteAllUserData();
        debugPrint('✅ [AuthRepository] Datos de Firestore eliminados');
      } catch (e) {
        debugPrint('⚠️ [AuthRepository] Error eliminando de Firestore: $e');
        // Continuamos aunque falle
      }

      // 2. SEGUNDO: Eliminar datos locales
      debugPrint('🗑️ [AuthRepository] Eliminando datos locales...');
      await deleteAllLocalData();

      // 3. TERCERO: Eliminar cuenta de Firebase Auth
      debugPrint('🔐 [AuthRepository] Eliminando cuenta de Firebase Auth...');
      await _authService.deleteAccountWithPassword(
        email: email,
        password: password,
      );

      debugPrint('✅ [AuthRepository] ¡Cuenta eliminada completamente!');
    } catch (e) {
      debugPrint('❌ [AuthRepository] Error eliminando cuenta: $e');
      rethrow;
    }
  }

  @override
  Future<bool> getCloudSyncEnabled() async {
    return await _preferencesService.getCloudSyncEnabled();
  }

  @override
  Future<void> setCloudSyncEnabled(bool enabled) async {
    await _preferencesService.saveCloudSyncEnabled(enabled);
    debugPrint(enabled 
        ? '☁️ [AuthRepository] Sincronización activada' 
        : '🔴 [AuthRepository] Sincronización desactivada');
  }

  @override
  Future<SyncResult> syncConversations() async {
    try {
      // El servicio ya devuelve SyncResult directamente
      return await _syncService.syncConversations();
    } catch (e) {
      debugPrint('❌ [AuthRepository] Error en sincronización: $e');
      return SyncResult(
        success: false,
        uploaded: 0,
        downloaded: 0,
        error: e.toString(),
      );
    }
  }

  @override
  Future<void> deleteAllLocalData() async {
    try {
      // Eliminar conversaciones locales
      await _syncService.deleteAllLocalConversations();
      
      // Limpiar preferencias relacionadas con sync
      await _preferencesService.saveCloudSyncEnabled(false);
      
      debugPrint('✅ [AuthRepository] Datos locales eliminados');
    } catch (e) {
      debugPrint('⚠️ [AuthRepository] Error al eliminar datos locales: $e');
      // No lanzamos el error, continuamos con la eliminación de la cuenta
    }
  }

  @override
  Future<bool> deleteAllUserData() async {
    return await _syncService.deleteAllUserData();
  }
}