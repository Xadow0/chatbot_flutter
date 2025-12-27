import 'package:flutter/foundation.dart';
import '../../../../core/services/secure_storage_service.dart';

/// Gestor de claves API
/// Proporciona una interfaz de alto nivel para gestionar las API keys
class ApiKeysManager {
  // Singleton pattern
  static final ApiKeysManager _instance = ApiKeysManager._internal();
  factory ApiKeysManager() => _instance;
  ApiKeysManager._internal();

  final _storage = SecureStorageService();

  // Constantes de claves
  static const String geminiApiKeyName = 'GEMINI_API_KEY';
  static const String openaiApiKeyName = 'OPENAI_API_KEY';
  
  // Prefijo para identificar nuestras keys en el storage
  static const String _keyPrefix = 'api_key_';

  /// Obtener el nombre completo de la clave con prefijo
  String _getFullKeyName(String keyName) => '$_keyPrefix$keyName';

  /// Guardar una API key
  Future<void> saveApiKey(String keyName, String apiKey) async {
    try {
      if (apiKey.trim().isEmpty) {
        throw Exception('La API key no puede estar vacía');
      }

      await _storage.write(
        key: _getFullKeyName(keyName),
        value: apiKey.trim(),
      );
      
      debugPrint('✅ [ApiKeysManager] API key guardada: $keyName');
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error guardando $keyName: $e');
      rethrow;
    }
  }

  /// Obtener una API key
  Future<String?> getApiKey(String keyName) async {
    try {
      final key = await _storage.read(key: _getFullKeyName(keyName));
      
      if (key != null && key.isNotEmpty) {
        debugPrint('✅ [ApiKeysManager] API key encontrada: $keyName');
        return key;
      }
      
      debugPrint('⚠️ [ApiKeysManager] API key no encontrada: $keyName');
      return null;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error obteniendo $keyName: $e');
      return null;
    }
  }

  /// Eliminar una API key
  Future<void> deleteApiKey(String keyName) async {
    try {
      await _storage.delete(key: _getFullKeyName(keyName));
      debugPrint('🗑️ [ApiKeysManager] API key eliminada: $keyName');
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error eliminando $keyName: $e');
      rethrow;
    }
  }

  /// Verificar si una API key existe y no está vacía
  Future<bool> hasApiKey(String keyName) async {
    try {
      final key = await getApiKey(keyName);
      return key != null && key.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error verificando $keyName: $e');
      return false;
    }
  }

  /// Verificar si existe al menos una API key configurada
  Future<bool> hasAnyApiKey() async {
    try {
      final hasGemini = await hasApiKey(geminiApiKeyName);
      final hasOpenAI = await hasApiKey(openaiApiKeyName);
      
      final result = hasGemini || hasOpenAI;
      debugPrint('🔍 [ApiKeysManager] ¿Hay alguna API key? $result');
      return result;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error verificando API keys: $e');
      return false;
    }
  }

  /// Obtener el estado de todas las API keys
  Future<Map<String, bool>> getApiKeysStatus() async {
    return {
      geminiApiKeyName: await hasApiKey(geminiApiKeyName),
      openaiApiKeyName: await hasApiKey(openaiApiKeyName),
    };
  }

  /// Eliminar todas las API keys (usar con precaución)
  Future<void> deleteAllApiKeys() async {
    try {
      await deleteApiKey(geminiApiKeyName);
      await deleteApiKey(openaiApiKeyName);
      debugPrint('🗑️ [ApiKeysManager] Todas las API keys eliminadas');
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error eliminando todas las keys: $e');
      rethrow;
    }
  }

  /// Validar formato de API key de Gemini
  bool validateGeminiKey(String key) {
    // Las keys de Gemini suelen empezar con "AIza" y tener 39 caracteres
    if (key.isEmpty) return false;
    if (key.length < 30) return false; // Longitud mínima razonable
    
    // Validación básica: debe contener solo caracteres alfanuméricos y algunos símbolos
    final validChars = RegExp(r'^[A-Za-z0-9_-]+$');
    return validChars.hasMatch(key);
  }

  /// Validar formato de API key de OpenAI
  bool validateOpenAIKey(String key) {
    // Las keys de OpenAI empiezan con "sk-" y tienen al menos 48 caracteres
    if (key.isEmpty) return false;
    if (!key.startsWith('sk-')) return false;
    if (key.length < 40) return false;
    
    // Validación básica de caracteres
    final validChars = RegExp(r'^sk-[A-Za-z0-9_-]+$');
    return validChars.hasMatch(key);
  }

  /// Validar cualquier API key según su tipo
  bool validateApiKey(String keyName, String key) {
    switch (keyName) {
      case geminiApiKeyName:
        return validateGeminiKey(key);
      case openaiApiKeyName:
        return validateOpenAIKey(key);
      default:
        // Validación genérica: no vacía y longitud razonable
        return key.isNotEmpty && key.length >= 20;
    }
  }

  /// Obtener información de una key (últimos 4 caracteres para verificación)
  Future<String?> getApiKeyPreview(String keyName) async {
    try {
      final key = await getApiKey(keyName);
      if (key == null || key.length < 4) return null;
      
      // Mostrar formato: "sk-...xyz123"
      final prefix = key.substring(0, key.indexOf('-') + 1).replaceAll(RegExp(r'[a-zA-Z0-9]'), '*');
      final suffix = key.substring(key.length - 4);
      return '$prefix...$suffix';
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error obteniendo preview: $e');
      return null;
    }
  }

  /// Método para debugging (solo desarrollo, nunca en producción)
  Future<void> printAllKeys() async {
    if (!kDebugMode) return; // Solo en modo debug
    
    try {
      debugPrint('🔍 [ApiKeysManager] === ESTADO DE API KEYS ===');
      final status = await getApiKeysStatus();
      
      for (var entry in status.entries) {
        final statusIcon = entry.value ? '✅' : '❌';
        debugPrint('   $statusIcon ${entry.key}: ${entry.value ? "Configurada" : "No configurada"}');
        
        if (entry.value) {
          final preview = await getApiKeyPreview(entry.key);
          debugPrint('      Preview: $preview');
        }
      }
      debugPrint('🔍 [ApiKeysManager] ========================\n');
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error en printAllKeys: $e');
    }
  }
}