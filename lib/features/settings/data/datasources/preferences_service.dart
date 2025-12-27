import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../../chat/data/utils/ai_service_selector.dart';

/// Servicio para persistir las preferencias del usuario
class PreferencesService {
  static const String _keyLastProvider = 'last_provider';
  static const String _keyLastOllamaModel = 'last_ollama_model';
  static const String _keyLastOpenAIModel = 'last_openai_model';
  static const String _keyCloudSyncEnabled = 'cloud_sync_enabled'; // NUEVO
  
  /// Guardar preferencia de sincronización en la nube
  Future<void> saveCloudSyncEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyCloudSyncEnabled, enabled);
      debugPrint('💾 [Preferences] Sincronización en la nube: $enabled');
    } catch (e) {
      debugPrint('❌ [Preferences] Error guardando sync status: $e');
    }
  }

  /// Obtener preferencia de sincronización
  Future<bool> getCloudSyncEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final enabled = prefs.getBool(_keyCloudSyncEnabled) ?? false;
      return enabled;
    } catch (e) {
      debugPrint('❌ [Preferences] Error leyendo sync status: $e');
      return false;
    }
  }

  /// Guardar el proveedor seleccionado
  Future<void> saveLastProvider(AIProvider provider) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastProvider, provider.toString());
      debugPrint('💾 [Preferences] Guardado proveedor: $provider');
    } catch (e) {
      debugPrint('❌ [Preferences] Error guardando proveedor: $e');
    }
  }
  
  /// Obtener el último proveedor usado
  Future<AIProvider?> getLastProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final providerString = prefs.getString(_keyLastProvider);
      
      if (providerString != null) {
        if (providerString.contains('gemini')) return AIProvider.gemini;
        if (providerString.contains('ollama')) return AIProvider.ollama;
        if (providerString.contains('openai')) return AIProvider.openai;
        // Fix: Faltaba localOllama en tu archivo original, lo añado por seguridad
        if (providerString.contains('localOllama')) return AIProvider.localOllama; 
      }
      return null;
    } catch (e) {
      debugPrint('❌ [Preferences] Error leyendo proveedor: $e');
      return null;
    }
  }
  
  Future<void> saveLastOllamaModel(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastOllamaModel, modelName);
  }
  
  Future<String?> getLastOllamaModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastOllamaModel);
  }
  
  Future<void> saveLastOpenAIModel(String modelName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastOpenAIModel, modelName);
  }
  
  Future<String?> getLastOpenAIModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastOpenAIModel);
  }
  
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}