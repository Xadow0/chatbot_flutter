import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'ai_service_selector.dart';

/// Servicio para persistir las preferencias del usuario
class PreferencesService {
  static const String _keyLastProvider = 'last_provider';
  static const String _keyLastOllamaModel = 'last_ollama_model';
  static const String _keyLastOpenAIModel = 'last_openai_model';
  
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
        // Convertir string a enum
        if (providerString.contains('gemini')) {
          debugPrint('📖 [Preferences] Último proveedor: Gemini');
          return AIProvider.gemini;
        } else if (providerString.contains('ollama')) {
          debugPrint('📖 [Preferences] Último proveedor: Ollama');
          return AIProvider.ollama;
        } else if (providerString.contains('openai')) {
          debugPrint('📖 [Preferences] Último proveedor: OpenAI');
          return AIProvider.openai;
        }
      }
      
      debugPrint('📖 [Preferences] No hay proveedor guardado');
      return null;
    } catch (e) {
      debugPrint('❌ [Preferences] Error leyendo proveedor: $e');
      return null;
    }
  }
  
  /// Guardar el modelo de Ollama seleccionado
  Future<void> saveLastOllamaModel(String modelName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastOllamaModel, modelName);
      debugPrint('💾 [Preferences] Guardado modelo Ollama: $modelName');
    } catch (e) {
      debugPrint('❌ [Preferences] Error guardando modelo Ollama: $e');
    }
  }
  
  /// Obtener el último modelo de Ollama usado
  Future<String?> getLastOllamaModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final model = prefs.getString(_keyLastOllamaModel);
      
      if (model != null) {
        debugPrint('📖 [Preferences] Último modelo Ollama: $model');
      } else {
        debugPrint('📖 [Preferences] No hay modelo Ollama guardado');
      }
      
      return model;
    } catch (e) {
      debugPrint('❌ [Preferences] Error leyendo modelo Ollama: $e');
      return null;
    }
  }
  
  /// Guardar el modelo de OpenAI seleccionado
  Future<void> saveLastOpenAIModel(String modelName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyLastOpenAIModel, modelName);
      debugPrint('💾 [Preferences] Guardado modelo OpenAI: $modelName');
    } catch (e) {
      debugPrint('❌ [Preferences] Error guardando modelo OpenAI: $e');
    }
  }
  
  /// Obtener el último modelo de OpenAI usado
  Future<String?> getLastOpenAIModel() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final model = prefs.getString(_keyLastOpenAIModel);
      
      if (model != null) {
        debugPrint('📖 [Preferences] Último modelo OpenAI: $model');
      } else {
        debugPrint('📖 [Preferences] No hay modelo OpenAI guardado');
      }
      
      return model;
    } catch (e) {
      debugPrint('❌ [Preferences] Error leyendo modelo OpenAI: $e');
      return null;
    }
  }
  
  /// Limpiar todas las preferencias (útil para debugging)
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyLastProvider);
      await prefs.remove(_keyLastOllamaModel);
      await prefs.remove(_keyLastOpenAIModel);
      debugPrint('🗑️ [Preferences] Preferencias limpiadas');
    } catch (e) {
      debugPrint('❌ [Preferences] Error limpiando preferencias: $e');
    }
  }
  
  /// Obtener todas las preferencias guardadas (útil para debugging)
  Future<Map<String, dynamic>> getAllPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'provider': prefs.getString(_keyLastProvider),
        'ollama_model': prefs.getString(_keyLastOllamaModel),
        'openai_model': prefs.getString(_keyLastOpenAIModel),
      };
    } catch (e) {
      debugPrint('❌ [Preferences] Error obteniendo preferencias: $e');
      return {};
    }
  }
}