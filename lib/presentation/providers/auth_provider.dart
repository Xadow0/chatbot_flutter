import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/preferences_service.dart';
import '../../data/services/firebase_sync_service.dart';
import '../providers/command_management_provider.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final PreferencesService _preferencesService;
  final FirebaseSyncService _syncService;

  User? _user;
  bool _isCloudSyncEnabled = false;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;
  String? _syncMessage;
  
  CommandManagementProvider? _commandProvider;

  AuthProvider({
    required AuthService authService,
    required PreferencesService preferencesService,
    required FirebaseSyncService syncService,
  })  : _authService = authService,
        _preferencesService = preferencesService,
        _syncService = syncService {
    _init();
  }

  User? get user => _user;
  bool get isCloudSyncEnabled => _isCloudSyncEnabled;
  bool get isLoading => _isLoading;
  bool get isSyncing => _isSyncing;
  String? get errorMessage => _errorMessage;
  String? get syncMessage => _syncMessage;
  bool get isAuthenticated => _user != null;

  void setCommandProvider(CommandManagementProvider provider) {
    _commandProvider = provider;
  }

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      _user = user;
      
      if (user == null) {
        _isCloudSyncEnabled = false;
      } else {
        _isCloudSyncEnabled = await _preferencesService.getCloudSyncEnabled();
      }
      
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    _setLoading(true);
    try {
      await _authService.signIn(email: email, password: password);
      _errorMessage = null;
      
      final hadSyncEnabled = await _preferencesService.getCloudSyncEnabled();
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
      await _authService.signUp(email: email, password: password);
      await toggleCloudSync(false);
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setLoading(true);
    await _authService.signOut();
    _isCloudSyncEnabled = false;
    _setLoading(false);
  }

  /// Elimina la cuenta del usuario de forma permanente
  /// 
  /// ORDEN IMPORTANTE:
  /// 1. Elimina datos de Firestore (conversaciones en la nube)
  /// 2. Elimina datos locales
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
      final email = _user!.email!;
      
      // 1. PRIMERO: Eliminar datos de Firestore (conversaciones en la nube)
      debugPrint('☁️ [AuthProvider] Eliminando datos de Firestore...');
      try {
        await _syncService.deleteAllUserData();
        debugPrint('✅ [AuthProvider] Datos de Firestore eliminados');
      } catch (e) {
        debugPrint('⚠️ [AuthProvider] Error eliminando de Firestore: $e');
        // Continuamos aunque falle, intentaremos eliminar lo demás
      }
      
      // 2. SEGUNDO: Eliminar datos locales
      debugPrint('🗑️ [AuthProvider] Eliminando datos locales...');
      await _deleteLocalData();
      
      // 3. TERCERO: Eliminar cuenta de Firebase Auth
      debugPrint('🔐 [AuthProvider] Eliminando cuenta de Firebase Auth...');
      await _authService.deleteAccountWithPassword(
        email: email,
        password: password,
      );
      
      // ⭐ 4. CRÍTICO: Actualizar estado manualmente
      // El listener authStateChanges tiene problemas de threading y no siempre notifica
      // Por eso actualizamos el estado manualmente para que la UI responda inmediatamente
      _user = null;
      _isCloudSyncEnabled = false;
      _errorMessage = null;
      
      debugPrint('✅ [AuthProvider] ¡Cuenta eliminada completamente!');
      
      // ⭐ Notificar cambios INMEDIATAMENTE
      // Esto hace que isAuthenticated sea false y la UI pueda reaccionar
      notifyListeners();
      
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password') {
        _errorMessage = 'Contraseña incorrecta. No se pudo eliminar la cuenta.';
      } else if (e.code == 'requires-recent-login') {
        _errorMessage = 'Por seguridad, debes cerrar sesión e iniciar sesión nuevamente antes de eliminar tu cuenta.';
      } else if (e.code == 'timeout') {
        _errorMessage = 'La operación tardó demasiado. Verifica tu conexión e intenta de nuevo.';
      } else if (e.code == 'network-request-failed') {
        _errorMessage = 'Error de conexión. Verifica tu internet e intenta de nuevo.';
      } else {
        _errorMessage = 'Error al eliminar la cuenta: ${e.message}';
      }
      debugPrint('❌ [AuthProvider] Error al eliminar cuenta: ${e.code}');
    } catch (e) {
      _errorMessage = 'Error inesperado al eliminar la cuenta: $e';
      debugPrint('❌ [AuthProvider] Error inesperado: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Elimina todos los datos locales del usuario
  /// Incluye: conversaciones, comandos y preferencias
  Future<void> _deleteLocalData() async {
    try {
      // Eliminar conversaciones locales
      await _syncService.deleteAllLocalConversations();
      
      // Eliminar comandos locales si existe el provider
      if (_commandProvider != null) {
        await _commandProvider!.deleteAllLocalCommands();
      }
      
      // Limpiar preferencias relacionadas con sync
      await _preferencesService.saveCloudSyncEnabled(false);
      
      debugPrint('✅ [AuthProvider] Datos locales eliminados');
    } catch (e) {
      debugPrint('⚠️ [AuthProvider] Error al eliminar datos locales: $e');
      // No lanzamos el error, continuamos con la eliminación de la cuenta
    }
  }

  Future<void> toggleCloudSync(bool value) async {
    if (_user == null) {
      _errorMessage = "Debes iniciar sesión para activar la sincronización";
      notifyListeners();
      return;
    }
    
    _isCloudSyncEnabled = value;
    await _preferencesService.saveCloudSyncEnabled(value);
    
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
      final conversationResult = await _syncService.syncConversations();
      
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
        if (conversationResult.success) {
          if (conversationResult.uploaded > 0 || conversationResult.downloaded > 0) {
            _syncMessage = "✅ Sincronizado: ${conversationResult.uploaded} subidas, ${conversationResult.downloaded} descargadas";
          } else {
            _syncMessage = "✅ Todo sincronizado";
          }
          debugPrint("✅ [AuthProvider] $syncMessage");
        } else {
          _syncMessage = "❌ Error: ${conversationResult.error}";
          debugPrint("❌ [AuthProvider] Error en sync: ${conversationResult.error}");
        }
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

  Future<void> manualSync() async {
    if (!_isCloudSyncEnabled) {
      _errorMessage = "La sincronización no está activada";
      notifyListeners();
      return;
    }
    
    await _performSync();
  }

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