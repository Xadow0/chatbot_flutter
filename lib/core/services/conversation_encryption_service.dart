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
class ConversationEncryptionService {
  final SecureStorageService _secureStorage;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  static const String _saltKey = 'encryption_salt';
  static const int _keyLength = 32; // 256 bits para AES-256
  static const int _ivLength = 12;  // 96 bits para GCM 
  
  encrypt.Key? _cachedKey;
  String? _cachedUserId;

  ConversationEncryptionService(this._secureStorage);

  /// Obtiene o genera la clave de cifrado para el usuario actual.
  /// La clave se deriva del UID del usuario + un salt único almacenado de forma segura.
  Future<encrypt.Key> _getEncryptionKey() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado. No se puede cifrar.');
    }

    // Usar clave cacheada si el usuario no ha cambiado
    if (_cachedKey != null && _cachedUserId == user.uid) {
      return _cachedKey!;
    }

    // Obtener o generar salt único para este dispositivo/usuario
    String? salt = await _secureStorage.read(key: '${_saltKey}_${user.uid}');
    
    if (salt == null) {
      // Generar salt aleatorio de 32 bytes
      final secureRandom = encrypt.SecureRandom(_keyLength);
      salt = base64Encode(secureRandom.bytes);
      await _secureStorage.write(
        key: '${_saltKey}_${user.uid}',
        value: salt,
      );
      debugPrint('🔐 [Encryption] Salt generado para usuario ${user.uid.substring(0, 8)}...');
    }

    // Derivar clave usando HMAC-SHA256 (UID + salt)
    final keyMaterial = utf8.encode('${user.uid}:$salt');
    final hmacKey = Hmac(sha256, utf8.encode(salt));
    final derivedKey = hmacKey.convert(keyMaterial);
    
    // Tomar los primeros 32 bytes para AES-256
    final keyBytes = Uint8List.fromList(derivedKey.bytes.take(_keyLength).toList());
    
    _cachedKey = encrypt.Key(keyBytes);
    _cachedUserId = user.uid;
    
    debugPrint('🔑 [Encryption] Clave derivada para usuario ${user.uid.substring(0, 8)}...');
    
    return _cachedKey!;
  }

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
      debugPrint('🗑️ [Encryption] Salt de usuario eliminado');
    }
    clearCache();
  }
}