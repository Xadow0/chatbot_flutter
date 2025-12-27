import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Servicio de almacenamiento seguro usando flutter_secure_storage
/// Encapsula toda la lógica de cifrado y descifrado
class SecureStorageService {
  // Singleton pattern
  static final SecureStorageService _instance = SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  // Configuración de seguridad para flutter_secure_storage
  static const _androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  
  static const _iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock,
  );

  // Instancia de FlutterSecureStorage
  final _storage = const FlutterSecureStorage(
    aOptions: _androidOptions,
    iOptions: _iosOptions,
  );

  /// Guardar un valor de forma segura
  Future<void> write({
    required String key,
    required String value,
  }) async {
    try {
      await _storage.write(key: key, value: value);
      debugPrint('🔐 [SecureStorage] Guardado: $key');
    } catch (e) {
      debugPrint('❌ [SecureStorage] Error guardando $key: $e');
      rethrow;
    }
  }

  /// Leer un valor guardado
  Future<String?> read({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      if (value != null) {
        debugPrint('📖 [SecureStorage] Leído: $key');
      } else {
        debugPrint('📖 [SecureStorage] No encontrado: $key');
      }
      return value;
    } catch (e) {
      debugPrint('❌ [SecureStorage] Error leyendo $key: $e');
      return null;
    }
  }

  /// Eliminar un valor
  Future<void> delete({required String key}) async {
    try {
      await _storage.delete(key: key);
      debugPrint('🗑️ [SecureStorage] Eliminado: $key');
    } catch (e) {
      debugPrint('❌ [SecureStorage] Error eliminando $key: $e');
      rethrow;
    }
  }

  /// Verificar si existe una clave
  Future<bool> containsKey({required String key}) async {
    try {
      final value = await _storage.read(key: key);
      return value != null;
    } catch (e) {
      debugPrint('❌ [SecureStorage] Error verificando $key: $e');
      return false;
    }
  }

  /// Leer todos los valores guardados
  Future<Map<String, String>> readAll() async {
    try {
      final all = await _storage.readAll();
      debugPrint('📚 [SecureStorage] Leídos ${all.length} elementos');
      return all;
    } catch (e) {
      debugPrint('❌ [SecureStorage] Error leyendo todos: $e');
      return {};
    }
  }

  /// Eliminar todos los valores (usar con precaución)
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
      debugPrint('🗑️ [SecureStorage] Todos los datos eliminados');
    } catch (e) {
      debugPrint('❌ [SecureStorage] Error eliminando todos: $e');
      rethrow;
    }
  }

  /// Método de utilidad para debugging (NO usar en producción con datos sensibles)
  Future<List<String>> getAllKeys() async {
    try {
      final all = await _storage.readAll();
      return all.keys.toList();
    } catch (e) {
      debugPrint('❌ [SecureStorage] Error obteniendo claves: $e');
      return [];
    }
  }
}