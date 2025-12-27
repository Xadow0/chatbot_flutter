// lib/features/auth/presentation/logic/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/repositories/auth_repository.dart';
import '../../../commands/presentation/logic/command_provider.dart';

/// Provider de autenticación para la UI
/// 
/// Gestiona el estado de:
/// - Usuario autenticado
/// - Sincronización con la nube
/// - Carga y errores
/// 
/// Utiliza [AuthRepository] para todas las operaciones de datos
class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  User? _user;
  bool _isCloudSyncEnabled = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _syncMessage;
  
  CommandManagementProvider? _commandProvider;

  AuthProvider({
    required AuthRepository authRepository,
  }) : _authRepository = authRepository {
    _init();
  }

  // ==========================================================================
  // GETTERS
  // ==========================================================================

  User? get user => _user;
  bool get isCloudSyncEnabled => _isCloudSyncEnabled;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get syncMessage => _syncMessage;
  bool get isAuthenticated => _user != null;

  // ==========================================================================
  // CONFIGURACIÓN
  // ==========================================================================

  void setCommandProvider(CommandManagementProvider provider) {
    _commandProvider = provider;
  }

  void _init() {
    _authRepository.authStateChanges.listen((User? user) async {
      _user = user;
      
      if (user == null) {
        _isCloudSyncEnabled = false;
      } else {
        _isCloudSyncEnabled = await _authRepository.getCloudSyncEnabled();
      }
      
      notifyListeners();
    });
  }

  // ==========================================================================
  // AUTENTICACIÓN
  // ==========================================================================

  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authRepository.signIn(email: email, password: password);
      _errorMessage = null;
      
      final hadSyncEnabled = await _authRepository.getCloudSyncEnabled();
      if (hadSyncEnabled) {
        _isCloudSyncEnabled = true;
        notifyListeners();
        await _performSync();
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signUp(String email, String password) async {
    _setLoading(true);
    try {
      await _authRepository.signUp(email: email, password: password);
      await toggleCloudSync(true);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    await _authRepository.signOut();
    _isCloudSyncEnabled = false;
    _setLoading(false);
  }

  // ==========================================================================
  // ELIMINACIÓN DE CUENTA
  // ==========================================================================

  /// Elimina la cuenta del usuario de forma permanente
  /// 
  /// ORDEN IMPORTANTE:
  /// 1. Elimina datos de Firestore (conversaciones en la nube)
  /// 2. Elimina datos locales (incluyendo comandos)
  /// 3. Elimina cuenta de Firebase Auth
  /// 4. ACTUALIZA MANUALMENTE el estado (fix para problema de threading)
  Future<void> deleteAccount(String password) async {
    if (_user == null) {
      _errorMessage = "No hay usuario autenticado";
      notifyListeners();
      return;
    }

    _setLoading(true);
    
    try {
      // Eliminar comandos locales si existe el provider
      if (_commandProvider != null) {
        debugPrint('🗑️ [AuthProvider] Eliminando comandos locales...');
        await _commandProvider!.deleteAllLocalCommands();
      }
      
      // El repositorio se encarga de:
      // 1. Eliminar datos de Firestore
      // 2. Eliminar conversaciones locales
      // 3. Eliminar cuenta de Firebase Auth
      await _authRepository.deleteAccount(password: password);
      
      // ⭐ CRÍTICO: Actualizar estado manualmente
      // El listener authStateChanges tiene problemas de threading y no siempre notifica
      _user = null;
      _isCloudSyncEnabled = false;
      _errorMessage = null;
      
      debugPrint('✅ [AuthProvider] ¡Cuenta eliminada completamente!');
      
      // ⭐ Notificar cambios INMEDIATAMENTE
      notifyListeners();
      
    } on FirebaseAuthException catch (e) {
      _handleFirebaseAuthError(e);
    } catch (e) {
      _errorMessage = 'Error inesperado al eliminar la cuenta: $e';
      debugPrint('❌ [AuthProvider] Error inesperado: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
        _errorMessage = 'Contraseña incorrecta. No se pudo eliminar la cuenta.';
        break;
      case 'requires-recent-login':
        _errorMessage = 'Por seguridad, debes cerrar sesión e iniciar sesión nuevamente antes de eliminar tu cuenta.';
        break;
      case 'timeout':
        _errorMessage = 'La operación tardó demasiado. Verifica tu conexión e intenta de nuevo.';
        break;
      case 'network-request-failed':
        _errorMessage = 'Error de conexión. Verifica tu internet e intenta de nuevo.';
        break;
      default:
        _errorMessage = 'Error al eliminar la cuenta: ${e.message}';
    }
    debugPrint('❌ [AuthProvider] Error al eliminar cuenta: ${e.code}');
  }

  // ==========================================================================
  // SINCRONIZACIÓN
  // ==========================================================================

  Future<void> toggleCloudSync(bool value) async {
    if (_user == null) {
      _errorMessage = "Debes iniciar sesión para activar la sincronización";
      notifyListeners();
      return;
    }
    
    _isCloudSyncEnabled = value;
    await _authRepository.setCloudSyncEnabled(value);
    
    if (value) {
      debugPrint("☁️ Sincronización activada. Iniciando proceso de sync...");
      await _performSync();
    } else {
      debugPrint("🔴 Sincronización desactivada");
      _syncMessage = null;
    }
    
    notifyListeners();
  }

  Future<void> _performSync() async {
    if (!_isCloudSyncEnabled || _user == null) return;
    
    _isSyncing = true;
    _syncMessage = "Sincronizando...";
    notifyListeners();
    
    try {
      final conversationResult = await _authRepository.syncConversations();
      
      if (_commandProvider != null) {
        _commandProvider!.resetSyncStatus();
        final commandResult = await _commandProvider!.syncWithFirebase();
        
        if (conversationResult.success && commandResult.success) {
          final totalUploaded = conversationResult.uploaded + commandResult.uploaded;
          final totalDownloaded = conversationResult.downloaded + commandResult.downloaded;
          
          if (totalUploaded > 0 || totalDownloaded > 0) {
            _syncMessage = "✅ Sincronizado: $totalUploaded subidas, $totalDownloaded descargadas";
          } else {
            _syncMessage = "✅ Todo sincronizado";
          }
          debugPrint("✅ [AuthProvider] Conversaciones: ↑${conversationResult.uploaded} ↓${conversationResult.downloaded}");
          debugPrint("✅ [AuthProvider] Comandos: ↑${commandResult.uploaded} ↓${commandResult.downloaded}");
        } else {
          final errors = [
            if (!conversationResult.success) conversationResult.error,
            if (!commandResult.success) commandResult.error,
          ].where((e) => e != null).join(', ');
          _syncMessage = "❌ Error: $errors";
          debugPrint("❌ [AuthProvider] Error en sync: $errors");
        }
      } else {
        _handleConversationOnlySync(conversationResult);
      }
    } catch (e) {
      _syncMessage = "❌ Error en sincronización: $e";
      debugPrint("❌ [AuthProvider] Excepción en sync: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
      
      Future.delayed(const Duration(seconds: 5), () {
        _syncMessage = null;
        notifyListeners();
      });
    }
  }

  void _handleConversationOnlySync(SyncResult conversationResult) {
    if (conversationResult.success) {
      if (conversationResult.uploaded > 0 || conversationResult.downloaded > 0) {
        _syncMessage = "✅ Sincronizado: ${conversationResult.uploaded} subidas, ${conversationResult.downloaded} descargadas";
      } else {
        _syncMessage = "✅ Todo sincronizado";
      }
      debugPrint("✅ [AuthProvider] $_syncMessage");
    } else {
      _syncMessage = "❌ Error: ${conversationResult.error}";
      debugPrint("❌ [AuthProvider] Error en sync: ${conversationResult.error}");
    }
  }

  Future<void> manualSync() async {
    if (!_isCloudSyncEnabled) {
      _errorMessage = "La sincronización no está activada";
      notifyListeners();
      return;
    }
    
    await _performSync();
  }

  // ==========================================================================
  // UTILIDADES
  // ==========================================================================

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void clearSyncMessage() {
    _syncMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}