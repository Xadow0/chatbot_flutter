import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../../core/services/secure_storage_service.dart';

/// Gestor de claves API
/// Proporciona una interfaz de alto nivel para gestionar las API keys
/// Diferencia entre keys por defecto (del .env) y keys personalizadas (del usuario)
class ApiKeysManager {
  // Singleton pattern
  static final ApiKeysManager _instance = ApiKeysManager._internal();
  factory ApiKeysManager() => _instance;
  ApiKeysManager._internal();

  final _storage = SecureStorageService();

  // Constantes de claves
  static const String geminiApiKeyName = 'GEMINI_API_KEY';
  static const String openaiApiKeyName = 'OPENAI_API_KEY';
  
  // Prefijo para identificar keys del usuario en el storage
  static const String _userKeyPrefix = 'user_api_key_';
  
  // Prefijo para marcar que el usuario usa key por defecto
  static const String _useDefaultPrefix = 'use_default_';

  /// Obtener el nombre completo de la clave de usuario
  String _getUserKeyName(String keyName) => '$_userKeyPrefix$keyName';
  
  /// Obtener el nombre de la bandera "usar por defecto"
  String _getUseDefaultFlagName(String keyName) => '$_useDefaultPrefix$keyName';

  /// Obtener la API key por defecto desde el .env (nunca expuesta al usuario)
  String? _getDefaultApiKey(String keyName) {
    try {
      final key = dotenv.env[keyName];
      if (key != null && key.isNotEmpty) {
        return key;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ [ApiKeysManager] Error obteniendo key por defecto: $e');
      return null;
    }
  }

  /// Verificar si el usuario está usando la key por defecto
  Future<bool> isUsingDefaultKey(String keyName) async {
    try {
      // Si hay una key de usuario guardada, no usa la por defecto
      final userKey = await _storage.read(key: _getUserKeyName(keyName));
      if (userKey != null && userKey.isNotEmpty) {
        return false;
      }
      
      // Si no hay key de usuario, verifica si existe una por defecto
      final defaultKey = _getDefaultApiKey(keyName);
      return defaultKey != null && defaultKey.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error verificando uso de key por defecto: $e');
      return false;
    }
  }

  /// Verificar si existe una key por defecto disponible
  bool hasDefaultKey(String keyName) {
    final defaultKey = _getDefaultApiKey(keyName);
    return defaultKey != null && defaultKey.isNotEmpty;
  }

  /// Guardar una API key personalizada del usuario
  Future<void> saveApiKey(String keyName, String apiKey) async {
    try {
      if (apiKey.trim().isEmpty) {
        throw Exception('La API key no puede estar vacía');
      }

      await _storage.write(
        key: _getUserKeyName(keyName),
        value: apiKey.trim(),
      );
      
      debugPrint('✅ [ApiKeysManager] API key de usuario guardada: $keyName');
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error guardando $keyName: $e');
      rethrow;
    }
  }

  /// Obtener la API key activa (usuario o por defecto)
  /// Esta es la que se usa internamente para las llamadas a la API
  Future<String?> getApiKey(String keyName) async {
    try {
      // Primero intentar obtener la key del usuario
      final userKey = await _storage.read(key: _getUserKeyName(keyName));
      if (userKey != null && userKey.isNotEmpty) {
        debugPrint('✅ [ApiKeysManager] Usando API key de usuario: $keyName');
        return userKey;
      }
      
      // Si no hay key de usuario, usar la por defecto
      final defaultKey = _getDefaultApiKey(keyName);
      if (defaultKey != null && defaultKey.isNotEmpty) {
        debugPrint('✅ [ApiKeysManager] Usando API key por defecto: $keyName');
        return defaultKey;
      }
      
      debugPrint('⚠️ [ApiKeysManager] No hay API key disponible: $keyName');
      return null;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error obteniendo $keyName: $e');
      return null;
    }
  }

  /// Obtener solo la API key del usuario (sin fallback a la por defecto)
  /// Usada para mostrar en la UI de configuración
  Future<String?> getUserApiKey(String keyName) async {
    try {
      final key = await _storage.read(key: _getUserKeyName(keyName));
      return (key != null && key.isNotEmpty) ? key : null;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error obteniendo key de usuario $keyName: $e');
      return null;
    }
  }

  /// Eliminar la API key personalizada del usuario (vuelve a usar la por defecto si existe)
  Future<void> deleteUserApiKey(String keyName) async {
    try {
      await _storage.delete(key: _getUserKeyName(keyName));
      debugPrint('🗑️ [ApiKeysManager] API key de usuario eliminada: $keyName');
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error eliminando $keyName: $e');
      rethrow;
    }
  }

  /// Restaurar a la API key por defecto (elimina la del usuario)
  Future<bool> restoreDefaultKey(String keyName) async {
    try {
      if (!hasDefaultKey(keyName)) {
        debugPrint('⚠️ [ApiKeysManager] No hay key por defecto para restaurar: $keyName');
        return false;
      }
      
      await deleteUserApiKey(keyName);
      debugPrint('✅ [ApiKeysManager] Restaurada key por defecto: $keyName');
      return true;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error restaurando key por defecto: $e');
      return false;
    }
  }

  /// Verificar si una API key está disponible (usuario o por defecto)
  Future<bool> hasApiKey(String keyName) async {
    try {
      final key = await getApiKey(keyName);
      return key != null && key.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error verificando $keyName: $e');
      return false;
    }
  }

  /// Verificar si el usuario tiene una key personalizada configurada
  Future<bool> hasUserApiKey(String keyName) async {
    try {
      final key = await getUserApiKey(keyName);
      return key != null && key.isNotEmpty;
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error verificando key de usuario $keyName: $e');
      return false;
    }
  }

  /// Verificar si existe al menos una API key configurada (usuario o por defecto)
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

  /// Obtener el estado detallado de todas las API keys
  Future<Map<String, ApiKeyStatus>> getApiKeysDetailedStatus() async {
    return {
      geminiApiKeyName: ApiKeyStatus(
        hasKey: await hasApiKey(geminiApiKeyName),
        isUserKey: await hasUserApiKey(geminiApiKeyName),
        isUsingDefault: await isUsingDefaultKey(geminiApiKeyName),
        hasDefaultAvailable: hasDefaultKey(geminiApiKeyName),
      ),
      openaiApiKeyName: ApiKeyStatus(
        hasKey: await hasApiKey(openaiApiKeyName),
        isUserKey: await hasUserApiKey(openaiApiKeyName),
        isUsingDefault: await isUsingDefaultKey(openaiApiKeyName),
        hasDefaultAvailable: hasDefaultKey(openaiApiKeyName),
      ),
    };
  }

  /// Obtener el estado de todas las API keys (compatibilidad)
  Future<Map<String, bool>> getApiKeysStatus() async {
    return {
      geminiApiKeyName: await hasApiKey(geminiApiKeyName),
      openaiApiKeyName: await hasApiKey(openaiApiKeyName),
    };
  }

  /// Eliminar todas las API keys de usuario
  Future<void> deleteAllUserApiKeys() async {
    try {
      await deleteUserApiKey(geminiApiKeyName);
      await deleteUserApiKey(openaiApiKeyName);
      debugPrint('🗑️ [ApiKeysManager] Todas las API keys de usuario eliminadas');
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error eliminando todas las keys: $e');
      rethrow;
    }
  }

  /// Validar formato de API key de Gemini
  bool validateGeminiKey(String key) {
    if (key.isEmpty) return false;
    if (key.length < 30) return false;
    
    final validChars = RegExp(r'^[A-Za-z0-9_-]+$');
    return validChars.hasMatch(key);
  }

  /// Validar formato de API key de OpenAI
  bool validateOpenAIKey(String key) {
    if (key.isEmpty) return false;
    if (!key.startsWith('sk-')) return false;
    if (key.length < 40) return false;
    
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
        return key.isNotEmpty && key.length >= 20;
    }
  }

  /// Obtener preview de la key del usuario (solo si es del usuario, nunca la por defecto)
  Future<String?> getUserApiKeyPreview(String keyName) async {
    try {
      final key = await getUserApiKey(keyName);
      if (key == null || key.length < 8) return null;
      
      // Mostrar formato: "****...xyz123"
      final suffix = key.substring(key.length - 4);
      return '••••••••...$suffix';
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error obteniendo preview: $e');
      return null;
    }
  }

  /// Método para debugging (solo desarrollo)
  Future<void> printAllKeys() async {
    if (!kDebugMode) return;
    
    try {
      debugPrint('🔍 [ApiKeysManager] === ESTADO DE API KEYS ===');
      final status = await getApiKeysDetailedStatus();
      
      for (var entry in status.entries) {
        final s = entry.value;
        debugPrint('   ${entry.key}:');
        debugPrint('      - Disponible: ${s.hasKey}');
        debugPrint('      - Es del usuario: ${s.isUserKey}');
        debugPrint('      - Usa por defecto: ${s.isUsingDefault}');
        debugPrint('      - Default disponible: ${s.hasDefaultAvailable}');
      }
      debugPrint('🔍 [ApiKeysManager] ========================\n');
    } catch (e) {
      debugPrint('❌ [ApiKeysManager] Error en printAllKeys: $e');
    }
  }
}

/// Clase para representar el estado detallado de una API key
class ApiKeyStatus {
  final bool hasKey;
  final bool isUserKey;
  final bool isUsingDefault;
  final bool hasDefaultAvailable;

  ApiKeyStatus({
    required this.hasKey,
    required this.isUserKey,
    required this.isUsingDefault,
    required this.hasDefaultAvailable,
  });
}