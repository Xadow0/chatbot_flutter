// lib/presentation/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themePreferenceKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.system;
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  bool get isLightMode => _themeMode == ThemeMode.light;
  bool get isSystemMode => _themeMode == ThemeMode.system;

  ThemeProvider() {
    _loadThemePreference();
  }

  /// Cargar la preferencia de tema guardada
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedThemeIndex = prefs.getInt(_themePreferenceKey);
      
      if (savedThemeIndex != null) {
        _themeMode = ThemeMode.values[savedThemeIndex];
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ [ThemeProvider] Error al cargar preferencia de tema: $e');
    }
  }

  /// Cambiar el modo de tema
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_themePreferenceKey, mode.index);
      debugPrint('✅ [ThemeProvider] Tema guardado: ${mode.name}');
    } catch (e) {
      debugPrint('❌ [ThemeProvider] Error al guardar preferencia de tema: $e');
    }
  }

  /// Alternar entre claro y oscuro (sin sistema)
  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light 
        ? ThemeMode.dark 
        : ThemeMode.light;
    await setThemeMode(newMode);
  }
}