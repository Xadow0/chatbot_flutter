import 'dart:convert';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'secure_storage_service.dart';

/// Servicio de cifrado para conversaciones almacenadas en Firebase.
/// 
/// Utiliza AES-GCM (rápido y seguro) con una clave derivada del UID del usuario.
/// Solo cifra el campo 'content' de cada mensaje para mantener el rendimiento.
/// 
/// CARACTERÍSTICAS:
/// - Cifrado AES-256-GCM (ligero y seguro)
/// - Clave única por usuario (derivada del UID + salt almacenado)
/// - IV aleatorio por mensaje (máxima seguridad)
/// - Formato: base64(iv:ciphertext:tag) para fácil almacenamiento
/// 
/// SINCRONIZACIÓN DE SALT MULTI-DISPOSITIVO:
/// - El salt se cifra con la contraseña del usuario (la misma del login)
/// - El salt cifrado se sube a Firebase automáticamente
/// - En dispositivos nuevos, se descarga y descifra automáticamente al iniciar sesión
/// - El usuario NO necesita ingresar la contraseña nuevamente - se usa la del login
/// - Esto permite descifrar conversaciones en cualquier dispositivo de forma transparente
class ConversationEncryptionService {
  final SecureStorageService _secureStorage;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _saltKey = 'encryption_salt';
  static const String _saltVersionKey = 'encryption_salt_version';
  static const int _keyLength = 32; // 256 bits para AES-256
  static const int _ivLength = 12;  // 96 bits para GCM 
  
  encrypt.Key? _cachedKey;
  String? _cachedUserId;

  ConversationEncryptionService(this._secureStorage);

  // ==========================================================================
  // GESTIÓN DE CLAVE DE CIFRADO
  // ==========================================================================

  /// Obtiene la clave de cifrado para el usuario actual.
  /// La clave se deriva del UID del usuario + el salt almacenado localmente.
  /// 
  /// IMPORTANTE: El salt debe estar inicializado previamente mediante
  /// [initializeWithPassword] que se llama automáticamente al iniciar sesión.
  Future<encrypt.Key> _getEncryptionKey() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado. No se puede cifrar.');
    }

    // Usar clave cacheada si el usuario no ha cambiado
    if (_cachedKey != null && _cachedUserId == user.uid) {
      return _cachedKey!;
    }

    // Obtener salt local
    String? salt = await _secureStorage.read(key: '${_saltKey}_${user.uid}');
    
    if (salt == null) {
      // No hay salt local - esto significa que initializeWithPassword
      // no fue llamado correctamente durante el login
      throw SaltNotFoundException(
        'Salt no inicializado. Esto no debería ocurrir si el login '
        'se realizó correctamente con sincronización activa.',
      );
    }

    return _deriveKeyFromSalt(user.uid, salt);
  }

  /// Deriva la clave de cifrado a partir del UID y el salt
  encrypt.Key _deriveKeyFromSalt(String uid, String salt) {
    // Derivar clave usando HMAC-SHA256 (UID + salt)
    final keyMaterial = utf8.encode('$uid:$salt');
    final hmacKey = Hmac(sha256, utf8.encode(salt));
    final derivedKey = hmacKey.convert(keyMaterial);
    
    // Tomar los primeros 32 bytes para AES-256
    final keyBytes = Uint8List.fromList(derivedKey.bytes.take(_keyLength).toList());
    
    final key = encrypt.Key(keyBytes);
    
    _cachedKey = key;
    _cachedUserId = uid;
    
    debugPrint('🔑 [Encryption] Clave derivada para usuario ${uid.substring(0, 8)}...');
    
    return key;
  }

  // ==========================================================================
  // GESTIÓN DE SALT - GENERACIÓN Y ALMACENAMIENTO LOCAL
  // ==========================================================================

  /// Genera un nuevo salt para el usuario actual.
  /// Retorna el salt generado (sin cifrar) para que pueda ser sincronizado.
  Future<String> generateNewSalt() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    // Generar salt aleatorio de 32 bytes
    final secureRandom = encrypt.SecureRandom(_keyLength);
    final salt = base64Encode(secureRandom.bytes);
    
    // Guardar localmente
    await _secureStorage.write(
      key: '${_saltKey}_${user.uid}',
      value: salt,
    );
    
    // Guardar versión del salt (timestamp para control de actualizaciones)
    final version = DateTime.now().millisecondsSinceEpoch.toString();
    await _secureStorage.write(
      key: '${_saltVersionKey}_${user.uid}',
      value: version,
    );
    
    // Limpiar cache para forzar recálculo de clave
    clearCache();
    
    debugPrint('🔐 [Encryption] Salt generado para usuario ${user.uid.substring(0, 8)}...');
    
    return salt;
  }

  /// Verifica si existe un salt local para el usuario actual
  Future<bool> hasLocalSalt() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    
    final salt = await _secureStorage.read(key: '${_saltKey}_${user.uid}');
    return salt != null;
  }

  /// Obtiene el salt local actual (sin cifrar)
  /// Retorna null si no existe
  Future<String?> getLocalSalt() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return await _secureStorage.read(key: '${_saltKey}_${user.uid}');
  }

  /// Obtiene la versión del salt local
  Future<String?> getLocalSaltVersion() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    
    return await _secureStorage.read(key: '${_saltVersionKey}_${user.uid}');
  }

  /// Guarda un salt descargado de Firebase (ya descifrado)
  Future<void> saveDecryptedSalt(String salt, String version) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    await _secureStorage.write(
      key: '${_saltKey}_${user.uid}',
      value: salt,
    );
    
    await _secureStorage.write(
      key: '${_saltVersionKey}_${user.uid}',
      value: version,
    );
    
    // Limpiar cache para forzar recálculo de clave
    clearCache();
    
    debugPrint('💾 [Encryption] Salt sincronizado guardado localmente');
  }

  // ==========================================================================
  // CIFRADO/DESCIFRADO DE SALT CON CONTRASEÑA
  // ==========================================================================

  /// Cifra el salt usando la contraseña del usuario.
  /// Este salt cifrado es seguro para subir a Firebase.
  /// 
  /// Proceso:
  /// 1. Deriva una clave de la contraseña usando PBKDF2-like (HMAC-SHA256)
  /// 2. Cifra el salt con AES-GCM
  /// 3. Retorna: base64(iv):base64(ciphertext)
  String encryptSaltWithPassword(String salt, String password) {
    try {
      // Derivar clave de la contraseña
      // Usamos un salt fijo derivado del propósito (no necesitamos aleatorio aquí
      // porque la contraseña ya provee entropía y el salt real es lo que protegemos)
      final passwordSalt = 'NexusAI_SaltEncryption_v1';
      final keyMaterial = utf8.encode('$password:$passwordSalt');
      final hmac = Hmac(sha256, utf8.encode(passwordSalt));
      final derivedKey = hmac.convert(keyMaterial);
      
      final key = encrypt.Key(
        Uint8List.fromList(derivedKey.bytes.take(_keyLength).toList()),
      );
      
      // Generar IV aleatorio
      final iv = encrypt.IV.fromSecureRandom(_ivLength);
      
      // Cifrar
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      final encrypted = encrypter.encrypt(salt, iv: iv);
      
      // Formato: iv:ciphertext
      final result = '${iv.base64}:${encrypted.base64}';
      
      debugPrint('🔒 [Encryption] Salt cifrado con contraseña');
      return result;
    } catch (e) {
      debugPrint('❌ [Encryption] Error cifrando salt con contraseña: $e');
      rethrow;
    }
  }

  /// Descifra el salt usando la contraseña del usuario.
  /// 
  /// Lanza [InvalidPasswordException] si la contraseña es incorrecta.
  String decryptSaltWithPassword(String encryptedSalt, String password) {
    try {
      if (!encryptedSalt.contains(':')) {
        throw FormatException('Formato de salt cifrado inválido');
      }
      
      final parts = encryptedSalt.split(':');
      if (parts.length != 2) {
        throw FormatException('Formato de salt cifrado inválido');
      }
      
      // Derivar clave de la contraseña (mismo proceso que al cifrar)
      final passwordSalt = 'NexusAI_SaltEncryption_v1';
      final keyMaterial = utf8.encode('$password:$passwordSalt');
      final hmac = Hmac(sha256, utf8.encode(passwordSalt));
      final derivedKey = hmac.convert(keyMaterial);
      
      final key = encrypt.Key(
        Uint8List.fromList(derivedKey.bytes.take(_keyLength).toList()),
      );
      
      // Extraer IV y ciphertext
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      
      // Descifrar
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      
      final decrypted = encrypter.decrypt(encrypted, iv: iv);
      
      debugPrint('🔓 [Encryption] Salt descifrado con contraseña');
      return decrypted;
    } on FormatException {
      rethrow;
    } catch (e) {
      // Los errores de descifrado generalmente indican contraseña incorrecta
      debugPrint('❌ [Encryption] Error descifrando salt (¿contraseña incorrecta?): $e');
      throw InvalidPasswordException(
        'No se pudo descifrar el salt. La contraseña puede ser incorrecta.',
      );
    }
  }

  // ==========================================================================
  // CIFRADO/DESCIFRADO DE CONTENIDO
  // ==========================================================================

  /// Cifra un texto plano.
  /// Retorna el texto cifrado en formato base64: iv:ciphertext (IV incluido)
  Future<String> encryptContent(String plainText) async {
    try {
      if (plainText.isEmpty) return plainText;
      
      final key = await _getEncryptionKey();
      
      // Generar IV aleatorio para cada mensaje (importante para seguridad)
      final iv = encrypt.IV.fromSecureRandom(_ivLength);
      
      // Crear encrypter con AES en modo GCM (más seguro y rápido que CBC)
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      
      // Cifrar
      final encrypted = encrypter.encrypt(plainText, iv: iv);
      
      // Formato: base64(iv):base64(ciphertext)
      // Esto permite extraer el IV para descifrar
      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      debugPrint('❌ [Encryption] Error cifrando: $e');
      rethrow;
    }
  }

  /// Descifra un texto cifrado.
  /// Espera el formato: iv:ciphertext (ambos en base64)
  Future<String> decryptContent(String encryptedText) async {
    try {
      if (encryptedText.isEmpty) return encryptedText;
      
      // Verificar si el texto está cifrado (contiene el separador)
      if (!encryptedText.contains(':')) {
        // Texto no cifrado, retornar tal cual (compatibilidad con datos antiguos)
        debugPrint('⚠️ [Encryption] Texto no cifrado detectado, retornando original');
        return encryptedText;
      }
      
      final parts = encryptedText.split(':');
      if (parts.length != 2) {
        // Formato inválido, podría ser texto plano con ':'
        // Intentar como texto plano
        debugPrint('⚠️ [Encryption] Formato no reconocido, retornando original');
        return encryptedText;
      }
      
      final key = await _getEncryptionKey();
      
      // Extraer IV y ciphertext
      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);
      
      // Crear encrypter
      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      
      // Descifrar
      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      debugPrint('❌ [Encryption] Error descifrando: $e');
      // En caso de error, retornar el texto original
      // Esto permite compatibilidad con mensajes no cifrados
      return encryptedText;
    }
  }

  /// Cifra una lista de mensajes (solo el campo 'content').
  /// Útil para cifrar toda una conversación antes de enviar a Firebase.
  Future<List<Map<String, dynamic>>> encryptMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final encryptedMessages = <Map<String, dynamic>>[];
    
    for (final message in messages) {
      final encryptedMessage = Map<String, dynamic>.from(message);
      
      if (message['content'] != null && message['content'] is String) {
        encryptedMessage['content'] = await encryptContent(message['content']);
        encryptedMessage['encrypted'] = true; // Marcador para identificar mensajes cifrados
      }
      
      encryptedMessages.add(encryptedMessage);
    }
    
    debugPrint('🔒 [Encryption] ${messages.length} mensajes cifrados');
    return encryptedMessages;
  }

  /// Descifra una lista de mensajes (solo el campo 'content').
  /// Útil para descifrar toda una conversación descargada de Firebase.
  Future<List<Map<String, dynamic>>> decryptMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final decryptedMessages = <Map<String, dynamic>>[];
    
    for (final message in messages) {
      final decryptedMessage = Map<String, dynamic>.from(message);
      
      // Solo descifrar si está marcado como cifrado o tiene el formato esperado
      if (message['content'] != null && message['content'] is String) {
        final content = message['content'] as String;
        
        // Verificar si está cifrado (tiene el marcador o el formato iv:ciphertext)
        if (message['encrypted'] == true || _looksEncrypted(content)) {
          decryptedMessage['content'] = await decryptContent(content);
          decryptedMessage.remove('encrypted'); // Limpiar marcador
        }
      }
      
      decryptedMessages.add(decryptedMessage);
    }
    
    debugPrint('🔓 [Encryption] ${messages.length} mensajes descifrados');
    return decryptedMessages;
  }

  /// Verifica si un texto parece estar cifrado (formato base64:base64)
  bool _looksEncrypted(String text) {
    if (!text.contains(':')) return false;
    
    final parts = text.split(':');
    if (parts.length != 2) return false;
    
    // Verificar que ambas partes parecen base64 válido
    try {
      base64Decode(parts[0]);
      base64Decode(parts[1]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==========================================================================
  // LIMPIEZA Y ELIMINACIÓN
  // ==========================================================================

  /// Limpia la clave cacheada (usar al cerrar sesión)
  void clearCache() {
    _cachedKey = null;
    _cachedUserId = null;
    debugPrint('🧹 [Encryption] Cache de clave limpiado');
  }

  /// Elimina el salt del usuario (usar al eliminar cuenta)
  Future<void> deleteUserSalt() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _secureStorage.delete(key: '${_saltKey}_${user.uid}');
      await _secureStorage.delete(key: '${_saltVersionKey}_${user.uid}');
      debugPrint('🗑️ [Encryption] Salt de usuario eliminado');
    }
    clearCache();
  }

  // ==========================================================================
  // INICIALIZACIÓN AUTOMÁTICA CON CONTRASEÑA DE LOGIN
  // ==========================================================================

  /// Inicializa el servicio de cifrado usando la contraseña del login.
  /// 
  /// Este método se llama AUTOMÁTICAMENTE durante el proceso de login
  /// cuando la sincronización está activa. El usuario NO necesita hacer nada.
  /// 
  /// FLUJO AUTOMÁTICO:
  /// 1. Usuario existente con sync activo:
  ///    - Descarga salt cifrado de Firebase
  ///    - Lo descifra con la contraseña del login
  ///    - Guarda localmente para uso futuro
  /// 
  /// 2. Usuario nuevo que activa sync:
  ///    - Genera salt nuevo
  ///    - Lo cifra con la contraseña
  ///    - Lo sube a Firebase
  /// 
  /// 3. Usuario con salt local sincronizado:
  ///    - Verifica que la versión coincida
  ///    - Si coincide, no hace nada (ya está listo)
  /// 
  /// [encryptedSaltFromFirebase]: Salt cifrado descargado de Firebase (null si no existe)
  /// [saltVersionFromFirebase]: Versión del salt en Firebase
  /// [password]: Contraseña del usuario (la misma que usó para iniciar sesión)
  /// 
  /// Retorna un [SaltInitResult] indicando si se necesita subir el salt a Firebase.
  Future<SaltInitResult> initializeWithPassword({
    String? encryptedSaltFromFirebase,
    String? saltVersionFromFirebase,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    debugPrint('🔐 [Encryption] Inicializando cifrado para ${user.uid.substring(0, 8)}...');

    // Caso 1: Existe salt en Firebase (usuario existente o dispositivo nuevo)
    if (encryptedSaltFromFirebase != null && encryptedSaltFromFirebase.isNotEmpty) {
      // Verificar si ya tenemos el salt local con la misma versión
      final localVersion = await getLocalSaltVersion();
      
      if (localVersion == saltVersionFromFirebase) {
        // Ya tenemos el salt correcto localmente - no hacer nada
        debugPrint('✅ [Encryption] Salt local ya sincronizado (v$localVersion)');
        return SaltInitResult(
          success: true,
          needsUpload: false,
        );
      }
      
      // Descifrar salt de Firebase con la contraseña del login
      try {
        final decryptedSalt = decryptSaltWithPassword(
          encryptedSaltFromFirebase,
          password,
        );
        
        // Guardar localmente
        await saveDecryptedSalt(
          decryptedSalt,
          saltVersionFromFirebase ?? DateTime.now().millisecondsSinceEpoch.toString(),
        );
        
        debugPrint('✅ [Encryption] Salt descargado de Firebase y guardado localmente');
        return SaltInitResult(
          success: true,
          needsUpload: false,
        );
      } on InvalidPasswordException {
        // Esto NO debería ocurrir si la contraseña es la correcta del login
        debugPrint('❌ [Encryption] Error: contraseña incorrecta (esto no debería pasar)');
        rethrow;
      }
    }
    
    // Caso 2: No existe salt en Firebase
    // Verificar si tenemos salt local (generado previamente en este dispositivo)
    final localSalt = await getLocalSalt();
    
    if (localSalt != null) {
      // Tenemos salt local pero no en Firebase - subirlo
      final encryptedSalt = encryptSaltWithPassword(localSalt, password);
      final version = await getLocalSaltVersion() ?? 
          DateTime.now().millisecondsSinceEpoch.toString();
      
      debugPrint('📤 [Encryption] Subiendo salt local existente a Firebase');
      return SaltInitResult(
        success: true,
        needsUpload: true,
        encryptedSalt: encryptedSalt,
        saltVersion: version,
      );
    }
    
    // Caso 3: No hay salt ni local ni en Firebase - generar nuevo
    // (Usuario nuevo que activa sync por primera vez)
    final newSalt = await generateNewSalt();
    final encryptedSalt = encryptSaltWithPassword(newSalt, password);
    final version = await getLocalSaltVersion()!;
    
    debugPrint('🆕 [Encryption] Nuevo salt generado, subiéndolo a Firebase');
    return SaltInitResult(
      success: true,
      needsUpload: true,
      encryptedSalt: encryptedSalt,
      saltVersion: version,
    );
  }

  /// Actualiza el salt cifrado cuando el usuario cambia su contraseña.
  /// 
  /// IMPORTANTE: Este método debe llamarse cuando el usuario cambia
  /// su contraseña en Firebase Auth para mantener el salt accesible.
  /// 
  /// [oldPassword]: Contraseña anterior
  /// [newPassword]: Nueva contraseña
  /// [currentEncryptedSalt]: Salt cifrado actual de Firebase
  /// 
  /// Retorna el nuevo salt cifrado para subir a Firebase.
  Future<String> reencryptSaltForPasswordChange({
    required String oldPassword,
    required String newPassword,
    required String currentEncryptedSalt,
  }) async {
    // Descifrar con contraseña antigua
    final salt = decryptSaltWithPassword(currentEncryptedSalt, oldPassword);
    
    // Cifrar con contraseña nueva
    final newEncryptedSalt = encryptSaltWithPassword(salt, newPassword);
    
    debugPrint('🔄 [Encryption] Salt recifrado con nueva contraseña');
    return newEncryptedSalt;
  }
}

// ==========================================================================
// EXCEPCIONES PERSONALIZADAS
// ==========================================================================

/// Excepción lanzada cuando no se encuentra el salt localmente
class SaltNotFoundException implements Exception {
  final String message;
  SaltNotFoundException(this.message);
  
  @override
  String toString() => message;
}

/// Excepción lanzada cuando la contraseña es incorrecta al descifrar el salt
class InvalidPasswordException implements Exception {
  final String message;
  InvalidPasswordException(this.message);
  
  @override
  String toString() => message;
}

// ==========================================================================
// RESULTADO DE INICIALIZACIÓN DE SALT
// ==========================================================================

/// Resultado de la inicialización del salt
class SaltInitResult {
  final bool success;
  final bool needsUpload;
  final String? encryptedSalt;
  final String? saltVersion;
  final String? error;

  SaltInitResult({
    required this.success,
    required this.needsUpload,
    this.encryptedSalt,
    this.saltVersion,
    this.error,
  });
}