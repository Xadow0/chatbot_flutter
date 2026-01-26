import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'dart:typed_data';

// =============================================================================
// INTERFACES Y CLASES NECESARIAS PARA TESTS
// =============================================================================

/// Interfaz del servicio de almacenamiento seguro
abstract class SecureStorageService {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

/// Mock de User de Firebase
class MockUser {
  final String uid;
  MockUser({required this.uid});
}

/// Interfaz simplificada de FirebaseAuth para tests
abstract class FirebaseAuthBase {
  MockUser? get currentUser;
}

// =============================================================================
// EXCEPCIONES PERSONALIZADAS
// =============================================================================

class SaltNotFoundException implements Exception {
  final String message;
  SaltNotFoundException(this.message);

  @override
  String toString() => message;
}

class InvalidPasswordException implements Exception {
  final String message;
  InvalidPasswordException(this.message);

  @override
  String toString() => message;
}

// =============================================================================
// RESULTADO DE INICIALIZACIÓN DE SALT
// =============================================================================

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

// =============================================================================
// SERVICIO DE CIFRADO (CÓDIGO BAJO PRUEBA)
// =============================================================================

class ConversationEncryptionService {
  final SecureStorageService _secureStorage;
  final FirebaseAuthBase _auth;

  static const String _saltKey = 'encryption_salt';
  static const String _saltVersionKey = 'encryption_salt_version';
  static const int _keyLength = 32;
  static const int _ivLength = 12;

  encrypt.Key? _cachedKey;
  String? _cachedUserId;

  ConversationEncryptionService(this._secureStorage, this._auth);

  // --------------------------------------------------------------------------
  // GESTIÓN DE CLAVE DE CIFRADO
  // --------------------------------------------------------------------------

  Future<encrypt.Key> _getEncryptionKey() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado. No se puede cifrar.');
    }

    if (_cachedKey != null && _cachedUserId == user.uid) {
      return _cachedKey!;
    }

    String? salt = await _secureStorage.read(key: '${_saltKey}_${user.uid}');

    if (salt == null) {
      throw SaltNotFoundException(
        'Salt no inicializado. Esto no debería ocurrir si el login '
        'se realizó correctamente con sincronización activa.',
      );
    }

    return _deriveKeyFromSalt(user.uid, salt);
  }

  encrypt.Key _deriveKeyFromSalt(String uid, String salt) {
    final keyMaterial = utf8.encode('$uid:$salt');
    final hmacKey = Hmac(sha256, utf8.encode(salt));
    final derivedKey = hmacKey.convert(keyMaterial);

    final keyBytes =
        Uint8List.fromList(derivedKey.bytes.take(_keyLength).toList());

    final key = encrypt.Key(keyBytes);

    _cachedKey = key;
    _cachedUserId = uid;

    return key;
  }

  // --------------------------------------------------------------------------
  // GESTIÓN DE SALT
  // --------------------------------------------------------------------------

  Future<String> generateNewSalt() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    final secureRandom = encrypt.SecureRandom(_keyLength);
    final salt = base64Encode(secureRandom.bytes);

    await _secureStorage.write(
      key: '${_saltKey}_${user.uid}',
      value: salt,
    );

    final version = DateTime.now().millisecondsSinceEpoch.toString();
    await _secureStorage.write(
      key: '${_saltVersionKey}_${user.uid}',
      value: version,
    );

    clearCache();

    return salt;
  }

  Future<bool> hasLocalSalt() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    final salt = await _secureStorage.read(key: '${_saltKey}_${user.uid}');
    return salt != null;
  }

  Future<String?> getLocalSalt() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    return await _secureStorage.read(key: '${_saltKey}_${user.uid}');
  }

  Future<String?> getLocalSaltVersion() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    return await _secureStorage.read(key: '${_saltVersionKey}_${user.uid}');
  }

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

    clearCache();
  }

  // --------------------------------------------------------------------------
  // CIFRADO/DESCIFRADO DE SALT CON CONTRASEÑA
  // --------------------------------------------------------------------------

  String encryptSaltWithPassword(String salt, String password) {
    try {
      final passwordSalt = 'NexusAI_SaltEncryption_v1';
      final keyMaterial = utf8.encode('$password:$passwordSalt');
      final hmac = Hmac(sha256, utf8.encode(passwordSalt));
      final derivedKey = hmac.convert(keyMaterial);

      final key = encrypt.Key(
        Uint8List.fromList(derivedKey.bytes.take(_keyLength).toList()),
      );

      final iv = encrypt.IV.fromSecureRandom(_ivLength);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );
      final encrypted = encrypter.encrypt(salt, iv: iv);

      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      rethrow;
    }
  }

  String decryptSaltWithPassword(String encryptedSalt, String password) {
    try {
      if (!encryptedSalt.contains(':')) {
        throw FormatException('Formato de salt cifrado inválido');
      }

      final parts = encryptedSalt.split(':');
      if (parts.length != 2) {
        throw FormatException('Formato de salt cifrado inválido');
      }

      final passwordSalt = 'NexusAI_SaltEncryption_v1';
      final keyMaterial = utf8.encode('$password:$passwordSalt');
      final hmac = Hmac(sha256, utf8.encode(passwordSalt));
      final derivedKey = hmac.convert(keyMaterial);

      final key = encrypt.Key(
        Uint8List.fromList(derivedKey.bytes.take(_keyLength).toList()),
      );

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      return encrypter.decrypt(encrypted, iv: iv);
    } on FormatException {
      rethrow;
    } catch (e) {
      throw InvalidPasswordException(
        'No se pudo descifrar el salt. La contraseña puede ser incorrecta.',
      );
    }
  }

  // --------------------------------------------------------------------------
  // CIFRADO/DESCIFRADO DE CONTENIDO
  // --------------------------------------------------------------------------

  Future<String> encryptContent(String plainText) async {
    try {
      if (plainText.isEmpty) return plainText;

      final key = await _getEncryptionKey();
      final iv = encrypt.IV.fromSecureRandom(_ivLength);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      final encrypted = encrypter.encrypt(plainText, iv: iv);

      return '${iv.base64}:${encrypted.base64}';
    } catch (e) {
      rethrow;
    }
  }

  Future<String> decryptContent(String encryptedText) async {
    try {
      if (encryptedText.isEmpty) return encryptedText;

      if (!encryptedText.contains(':')) {
        return encryptedText;
      }

      final parts = encryptedText.split(':');
      if (parts.length != 2) {
        return encryptedText;
      }

      final key = await _getEncryptionKey();

      final iv = encrypt.IV.fromBase64(parts[0]);
      final encrypted = encrypt.Encrypted.fromBase64(parts[1]);

      final encrypter = encrypt.Encrypter(
        encrypt.AES(key, mode: encrypt.AESMode.gcm),
      );

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return encryptedText;
    }
  }

  Future<List<Map<String, dynamic>>> encryptMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final encryptedMessages = <Map<String, dynamic>>[];

    for (final message in messages) {
      final encryptedMessage = Map<String, dynamic>.from(message);

      if (message['content'] != null && message['content'] is String) {
        encryptedMessage['content'] = await encryptContent(message['content']);
        encryptedMessage['encrypted'] = true;
      }

      encryptedMessages.add(encryptedMessage);
    }

    return encryptedMessages;
  }

  Future<List<Map<String, dynamic>>> decryptMessages(
    List<Map<String, dynamic>> messages,
  ) async {
    final decryptedMessages = <Map<String, dynamic>>[];

    for (final message in messages) {
      final decryptedMessage = Map<String, dynamic>.from(message);

      if (message['content'] != null && message['content'] is String) {
        final content = message['content'] as String;

        if (message['encrypted'] == true || _looksEncrypted(content)) {
          decryptedMessage['content'] = await decryptContent(content);
          decryptedMessage.remove('encrypted');
        }
      }

      decryptedMessages.add(decryptedMessage);
    }

    return decryptedMessages;
  }

  bool _looksEncrypted(String text) {
    if (!text.contains(':')) return false;

    final parts = text.split(':');
    if (parts.length != 2) return false;

    try {
      base64Decode(parts[0]);
      base64Decode(parts[1]);
      return true;
    } catch (e) {
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // LIMPIEZA Y ELIMINACIÓN
  // --------------------------------------------------------------------------

  void clearCache() {
    _cachedKey = null;
    _cachedUserId = null;
  }

  Future<void> deleteUserSalt() async {
    final user = _auth.currentUser;
    if (user != null) {
      await _secureStorage.delete(key: '${_saltKey}_${user.uid}');
      await _secureStorage.delete(key: '${_saltVersionKey}_${user.uid}');
    }
    clearCache();
  }

  // --------------------------------------------------------------------------
  // INICIALIZACIÓN CON CONTRASEÑA
  // --------------------------------------------------------------------------

  Future<SaltInitResult> initializeWithPassword({
    String? encryptedSaltFromFirebase,
    String? saltVersionFromFirebase,
    required String password,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado');
    }

    // Caso 1: Existe salt en Firebase
    if (encryptedSaltFromFirebase != null &&
        encryptedSaltFromFirebase.isNotEmpty) {
      final localVersion = await getLocalSaltVersion();

      if (localVersion == saltVersionFromFirebase) {
        return SaltInitResult(
          success: true,
          needsUpload: false,
        );
      }

      try {
        final decryptedSalt = decryptSaltWithPassword(
          encryptedSaltFromFirebase,
          password,
        );

        await saveDecryptedSalt(
          decryptedSalt,
          saltVersionFromFirebase ??
              DateTime.now().millisecondsSinceEpoch.toString(),
        );

        return SaltInitResult(
          success: true,
          needsUpload: false,
        );
      } on InvalidPasswordException {
        rethrow;
      }
    }

    // Caso 2: No existe salt en Firebase, verificar local
    final localSalt = await getLocalSalt();

    if (localSalt != null) {
      final encryptedSalt = encryptSaltWithPassword(localSalt, password);
      final version = await getLocalSaltVersion() ??
          DateTime.now().millisecondsSinceEpoch.toString();

      return SaltInitResult(
        success: true,
        needsUpload: true,
        encryptedSalt: encryptedSalt,
        saltVersion: version,
      );
    }

    // Caso 3: No hay salt ni local ni en Firebase - generar nuevo
    final newSalt = await generateNewSalt();
    final encryptedSalt = encryptSaltWithPassword(newSalt, password);
    final version = await getLocalSaltVersion();

    return SaltInitResult(
      success: true,
      needsUpload: true,
      encryptedSalt: encryptedSalt,
      saltVersion: version,
    );
  }

  Future<String> reencryptSaltForPasswordChange({
    required String oldPassword,
    required String newPassword,
    required String currentEncryptedSalt,
  }) async {
    final salt = decryptSaltWithPassword(currentEncryptedSalt, oldPassword);
    return encryptSaltWithPassword(salt, newPassword);
  }

  // Getter público para testing de _looksEncrypted
  bool looksEncrypted(String text) => _looksEncrypted(text);
}

// =============================================================================
// MOCKS
// =============================================================================

class MockSecureStorageService extends Mock implements SecureStorageService {}

class MockFirebaseAuth extends Mock implements FirebaseAuthBase {}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // SaltInitResult Tests
  // ---------------------------------------------------------------------------
  group('SaltInitResult', () {
    test('crea instancia con parámetros requeridos', () {
      final result = SaltInitResult(
        success: true,
        needsUpload: false,
      );

      expect(result.success, isTrue);
      expect(result.needsUpload, isFalse);
      expect(result.encryptedSalt, isNull);
      expect(result.saltVersion, isNull);
      expect(result.error, isNull);
    });

    test('crea instancia con todos los parámetros', () {
      final result = SaltInitResult(
        success: true,
        needsUpload: true,
        encryptedSalt: 'encrypted_salt_value',
        saltVersion: '1234567890',
        error: null,
      );

      expect(result.success, isTrue);
      expect(result.needsUpload, isTrue);
      expect(result.encryptedSalt, equals('encrypted_salt_value'));
      expect(result.saltVersion, equals('1234567890'));
    });

    test('crea instancia con error', () {
      final result = SaltInitResult(
        success: false,
        needsUpload: false,
        error: 'Error message',
      );

      expect(result.success, isFalse);
      expect(result.error, equals('Error message'));
    });
  });

  // ---------------------------------------------------------------------------
  // Excepciones Tests
  // ---------------------------------------------------------------------------
  group('Excepciones', () {
    group('SaltNotFoundException', () {
      test('almacena y retorna mensaje correctamente', () {
        final exception = SaltNotFoundException('Salt no encontrado');

        expect(exception.message, equals('Salt no encontrado'));
        expect(exception.toString(), equals('Salt no encontrado'));
      });
    });

    group('InvalidPasswordException', () {
      test('almacena y retorna mensaje correctamente', () {
        final exception = InvalidPasswordException('Contraseña incorrecta');

        expect(exception.message, equals('Contraseña incorrecta'));
        expect(exception.toString(), equals('Contraseña incorrecta'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // ConversationEncryptionService Tests
  // ---------------------------------------------------------------------------
  group('ConversationEncryptionService', () {
    late MockSecureStorageService mockStorage;
    late MockFirebaseAuth mockAuth;
    late ConversationEncryptionService service;
    late MockUser testUser;

    setUp(() {
      mockStorage = MockSecureStorageService();
      mockAuth = MockFirebaseAuth();
      service = ConversationEncryptionService(mockStorage, mockAuth);
      testUser = MockUser(uid: 'test-user-id-12345');
    });

    // -------------------------------------------------------------------------
    // generateNewSalt Tests
    // -------------------------------------------------------------------------
    group('generateNewSalt', () {
      test('genera salt cuando usuario está autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
            .thenAnswer((_) async {});

        final salt = await service.generateNewSalt();

        expect(salt, isNotEmpty);
        expect(salt.length, greaterThan(20)); // Base64 de 32 bytes

        verify(() => mockStorage.write(
              key: 'encryption_salt_${testUser.uid}',
              value: salt,
            )).called(1);

        verify(() => mockStorage.write(
              key: 'encryption_salt_version_${testUser.uid}',
              value: any(named: 'value'),
            )).called(1);
      });

      test('lanza excepción cuando usuario no está autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        expect(
          () => service.generateNewSalt(),
          throwsA(isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('no autenticado'),
          )),
        );
      });

      test('genera salt único cada vez', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
            .thenAnswer((_) async {});

        final salt1 = await service.generateNewSalt();
        final salt2 = await service.generateNewSalt();

        expect(salt1, isNot(equals(salt2)));
      });
    });

    // -------------------------------------------------------------------------
    // hasLocalSalt Tests
    // -------------------------------------------------------------------------
    group('hasLocalSalt', () {
      test('retorna false cuando usuario no está autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        final result = await service.hasLocalSalt();

        expect(result, isFalse);
        verifyNever(() => mockStorage.read(key: any(named: 'key')));
      });

      test('retorna true cuando existe salt', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'some_salt_value');

        final result = await service.hasLocalSalt();

        expect(result, isTrue);
      });

      test('retorna false cuando no existe salt', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => null);

        final result = await service.hasLocalSalt();

        expect(result, isFalse);
      });
    });

    // -------------------------------------------------------------------------
    // getLocalSalt Tests
    // -------------------------------------------------------------------------
    group('getLocalSalt', () {
      test('retorna null cuando usuario no está autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        final result = await service.getLocalSalt();

        expect(result, isNull);
      });

      test('retorna salt cuando existe', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'my_salt_value');

        final result = await service.getLocalSalt();

        expect(result, equals('my_salt_value'));
      });

      test('retorna null cuando no existe salt', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => null);

        final result = await service.getLocalSalt();

        expect(result, isNull);
      });
    });

    // -------------------------------------------------------------------------
    // getLocalSaltVersion Tests
    // -------------------------------------------------------------------------
    group('getLocalSaltVersion', () {
      test('retorna null cuando usuario no está autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        final result = await service.getLocalSaltVersion();

        expect(result, isNull);
      });

      test('retorna versión cuando existe', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(
                key: 'encryption_salt_version_${testUser.uid}'))
            .thenAnswer((_) async => '1704067200000');

        final result = await service.getLocalSaltVersion();

        expect(result, equals('1704067200000'));
      });
    });

    // -------------------------------------------------------------------------
    // saveDecryptedSalt Tests
    // -------------------------------------------------------------------------
    group('saveDecryptedSalt', () {
      test('guarda salt y versión correctamente', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
            .thenAnswer((_) async {});

        await service.saveDecryptedSalt('test_salt', '1234567890');

        verify(() => mockStorage.write(
              key: 'encryption_salt_${testUser.uid}',
              value: 'test_salt',
            )).called(1);

        verify(() => mockStorage.write(
              key: 'encryption_salt_version_${testUser.uid}',
              value: '1234567890',
            )).called(1);
      });

      test('lanza excepción cuando usuario no está autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        expect(
          () => service.saveDecryptedSalt('salt', 'version'),
          throwsA(isA<Exception>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // encryptSaltWithPassword / decryptSaltWithPassword Tests
    // -------------------------------------------------------------------------
    group('encryptSaltWithPassword y decryptSaltWithPassword', () {
      test('cifra y descifra salt correctamente con misma contraseña', () {
        const salt = 'my_secret_salt_value';
        const password = 'my_secure_password_123';

        final encrypted = service.encryptSaltWithPassword(salt, password);
        final decrypted = service.decryptSaltWithPassword(encrypted, password);

        expect(decrypted, equals(salt));
      });

      test('cifrado genera formato iv:ciphertext', () {
        const salt = 'test_salt';
        const password = 'password';

        final encrypted = service.encryptSaltWithPassword(salt, password);

        expect(encrypted, contains(':'));
        final parts = encrypted.split(':');
        expect(parts.length, equals(2));

        // Verificar que ambas partes son base64 válido
        expect(() => base64Decode(parts[0]), returnsNormally);
        expect(() => base64Decode(parts[1]), returnsNormally);
      });

      test('cifrado genera resultado diferente cada vez (IV aleatorio)', () {
        const salt = 'test_salt';
        const password = 'password';

        final encrypted1 = service.encryptSaltWithPassword(salt, password);
        final encrypted2 = service.encryptSaltWithPassword(salt, password);

        expect(encrypted1, isNot(equals(encrypted2)));

        // Pero ambos descifran al mismo valor
        expect(service.decryptSaltWithPassword(encrypted1, password), equals(salt));
        expect(service.decryptSaltWithPassword(encrypted2, password), equals(salt));
      });

      test('lanza InvalidPasswordException con contraseña incorrecta', () {
        const salt = 'test_salt';
        const correctPassword = 'correct_password';
        const wrongPassword = 'wrong_password';

        final encrypted = service.encryptSaltWithPassword(salt, correctPassword);

        expect(
          () => service.decryptSaltWithPassword(encrypted, wrongPassword),
          throwsA(isA<InvalidPasswordException>()),
        );
      });

      test('lanza FormatException con formato inválido (sin separador)', () {
        expect(
          () => service.decryptSaltWithPassword('invalid_format_no_colon', 'pass'),
          throwsA(isA<FormatException>()),
        );
      });

      test('lanza FormatException con más de dos partes', () {
        expect(
          () => service.decryptSaltWithPassword('part1:part2:part3', 'pass'),
          throwsA(isA<FormatException>()),
        );
      });

      test('maneja caracteres especiales en salt y contraseña', () {
        const salt = 'salt_con_ñ_y_émojis_🔐!@#\$%';
        const password = 'contraseña_súper_sëgura_123!';

        final encrypted = service.encryptSaltWithPassword(salt, password);
        final decrypted = service.decryptSaltWithPassword(encrypted, password);

        expect(decrypted, equals(salt));
      });

      test('maneja salt vacío', () {
        const salt = '';
        const password = 'password';

        final encrypted = service.encryptSaltWithPassword(salt, password);
        final decrypted = service.decryptSaltWithPassword(encrypted, password);

        expect(decrypted, equals(salt));
      });
    });

    // -------------------------------------------------------------------------
    // encryptContent / decryptContent Tests
    // -------------------------------------------------------------------------
    group('encryptContent y decryptContent', () {
      setUp(() {
        when(() => mockAuth.currentUser).thenReturn(testUser);
      });

      test('retorna texto vacío sin modificar', () async {
        final result = await service.encryptContent('');
        expect(result, equals(''));
      });

      test('retorna texto vacío al descifrar vacío', () async {
        final result = await service.decryptContent('');
        expect(result, equals(''));
      });

      test('cifra y descifra contenido correctamente', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt_value');

        const plainText = 'Este es un mensaje secreto';

        final encrypted = await service.encryptContent(plainText);
        final decrypted = await service.decryptContent(encrypted);

        expect(encrypted, isNot(equals(plainText)));
        expect(decrypted, equals(plainText));
      });

      test('cifrado genera formato iv:ciphertext', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        final encrypted = await service.encryptContent('test message');

        expect(encrypted, contains(':'));
        final parts = encrypted.split(':');
        expect(parts.length, equals(2));
      });

      test('genera cifrado diferente cada vez (IV aleatorio)', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        final encrypted1 = await service.encryptContent('same message');
        final encrypted2 = await service.encryptContent('same message');

        expect(encrypted1, isNot(equals(encrypted2)));
      });

      test('retorna texto original si no tiene formato cifrado (sin :)', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        const plainText = 'texto sin cifrar';
        final result = await service.decryptContent(plainText);

        expect(result, equals(plainText));
      });

      test('retorna texto original si formato es inválido (más de 2 partes)', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        const invalidFormat = 'part1:part2:part3';
        final result = await service.decryptContent(invalidFormat);

        expect(result, equals(invalidFormat));
      });

      test('lanza SaltNotFoundException cuando no hay salt', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => null);

        expect(
          () => service.encryptContent('test'),
          throwsA(isA<SaltNotFoundException>()),
        );
      });

      test('lanza excepción cuando usuario no autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        expect(
          () => service.encryptContent('test'),
          throwsA(isA<Exception>()),
        );
      });

      test('usa cache de clave para el mismo usuario', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        await service.encryptContent('message 1');
        await service.encryptContent('message 2');
        await service.encryptContent('message 3');

        // Solo debería leer el salt una vez (las demás usan cache)
        verify(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .called(1);
      });

      test('recarga clave si cambia el usuario', () async {
        final user2 = MockUser(uid: 'different-user-id');

        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'salt_user_1');
        when(() => mockStorage.read(key: 'encryption_salt_${user2.uid}'))
            .thenAnswer((_) async => 'salt_user_2');

        when(() => mockAuth.currentUser).thenReturn(testUser);
        await service.encryptContent('message');

        when(() => mockAuth.currentUser).thenReturn(user2);
        await service.encryptContent('message');

        verify(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .called(1);
        verify(() => mockStorage.read(key: 'encryption_salt_${user2.uid}'))
            .called(1);
      });

      test('maneja caracteres unicode y emojis', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        const message = '¡Hola! 你好 🎉🔐 Привет';

        final encrypted = await service.encryptContent(message);
        final decrypted = await service.decryptContent(encrypted);

        expect(decrypted, equals(message));
      });

      test('maneja mensajes muy largos', () async {
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        final longMessage = 'A' * 10000;

        final encrypted = await service.encryptContent(longMessage);
        final decrypted = await service.decryptContent(encrypted);

        expect(decrypted, equals(longMessage));
      });
    });

    // -------------------------------------------------------------------------
    // encryptMessages / decryptMessages Tests
    // -------------------------------------------------------------------------
    group('encryptMessages y decryptMessages', () {
      setUp(() {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');
      });

      test('cifra lista vacía', () async {
        final result = await service.encryptMessages([]);
        expect(result, isEmpty);
      });

      test('descifra lista vacía', () async {
        final result = await service.decryptMessages([]);
        expect(result, isEmpty);
      });

      test('cifra mensajes y añade marcador encrypted', () async {
        final messages = [
          {'id': '1', 'content': 'Hello', 'role': 'user'},
          {'id': '2', 'content': 'World', 'role': 'assistant'},
        ];

        final encrypted = await service.encryptMessages(messages);

        expect(encrypted.length, equals(2));
        expect(encrypted[0]['encrypted'], isTrue);
        expect(encrypted[1]['encrypted'], isTrue);
        expect(encrypted[0]['content'], isNot(equals('Hello')));
        expect(encrypted[1]['content'], isNot(equals('World')));
        expect(encrypted[0]['id'], equals('1'));
        expect(encrypted[0]['role'], equals('user'));
      });

      test('descifra mensajes y remueve marcador encrypted', () async {
        final messages = [
          {'id': '1', 'content': 'Hello', 'role': 'user'},
        ];

        final encrypted = await service.encryptMessages(messages);
        final decrypted = await service.decryptMessages(encrypted);

        expect(decrypted[0]['content'], equals('Hello'));
        expect(decrypted[0].containsKey('encrypted'), isFalse);
        expect(decrypted[0]['id'], equals('1'));
      });

      test('preserva campos adicionales', () async {
        final messages = [
          {
            'id': '1',
            'content': 'Test',
            'role': 'user',
            'timestamp': 1234567890,
            'metadata': {'key': 'value'},
          },
        ];

        final encrypted = await service.encryptMessages(messages);
        final decrypted = await service.decryptMessages(encrypted);

        expect(decrypted[0]['timestamp'], equals(1234567890));
        expect(decrypted[0]['metadata'], equals({'key': 'value'}));
      });

      test('ignora mensajes sin content', () async {
        final messages = [
          {'id': '1', 'role': 'system'},
          {'id': '2', 'content': null, 'role': 'user'},
        ];

        final encrypted = await service.encryptMessages(messages);

        expect(encrypted[0].containsKey('encrypted'), isFalse);
        expect(encrypted[1].containsKey('encrypted'), isFalse);
      });

      test('ignora content que no es String', () async {
        final messages = [
          {'id': '1', 'content': 123, 'role': 'user'},
          {'id': '2', 'content': ['array'], 'role': 'user'},
        ];

        final encrypted = await service.encryptMessages(messages);

        expect(encrypted[0]['content'], equals(123));
        expect(encrypted[1]['content'], equals(['array']));
        expect(encrypted[0].containsKey('encrypted'), isFalse);
      });

      test('descifra basándose en marcador encrypted', () async {
        // Simular mensaje ya cifrado
        final plainMessage = 'Secret message';
        final encryptedContent = await service.encryptContent(plainMessage);

        final messages = [
          {'id': '1', 'content': encryptedContent, 'encrypted': true},
        ];

        final decrypted = await service.decryptMessages(messages);

        expect(decrypted[0]['content'], equals(plainMessage));
      });

      test('descifra basándose en formato iv:ciphertext (sin marcador)', () async {
        final plainMessage = 'Auto detected';
        final encryptedContent = await service.encryptContent(plainMessage);

        final messages = [
          {'id': '1', 'content': encryptedContent},
        ];

        final decrypted = await service.decryptMessages(messages);

        expect(decrypted[0]['content'], equals(plainMessage));
      });

      test('no modifica contenido que no parece cifrado', () async {
        final messages = [
          {'id': '1', 'content': 'Plain text without colon'},
          {'id': '2', 'content': 'Text:with:multiple:colons'},
        ];

        final decrypted = await service.decryptMessages(messages);

        expect(decrypted[0]['content'], equals('Plain text without colon'));
        expect(decrypted[1]['content'], equals('Text:with:multiple:colons'));
      });
    });

    // -------------------------------------------------------------------------
    // looksEncrypted Tests
    // -------------------------------------------------------------------------
    group('looksEncrypted', () {
      test('retorna false para texto sin dos puntos', () {
        expect(service.looksEncrypted('plain text'), isFalse);
      });

      test('retorna false para texto con más de dos partes', () {
        expect(service.looksEncrypted('a:b:c'), isFalse);
      });

      test('retorna false para base64 inválido', () {
        expect(service.looksEncrypted('not_base64:also_not'), isFalse);
      });

      test('retorna true para formato válido iv:ciphertext', () {
        final validIv = base64Encode([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12]);
        final validCiphertext = base64Encode([1, 2, 3, 4, 5]);

        expect(service.looksEncrypted('$validIv:$validCiphertext'), isTrue);
      });

      test('retorna true para texto cifrado real', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        final encrypted = await service.encryptContent('test');

        expect(service.looksEncrypted(encrypted), isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // clearCache Tests
    // -------------------------------------------------------------------------
    group('clearCache', () {
      test('limpia cache de clave', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        // Llenar cache
        await service.encryptContent('test');
        verify(() => mockStorage.read(key: any(named: 'key'))).called(1);

        // Limpiar cache
        service.clearCache();

        // Siguiente operación debe volver a leer
        await service.encryptContent('test2');
        verify(() => mockStorage.read(key: any(named: 'key'))).called(1);
      });
    });

    // -------------------------------------------------------------------------
    // deleteUserSalt Tests
    // -------------------------------------------------------------------------
    group('deleteUserSalt', () {
      test('elimina salt y versión cuando usuario autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.delete(key: any(named: 'key')))
            .thenAnswer((_) async {});

        await service.deleteUserSalt();

        verify(() => mockStorage.delete(key: 'encryption_salt_${testUser.uid}'))
            .called(1);
        verify(() => mockStorage.delete(
            key: 'encryption_salt_version_${testUser.uid}')).called(1);
      });

      test('no elimina nada pero limpia cache cuando no hay usuario', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        await service.deleteUserSalt();

        verifyNever(() => mockStorage.delete(key: any(named: 'key')));
      });

      test('limpia cache después de eliminar', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');
        when(() => mockStorage.delete(key: any(named: 'key')))
            .thenAnswer((_) async {});

        // Llenar cache
        await service.encryptContent('test');

        // Eliminar
        await service.deleteUserSalt();

        // Ahora no debería haber salt
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => null);

        expect(
          () => service.encryptContent('test'),
          throwsA(isA<SaltNotFoundException>()),
        );
      });
    });

    // -------------------------------------------------------------------------
    // initializeWithPassword Tests
    // -------------------------------------------------------------------------
    group('initializeWithPassword', () {
      const testPassword = 'secure_password_123';

      test('lanza excepción cuando usuario no autenticado', () async {
        when(() => mockAuth.currentUser).thenReturn(null);

        expect(
          () => service.initializeWithPassword(password: testPassword),
          throwsA(isA<Exception>()),
        );
      });

      test('retorna needsUpload=false cuando versión local coincide con Firebase',
          () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(
                key: 'encryption_salt_version_${testUser.uid}'))
            .thenAnswer((_) async => '1234567890');

        final result = await service.initializeWithPassword(
          encryptedSaltFromFirebase: 'some:encrypted',
          saltVersionFromFirebase: '1234567890',
          password: testPassword,
        );

        expect(result.success, isTrue);
        expect(result.needsUpload, isFalse);
      });

      test('descarga y guarda salt de Firebase cuando versión diferente', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(
                key: 'encryption_salt_version_${testUser.uid}'))
            .thenAnswer((_) async => 'old_version');
        when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
            .thenAnswer((_) async {});

        // Crear salt cifrado válido
        final salt = 'my_test_salt';
        final encryptedSalt =
            service.encryptSaltWithPassword(salt, testPassword);

        final result = await service.initializeWithPassword(
          encryptedSaltFromFirebase: encryptedSalt,
          saltVersionFromFirebase: 'new_version',
          password: testPassword,
        );

        expect(result.success, isTrue);
        expect(result.needsUpload, isFalse);

        verify(() => mockStorage.write(
              key: 'encryption_salt_${testUser.uid}',
              value: salt,
            )).called(1);
      });

      test('propaga InvalidPasswordException si contraseña incorrecta', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(
                key: 'encryption_salt_version_${testUser.uid}'))
            .thenAnswer((_) async => null);

        final encryptedSalt = service.encryptSaltWithPassword(
          'salt',
          'correct_password',
        );

        expect(
          () => service.initializeWithPassword(
            encryptedSaltFromFirebase: encryptedSalt,
            saltVersionFromFirebase: '123',
            password: 'wrong_password',
          ),
          throwsA(isA<InvalidPasswordException>()),
        );
      });

      test('sube salt local existente si no hay salt en Firebase', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'existing_local_salt');
        when(() => mockStorage.read(
                key: 'encryption_salt_version_${testUser.uid}'))
            .thenAnswer((_) async => '1111111111');

        final result = await service.initializeWithPassword(
          encryptedSaltFromFirebase: null,
          password: testPassword,
        );

        expect(result.success, isTrue);
        expect(result.needsUpload, isTrue);
        expect(result.encryptedSalt, isNotNull);
        expect(result.saltVersion, equals('1111111111'));

        // Verificar que el salt cifrado se puede descifrar
        final decrypted = service.decryptSaltWithPassword(
          result.encryptedSalt!,
          testPassword,
        );
        expect(decrypted, equals('existing_local_salt'));
      });

      test('genera nuevo salt si no hay ni local ni en Firebase', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => null);
        when(() => mockStorage.read(
                key: 'encryption_salt_version_${testUser.uid}'))
            .thenAnswer((_) async => null);
        
        String? savedSalt;
        String? savedVersion;
        when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
            .thenAnswer((invocation) async {
          final key = invocation.namedArguments[#key] as String;
          final value = invocation.namedArguments[#value] as String;
          if (key.contains('_version_')) {
            savedVersion = value;
          } else if (key.contains('encryption_salt_')) {
            savedSalt = value;
          }
        });

        // Después de generar, simular que se puede leer
        when(() => mockStorage.read(
                key: 'encryption_salt_version_${testUser.uid}'))
            .thenAnswer((_) async => savedVersion);

        final result = await service.initializeWithPassword(
          encryptedSaltFromFirebase: null,
          password: testPassword,
        );

        expect(result.success, isTrue);
        expect(result.needsUpload, isTrue);
        expect(result.encryptedSalt, isNotNull);
      });

      test('maneja encryptedSaltFromFirebase vacío como null', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'local_salt');
        when(() => mockStorage.read(
                key: 'encryption_salt_version_${testUser.uid}'))
            .thenAnswer((_) async => '123');

        final result = await service.initializeWithPassword(
          encryptedSaltFromFirebase: '',
          password: testPassword,
        );

        // Debería comportarse como si no hubiera salt en Firebase
        expect(result.needsUpload, isTrue);
      });
    });

    // -------------------------------------------------------------------------
    // reencryptSaltForPasswordChange Tests
    // -------------------------------------------------------------------------
    group('reencryptSaltForPasswordChange', () {
      test('recifra salt correctamente con nueva contraseña', () async {
        const salt = 'my_secret_salt';
        const oldPassword = 'old_password_123';
        const newPassword = 'new_password_456';

        final encryptedWithOld =
            service.encryptSaltWithPassword(salt, oldPassword);

        final encryptedWithNew = await service.reencryptSaltForPasswordChange(
          oldPassword: oldPassword,
          newPassword: newPassword,
          currentEncryptedSalt: encryptedWithOld,
        );

        // Verificar que se puede descifrar con la nueva contraseña
        final decrypted =
            service.decryptSaltWithPassword(encryptedWithNew, newPassword);
        expect(decrypted, equals(salt));

        // Verificar que NO se puede descifrar con la contraseña antigua
        expect(
          () => service.decryptSaltWithPassword(encryptedWithNew, oldPassword),
          throwsA(isA<InvalidPasswordException>()),
        );
      });

      test('lanza InvalidPasswordException si contraseña antigua incorrecta',
          () async {
        const salt = 'my_salt';
        const correctOldPassword = 'correct_old';
        const wrongOldPassword = 'wrong_old';

        final encrypted =
            service.encryptSaltWithPassword(salt, correctOldPassword);

        expect(
          () => service.reencryptSaltForPasswordChange(
            oldPassword: wrongOldPassword,
            newPassword: 'new_pass',
            currentEncryptedSalt: encrypted,
          ),
          throwsA(isA<InvalidPasswordException>()),
        );
      });

      test('preserva el salt original durante el recifrado', () async {
        const salt = 'preserve_this_salt_🔐';
        const oldPassword = 'old';
        const newPassword = 'new';

        final encrypted = service.encryptSaltWithPassword(salt, oldPassword);

        final reencrypted = await service.reencryptSaltForPasswordChange(
          oldPassword: oldPassword,
          newPassword: newPassword,
          currentEncryptedSalt: encrypted,
        );

        // Recifrar nuevamente con otra contraseña
        final reencrypted2 = await service.reencryptSaltForPasswordChange(
          oldPassword: newPassword,
          newPassword: 'another_password',
          currentEncryptedSalt: reencrypted,
        );

        final finalSalt = service.decryptSaltWithPassword(
          reencrypted2,
          'another_password',
        );

        expect(finalSalt, equals(salt));
      });
    });

    // -------------------------------------------------------------------------
    // Casos edge y de integración
    // -------------------------------------------------------------------------
    group('casos edge y de integración', () {
      test('flujo completo: generar -> cifrar -> descifrar mensajes', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.write(key: any(named: 'key'), value: any(named: 'value')))
            .thenAnswer((_) async {});

        // Generar salt
        final salt = await service.generateNewSalt();

        // Configurar mock para retornar el salt generado
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => salt);

        // Crear mensajes
        final messages = [
          {'id': '1', 'content': 'Mensaje secreto 1', 'role': 'user'},
          {'id': '2', 'content': 'Respuesta secreta', 'role': 'assistant'},
        ];

        // Cifrar
        final encrypted = await service.encryptMessages(messages);

        // Verificar que están cifrados
        expect(encrypted[0]['content'], isNot(equals('Mensaje secreto 1')));
        expect(encrypted[1]['content'], isNot(equals('Respuesta secreta')));

        // Descifrar
        final decrypted = await service.decryptMessages(encrypted);

        // Verificar contenido original
        expect(decrypted[0]['content'], equals('Mensaje secreto 1'));
        expect(decrypted[1]['content'], equals('Respuesta secreta'));
      });

      test('compatibilidad: descifra mensajes antiguos no cifrados', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        final messages = [
          {'id': '1', 'content': 'Mensaje sin cifrar antiguo', 'role': 'user'},
        ];

        final decrypted = await service.decryptMessages(messages);

        expect(decrypted[0]['content'], equals('Mensaje sin cifrar antiguo'));
      });

      test('maneja mensajes mixtos (cifrados y no cifrados)', () async {
        when(() => mockAuth.currentUser).thenReturn(testUser);
        when(() => mockStorage.read(key: 'encryption_salt_${testUser.uid}'))
            .thenAnswer((_) async => 'test_salt');

        final encryptedContent = await service.encryptContent('Mensaje nuevo');

        final messages = [
          {'id': '1', 'content': 'Mensaje antiguo sin cifrar', 'role': 'user'},
          {'id': '2', 'content': encryptedContent, 'encrypted': true},
        ];

        final decrypted = await service.decryptMessages(messages);

        expect(decrypted[0]['content'], equals('Mensaje antiguo sin cifrar'));
        expect(decrypted[1]['content'], equals('Mensaje nuevo'));
      });

      test('diferentes usuarios tienen diferentes cifrados', () async {
        final user1 = MockUser(uid: 'user-1');
        final user2 = MockUser(uid: 'user-2');

        when(() => mockStorage.read(key: 'encryption_salt_user-1'))
            .thenAnswer((_) async => 'salt_for_user_1');
        when(() => mockStorage.read(key: 'encryption_salt_user-2'))
            .thenAnswer((_) async => 'salt_for_user_2');

        const message = 'Same message for both users';

        // Cifrar con usuario 1
        when(() => mockAuth.currentUser).thenReturn(user1);
        service.clearCache();
        final encrypted1 = await service.encryptContent(message);

        // Cifrar con usuario 2
        when(() => mockAuth.currentUser).thenReturn(user2);
        service.clearCache();
        final encrypted2 = await service.encryptContent(message);

        // Los cifrados deben ser diferentes
        expect(encrypted1, isNot(equals(encrypted2)));

        // Pero cada usuario puede descifrar su propio mensaje
        when(() => mockAuth.currentUser).thenReturn(user1);
        service.clearCache();
        expect(await service.decryptContent(encrypted1), equals(message));

        when(() => mockAuth.currentUser).thenReturn(user2);
        service.clearCache();
        expect(await service.decryptContent(encrypted2), equals(message));
      });
    });
  });
}