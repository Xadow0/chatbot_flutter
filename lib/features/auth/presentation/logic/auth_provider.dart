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
/// CIFRADO MULTI-DISPOSITIVO AUTOMÁTICO:
/// 
/// El cifrado de conversaciones funciona de forma TRANSPARENTE:
/// 
/// - Al iniciar sesión: Si sync está activo, el cifrado se inicializa
///   automáticamente usando la contraseña del login.
/// 
/// - Al activar sync: Se pide la contraseña una sola vez y se configura
///   el cifrado automáticamente.
/// 
/// - El usuario NUNCA necesita ingresar la contraseña dos veces ni
///   realizar acciones adicionales para el cifrado.
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
  
  /// Almacena temporalmente la contraseña durante el flujo de registro
  /// para poder activar sync automáticamente sin pedirla de nuevo.
  String? _tempPassword;
  
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
  
  /// Indica si la contraseña está disponible para activar sync.
  /// Si es false, la UI debe solicitar la contraseña al usuario.
  bool get canActivateSyncWithoutPassword => _tempPassword != null;

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
        _tempPassword = null; // Limpiar contraseña temporal
      } else {
        _isCloudSyncEnabled = await _authRepository.getCloudSyncEnabled();
      }
      
      notifyListeners();
    });
  }

  // ==========================================================================
  // AUTENTICACIÓN
  // ==========================================================================

  /// Inicia sesión con email y contraseña.
  /// 
  /// Si el usuario tiene sincronización activa, el cifrado se inicializa
  /// AUTOMÁTICAMENTE usando la contraseña proporcionada. El usuario no
  /// necesita hacer nada adicional.
  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      // Guardar contraseña temporalmente para:
      // 1. Inicialización automática de cifrado si sync ya está activo
      // 2. Activación manual de sync después del login
      _tempPassword = password;
      
      // El repositorio maneja automáticamente:
      // 1. Autenticación con Firebase
      // 2. Inicialización del cifrado si sync está activo
      await _authRepository.signIn(email: email, password: password);
      _errorMessage = null;
      
      // Si sync estaba activo, realizar sincronización
      final hadSyncEnabled = await _authRepository.getCloudSyncEnabled();
      if (hadSyncEnabled) {
        _isCloudSyncEnabled = true;
        notifyListeners();
        await _performSync();
      }
    } catch (e) {
      _errorMessage = e.toString();
      _tempPassword = null; // Limpiar en caso de error
    } finally {
      _setLoading(false);
    }
  }

  /// Registra un nuevo usuario.
  /// 
  /// Después de registrarse, activa sync automáticamente usando la
  /// misma contraseña (el usuario no necesita ingresarla de nuevo).
  Future<void> signUp(String email, String password) async {
    _setLoading(true);
    try {
      await _authRepository.signUp(email: email, password: password);
      
      // Guardar contraseña temporalmente para activar sync
      _tempPassword = password;
      
      // Activar sync automáticamente para usuarios nuevos
      await toggleCloudSync(true);
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _tempPassword = null; // Siempre limpiar
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    await _authRepository.signOut();
    _isCloudSyncEnabled = false;
    _tempPassword = null;
    _setLoading(false);
  }

  // ==========================================================================
  // ELIMINACIÓN DE CUENTA
  // ==========================================================================

  /// Elimina la cuenta del usuario de forma permanente
  /// 
  /// ORDEN IMPORTANTE:
  /// 1. Elimina datos de Firestore (conversaciones + salt cifrado)
  /// 2. Elimina datos locales (incluyendo comandos y salt local)
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
      // 1. Eliminar datos de Firestore (incluye salt cifrado)
      // 2. Eliminar conversaciones locales
      // 3. Eliminar salt local
      // 4. Eliminar cuenta de Firebase Auth
      await _authRepository.deleteAccount(password: password);
      
      // ⭐ CRÍTICO: Actualizar estado manualmente
      // El listener authStateChanges tiene problemas de threading y no siempre notifica
      _user = null;
      _isCloudSyncEnabled = false;
      _errorMessage = null;
      _tempPassword = null;
      
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

  /// Activa o desactiva la sincronización con la nube.
  /// 
  /// Al ACTIVAR la sincronización:
  /// - Si hay contraseña temporal (del login reciente), la usa automáticamente
  /// - Si no hay contraseña, retorna error y la UI debe llamar a 
  ///   [toggleCloudSyncWithPassword] con la contraseña del usuario
  /// 
  /// Al DESACTIVAR: No requiere contraseña.
  Future<void> toggleCloudSync(bool value) async {
    if (_user == null) {
      _errorMessage = "Debes iniciar sesión para activar la sincronización";
      notifyListeners();
      return;
    }
    
    if (value) {
      // Activando sync - intentar usar contraseña temporal
      if (_tempPassword != null) {
        await toggleCloudSyncWithPassword(value, _tempPassword!);
      } else {
        // No hay contraseña temporal - la UI debe mostrar un diálogo
        _errorMessage = "Por favor, ingresa tu contraseña para activar la sincronización";
        notifyListeners();
        debugPrint("⚠️ [AuthProvider] Se requiere contraseña para activar sync");
      }
    } else {
      // Desactivando sync - no necesitamos contraseña
      _isCloudSyncEnabled = false;
      await _authRepository.setCloudSyncEnabled(false);
      debugPrint("🔴 Sincronización desactivada");
      _syncMessage = null;
      notifyListeners();
    }
  }

  /// Activa la sincronización con la contraseña proporcionada.
  /// 
  /// Este método debe usarse cuando:
  /// - Se activa sync desde la UI de settings sin contraseña temporal
  /// - La contraseña temporal ya expiró
  /// 
  /// [value]: true para activar, false para desactivar
  /// [password]: Contraseña del usuario para cifrar/descifrar el salt
  Future<void> toggleCloudSyncWithPassword(bool value, String password) async {
    if (_user == null) {
      _errorMessage = "Debes iniciar sesión para activar la sincronización";
      notifyListeners();
      return;
    }

    if (!value) {
      // Desactivando sync
      _isCloudSyncEnabled = false;
      await _authRepository.setCloudSyncEnabled(false);
      debugPrint("🔴 Sincronización desactivada");
      _syncMessage = null;
      notifyListeners();
      return;
    }

    // Activando sync
    _isSyncing = true;
    _syncMessage = "Inicializando cifrado...";
    _errorMessage = null;
    notifyListeners();

    try {
      // El repositorio inicializa el cifrado con la contraseña
      await _authRepository.setCloudSyncEnabled(true, password: password);
      
      _isCloudSyncEnabled = true;
      debugPrint("☁️ Sincronización activada. Iniciando proceso de sync...");
      
      // Realizar sincronización
      await _performSync();
      
      // Limpiar contraseña temporal por seguridad (ya se usó exitosamente)
      _tempPassword = null;
      
    } catch (e) {
      _errorMessage = e.toString();
      _isCloudSyncEnabled = false;
      debugPrint("❌ [AuthProvider] Error activando sync: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
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