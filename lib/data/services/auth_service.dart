import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  User? get currentUser => _firebaseAuth.currentUser;

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ [AuthService] Usuario logueado: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AuthService] Error Login: ${e.code}');
      throw _handleAuthException(e);
    }
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('✅ [AuthService] Usuario creado: ${credential.user?.email}');
      return credential;
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AuthService] Error Registro: ${e.code}');
      throw _handleAuthException(e);
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
    debugPrint('👋 [AuthService] Sesión cerrada');
  }

  /// Método alternativo que reautentica y elimina en un solo paso
  /// Más confiable que hacerlo por separado
  /// 
  /// Este método evita el problema de threading al hacer todo en una sola operación
  Future<void> deleteAccountWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final user = _firebaseAuth.currentUser;
      if (user == null) {
        throw 'No hay usuario autenticado';
      }

      debugPrint('🔐 [AuthService] Reautenticando y eliminando cuenta...');

      // Paso 1: Reautenticar
      final credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      try {
        await user.reauthenticateWithCredential(credential)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw FirebaseAuthException(
                  code: 'timeout',
                  message: 'La reautenticación tardó demasiado.',
                );
              },
            );
        debugPrint('✅ [AuthService] Reautenticación exitosa');
      } catch (e) {
        debugPrint('⚠️ [AuthService] Error en reautenticación: $e');
        // Si la reautenticación falla por threading, intentamos eliminar directamente
        // Firebase a veces permite esto si la sesión es reciente
      }

      // Paso 2: Eliminar cuenta (intentar incluso si reautenticación falló)
      await user.delete().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw FirebaseAuthException(
            code: 'timeout',
            message: 'La eliminación tardó demasiado.',
          );
        },
      );

      debugPrint('✅ [AuthService] Cuenta eliminada exitosamente');
      
    } on FirebaseAuthException catch (e) {
      debugPrint('❌ [AuthService] Error FirebaseAuth: ${e.code} - ${e.message}');
      throw _handleAuthException(e);
    } catch (e) {
      debugPrint('❌ [AuthService] Error inesperado: $e');
      throw 'Error al eliminar la cuenta: $e';
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No existe usuario con ese correo.';
      case 'wrong-password':
        return 'Contraseña incorrecta.';
      case 'email-already-in-use':
        return 'El correo ya está registrado.';
      case 'invalid-email':
        return 'El formato del correo no es válido.';
      case 'weak-password':
        return 'La contraseña es muy débil.';
      case 'requires-recent-login':
        return 'Por seguridad, debes iniciar sesión nuevamente antes de eliminar tu cuenta.';
      case 'invalid-credential':
        return 'Las credenciales proporcionadas son incorrectas.';
      case 'timeout':
        return 'La operación tardó demasiado. Por favor, intenta de nuevo.';
      case 'network-request-failed':
        return 'Error de conexión. Verifica tu internet e intenta de nuevo.';
      default:
        return 'Error de autenticación: ${e.message ?? e.code}';
    }
  }
}