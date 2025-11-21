import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/preferences_service.dart';
import '../../data/services/firebase_sync_service.dart';

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

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      _user = user;
      
      if (user == null) {
        // Si se desconecta, desactivamos sync visualmente
        _isCloudSyncEnabled = false;
      } else {
        // Al conectar, recuperamos la preferencia del usuario
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
      
      // Si el usuario tenía sync habilitado, intentar sincronizar
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
      // Al registrarse, dejamos el sync desactivado por defecto
      // El usuario lo activará manualmente desde settings
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

  /// Activa o desactiva la sincronización con la nube
  /// Al activar, realiza una sincronización bidireccional automática
  Future<void> toggleCloudSync(bool value) async {
    if (_user == null) {
      _errorMessage = "Debes iniciar sesión para activar la sincronización";
      notifyListeners();
      return;
    }
    
    _isCloudSyncEnabled = value;
    await _preferencesService.saveCloudSyncEnabled(value);
    
    if (value) {
      // Al activar, disparar sincronización inicial
      debugPrint("☁️ Sincronización activada. Iniciando proceso de sync...");
      await _performSync();
    } else {
      debugPrint("📴 Sincronización desactivada");
      _syncMessage = null;
    }
    
    notifyListeners();
  }

  /// Ejecuta el proceso de sincronización bidireccional
  Future<void> _performSync() async {
    if (!_isCloudSyncEnabled || _user == null) return;
    
    _isSyncing = true;
    _syncMessage = "Sincronizando...";
    notifyListeners();
    
    try {
      final result = await _syncService.syncConversations();
      
      if (result.success) {
        if (result.uploaded > 0 || result.downloaded > 0) {
          _syncMessage = "✅ Sincronizado: ${result.uploaded} subidas, ${result.downloaded} descargadas";
        } else {
          _syncMessage = "✅ Todo sincronizado";
        }
        debugPrint("✅ [AuthProvider] $syncMessage");
      } else {
        _syncMessage = "❌ Error: ${result.error}";
        debugPrint("❌ [AuthProvider] Error en sync: ${result.error}");
      }
    } catch (e) {
      _syncMessage = "❌ Error en sincronización: $e";
      debugPrint("❌ [AuthProvider] Excepción en sync: $e");
    } finally {
      _isSyncing = false;
      notifyListeners();
      
      // Limpiar mensaje después de 5 segundos
      Future.delayed(const Duration(seconds: 5), () {
        _syncMessage = null;
        notifyListeners();
      });
    }
  }

  /// Permite sincronizar manualmente bajo demanda
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