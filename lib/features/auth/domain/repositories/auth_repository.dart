// lib/features/auth/domain/repositories/auth_repository.dart
import 'package:firebase_auth/firebase_auth.dart';

import '../../data/datasources/firebase_sync_service.dart' show SyncResult, SaltSyncResult;

// Re-exportamos para que quien use auth_repository tenga acceso
export '../../data/datasources/firebase_sync_service.dart' show SyncResult, SaltSyncResult;

/// Contrato abstracto para el repositorio de autenticación
/// 
/// Define las operaciones disponibles para:
/// - Autenticación (login, registro, logout)
/// - Gestión de cuenta (eliminación)
/// - Sincronización con Firebase
/// - Estado de la sesión
/// - **Cifrado multi-dispositivo** (automático y transparente)
/// 
/// FLUJO DE CIFRADO MULTI-DISPOSITIVO:
/// 
/// El sistema de cifrado funciona de forma AUTOMÁTICA y TRANSPARENTE:
/// 
/// 1. Usuario EXISTENTE inicia sesión (con sync activo):
///    - signIn() recibe email y password
///    - Internamente descarga el salt cifrado de Firebase
///    - Descifra el salt usando la misma contraseña del login
///    - Guarda el salt localmente
///    - Sincroniza y descifra las conversaciones automáticamente
///    → El usuario NO necesita hacer nada adicional
/// 
/// 2. Usuario NUEVO activa sincronización:
///    - signUp() recibe email y password
///    - Al activar sync, genera un nuevo salt
///    - Cifra el salt con la contraseña del usuario
///    - Sube el salt cifrado a Firebase
///    → El usuario NO necesita ingresar la contraseña de nuevo
/// 
/// 3. Dispositivo NUEVO con cuenta existente:
///    - signIn() en el nuevo dispositivo
///    - Detecta que hay salt en Firebase pero no local
///    - Descarga y descifra automáticamente con la contraseña del login
///    → Totalmente transparente para el usuario
abstract class AuthRepository {
  /// Stream que emite cambios en el estado de autenticación
  Stream<User?> get authStateChanges;

  /// Usuario actualmente autenticado (null si no hay sesión)
  User? get currentUser;

  /// Indica si hay un usuario autenticado
  bool get isAuthenticated;

  // ==========================================================================
  // AUTENTICACIÓN
  // ==========================================================================

  /// Inicia sesión con email y contraseña.
  /// 
  /// Si el usuario tiene sincronización activa, este método también:
  /// - Descarga el salt cifrado de Firebase (si existe)
  /// - Descifra el salt usando [password]
  /// - Inicializa el sistema de cifrado para las conversaciones
  /// 
  /// El proceso es completamente AUTOMÁTICO y TRANSPARENTE.
  /// 
  /// [email]: Email del usuario
  /// [password]: Contraseña (también usada para descifrar el salt)
  /// 
  /// Throws [String] con mensaje de error si falla
  Future<UserCredential> signIn({
    required String email,
    required String password,
  });

  /// Crea una nueva cuenta con email y contraseña.
  /// 
  /// [email]: Email del usuario
  /// [password]: Contraseña (también usada para cifrar el salt si se activa sync)
  /// 
  /// Throws [String] con mensaje de error si falla
  Future<UserCredential> signUp({
    required String email,
    required String password,
  });

  /// Cierra la sesión del usuario actual.
  /// 
  /// También limpia el cache de cifrado por seguridad.
  Future<void> signOut();

  /// Elimina la cuenta del usuario de forma permanente.
  /// 
  /// ORDEN DE OPERACIONES:
  /// 1. Elimina datos de Firestore (conversaciones + salt cifrado)
  /// 2. Elimina datos locales (conversaciones + salt + preferencias)
  /// 3. Elimina cuenta de Firebase Auth
  /// 
  /// [password]: Contraseña para reautenticación
  /// 
  /// Throws [String] con mensaje de error si falla
  Future<void> deleteAccount({
    required String password,
  });

  // ==========================================================================
  // SINCRONIZACIÓN
  // ==========================================================================

  /// Obtiene el estado actual de sincronización con la nube
  Future<bool> getCloudSyncEnabled();

  /// Activa o desactiva la sincronización con la nube.
  /// 
  /// Cuando se ACTIVA la sincronización:
  /// - Si hay salt en Firebase: lo descarga y descifra con [password]
  /// - Si no hay salt: genera uno nuevo y lo sube cifrado
  /// - Sincroniza las conversaciones automáticamente
  /// 
  /// [enabled]: true para activar, false para desactivar
  /// [password]: Requerido al ACTIVAR sync (para cifrar/descifrar salt)
  Future<void> setCloudSyncEnabled(bool enabled, {String? password});

  /// Realiza una sincronización manual con Firebase.
  /// 
  /// PREREQUISITO: El cifrado debe estar inicializado (el usuario debe
  /// haber iniciado sesión con sync activo o haber activado sync después).
  /// 
  /// Returns [SyncResult] con el resultado de la operación
  Future<SyncResult> syncConversations();

  // ==========================================================================
  // DATOS LOCALES
  // ==========================================================================

  /// Elimina todos los datos locales del usuario
  /// (conversaciones, salt, preferencias de sync)
  Future<void> deleteAllLocalData();

  /// Elimina todos los datos del usuario en Firebase
  /// (conversaciones + salt cifrado)
  Future<bool> deleteAllUserData();

  // ==========================================================================
  // CIFRADO (INTERNO - usado por el provider)
  // ==========================================================================

  /// Inicializa el cifrado para sincronización usando la contraseña.
  /// 
  /// Este método es llamado INTERNAMENTE por [signIn] y [setCloudSyncEnabled].
  /// No debería ser necesario llamarlo directamente desde la UI.
  /// 
  /// [password]: Contraseña del usuario (la misma del login)
  /// 
  /// Returns [SaltSyncResult] indicando si fue exitoso
  Future<SaltSyncResult> initializeEncryptionForSync(String password);
}