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