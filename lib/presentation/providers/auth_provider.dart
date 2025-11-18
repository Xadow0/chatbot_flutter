import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/preferences_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService;
  final PreferencesService _preferencesService;

  User? _user;
  bool _isCloudSyncEnabled = false;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider({
    required AuthService authService,
    required PreferencesService preferencesService,
  })  : _authService = authService,
        _preferencesService = preferencesService {
    _init();
  }

  User? get user => _user;
  bool get isCloudSyncEnabled => _isCloudSyncEnabled;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  void _init() {
    _authService.authStateChanges.listen((User? user) async {
      _user = user;
      
      if (user == null) {
        // Si se desconecta, desactivamos sync visualmente (la preferencia persiste si quiere)
        // Pero según requerimiento: "Si se desconecta... se actualizará con la versión remota al recuperar"
        // Mantenemos el estado en false en memoria para que no intente subir nada.
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
      // Por defecto, al crear cuenta, activamos el sync (según requerimiento o UX standard)
      // El requerimiento dice: "se activará en la página de settings el botón... el cual se podrá dejar activado o desactivado"
      // Lo dejamos desactivado por defecto para que el usuario elija activarlo, o activado si prefieres.
      // Vamos a dejarlo activado por defecto al registrarse para mejor UX:
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
    await _authService.signOut();
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
      // TODO: Aquí dispararemos la sincronización inicial en la Fase 2
      debugPrint("☁️ Sincronización activada. Iniciando proceso de sync (Fase 2)");
    }
    
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}