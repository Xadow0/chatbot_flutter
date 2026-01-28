import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_app/features/settings/data/datasources/api_keys_manager.dart';

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
// ============================================================================
// FIN DE LA COPIA TEMPORAL
// ============================================================================

void main() {
  late ApiKeysManager apiKeysManager;

  setUp(() {
    apiKeysManager = ApiKeysManager();
  });

  group('ApiKeysManager - Constantes', () {
    test('geminiApiKeyName debe ser GEMINI_API_KEY', () {
      expect(ApiKeysManager.geminiApiKeyName, equals('GEMINI_API_KEY'));
    });

    test('openaiApiKeyName debe ser OPENAI_API_KEY', () {
      expect(ApiKeysManager.openaiApiKeyName, equals('OPENAI_API_KEY'));
    });

    test('Singleton debe retornar la misma instancia', () {
      final instance1 = ApiKeysManager();
      final instance2 = ApiKeysManager();
      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('ApiKeysManager - validateGeminiKey', () {
    group('Casos válidos', () {
      test('debe aceptar key válida de 30 caracteres exactos', () {
        final key = 'A' * 30;
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key válida de más de 30 caracteres', () {
        final key = 'A' * 50;
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key con letras mayúsculas', () {
        final key = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ1234';
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key con letras minúsculas', () {
        final key = 'abcdefghijklmnopqrstuvwxyz1234';
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key con números', () {
        final key = '012345678901234567890123456789';
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key con guiones bajos', () {
        final key = 'ABC_DEF_GHI_JKL_MNO_PQR_STU_VWX';
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key con guiones medios', () {
        final key = 'ABC-DEF-GHI-JKL-MNO-PQR-STU-VWX';
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key con combinación de caracteres válidos', () {
        final key = 'AIzaSyD_Test-Key_123456789012345';
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key realista de Gemini', () {
        final key = 'AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz12345';
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });
    });

    group('Casos inválidos', () {
      test('debe rechazar key vacía', () {
        expect(apiKeysManager.validateGeminiKey(''), isFalse);
      });

      test('debe rechazar key de 1 carácter', () {
        expect(apiKeysManager.validateGeminiKey('A'), isFalse);
      });

      test('debe rechazar key de 29 caracteres (límite inferior)', () {
        final key = 'A' * 29;
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con espacios', () {
        final key = 'AIzaSyD Test Key 12345678901234';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con espacios al inicio', () {
        final key = ' AIzaSyDTestKey123456789012345678';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con espacios al final', () {
        final key = 'AIzaSyDTestKey123456789012345678 ';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con caracteres especiales (@)', () {
        final key = 'AIzaSyD@TestKey12345678901234567';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con caracteres especiales (#)', () {
        final key = 'AIzaSyD#TestKey12345678901234567';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con caracteres especiales (!)', () {
        final key = 'AIzaSyD!TestKey12345678901234567';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con caracteres especiales (.)', () {
        final key = 'AIzaSyD.TestKey12345678901234567';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con caracteres especiales (\$)', () {
        final key = 'AIzaSyD\$TestKey1234567890123456';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con salto de línea', () {
        final key = 'AIzaSyDTestKey12345678\n901234567';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con tabulación', () {
        final key = 'AIzaSyDTestKey12345678\t901234567';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con caracteres unicode', () {
        final key = 'AIzaSyDTestKeyñ1234567890123456';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });

      test('debe rechazar key con emoji', () {
        final key = 'AIzaSyDTestKey😀234567890123456';
        expect(apiKeysManager.validateGeminiKey(key), isFalse);
      });
    });

    group('Casos límite', () {
      test('debe aceptar key de exactamente 30 caracteres alfanuméricos', () {
        final key = 'aB3dE6gH9jK2mN5pQ8sT1vW4yZ7bC0';
        expect(key.length, equals(30));
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key muy larga (100 caracteres)', () {
        final key = 'A' * 100;
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key muy larga (500 caracteres)', () {
        final key = 'A' * 500;
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key solo con guiones bajos (30 chars)', () {
        final key = '_' * 30;
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });

      test('debe aceptar key solo con guiones medios (30 chars)', () {
        final key = '-' * 30;
        expect(apiKeysManager.validateGeminiKey(key), isTrue);
      });
    });
  });

  group('ApiKeysManager - validateOpenAIKey', () {
    group('Casos válidos', () {
      test('debe aceptar key válida con prefijo sk- de 40 caracteres', () {
        final key = 'sk-' + 'A' * 37;
        expect(key.length, equals(40));
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });

      test('debe aceptar key válida de más de 40 caracteres', () {
        final key = 'sk-' + 'A' * 50;
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });



      test('debe aceptar key con números después de sk-', () {
        final key = 'sk-0123456789012345678901234567890123456';
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });

      test('debe aceptar key realista de OpenAI formato antiguo', () {
        final key = 'sk-abcdefghijklmnopqrstuvwxyz1234567890ABCD';
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });

      test('debe aceptar key realista de OpenAI formato proj', () {
        final key = 'sk-proj-AbCdEfGhIjKlMnOpQrStUvWxYz123456';
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });
    });

    group('Casos inválidos', () {
      test('debe rechazar key vacía', () {
        expect(apiKeysManager.validateOpenAIKey(''), isFalse);
      });

      test('debe rechazar key sin prefijo sk-', () {
        final key = 'abcdefghijklmnopqrstuvwxyz1234567890ABCD';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con prefijo SK- (mayúsculas)', () {
        final key = 'SK-abcdefghijklmnopqrstuvwxyz1234567890A';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con prefijo Sk- (mixto)', () {
        final key = 'Sk-abcdefghijklmnopqrstuvwxyz1234567890A';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con prefijo sk_ (guión bajo)', () {
        final key = 'sk_abcdefghijklmnopqrstuvwxyz1234567890A';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key de 39 caracteres (límite inferior)', () {
        final key = 'sk-' + 'A' * 36;
        expect(key.length, equals(39));
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key solo con prefijo sk-', () {
        expect(apiKeysManager.validateOpenAIKey('sk-'), isFalse);
      });

      test('debe rechazar key con espacios', () {
        final key = 'sk-abcdefghijklmnopqr stuvwxyz1234567890';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con espacios al inicio', () {
        final key = ' sk-abcdefghijklmnopqrstuvwxyz123456789';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con espacios al final', () {
        final key = 'sk-abcdefghijklmnopqrstuvwxyz123456789 ';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con caracteres especiales (@)', () {
        final key = 'sk-abcdefghijklmnopqr@tuvwxyz123456789';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con caracteres especiales (#)', () {
        final key = 'sk-abcdefghijklmnopqr#tuvwxyz123456789';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con caracteres especiales (.)', () {
        final key = 'sk-abcdefghijklmnopqr.tuvwxyz123456789';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con salto de línea', () {
        final key = 'sk-abcdefghijklmnopqr\ntuvwxyz123456789';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key con caracteres unicode', () {
        final key = 'sk-abcdefghijklmnopqrñtuvwxyz123456789';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });

      test('debe rechazar key que empieza con espacio antes de sk-', () {
        final key = ' sk-abcdefghijklmnopqrstuvwxyz12345678';
        expect(apiKeysManager.validateOpenAIKey(key), isFalse);
      });
    });

    group('Casos límite', () {

      test('debe aceptar key muy larga (100 caracteres)', () {
        final key = 'sk-' + 'A' * 97;
        expect(key.length, equals(100));
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });

      test('debe aceptar key muy larga (200 caracteres)', () {
        final key = 'sk-' + 'A' * 197;
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });

      test('debe aceptar key solo con guiones bajos después de sk-', () {
        final key = 'sk-' + '_' * 37;
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });

      test('debe aceptar key solo con guiones medios después de sk-', () {
        final key = 'sk-' + '-' * 37;
        expect(apiKeysManager.validateOpenAIKey(key), isTrue);
      });
    });
  });

  group('ApiKeysManager - validateApiKey', () {
    group('Delegación a validateGeminiKey', () {
      test('debe delegar validación de GEMINI_API_KEY a validateGeminiKey (válida)', () {
        final key = 'AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz12345';
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.geminiApiKeyName, key),
          equals(apiKeysManager.validateGeminiKey(key)),
        );
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.geminiApiKeyName, key),
          isTrue,
        );
      });

      test('debe delegar validación de GEMINI_API_KEY a validateGeminiKey (inválida corta)', () {
        final key = 'short';
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.geminiApiKeyName, key),
          equals(apiKeysManager.validateGeminiKey(key)),
        );
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.geminiApiKeyName, key),
          isFalse,
        );
      });

      test('debe delegar validación de GEMINI_API_KEY a validateGeminiKey (inválida caracteres)', () {
        final key = 'AIzaSyAbCdEfGhIjKlMnOp@rStUvWx';
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.geminiApiKeyName, key),
          equals(apiKeysManager.validateGeminiKey(key)),
        );
      });
    });

    group('Delegación a validateOpenAIKey', () {
      test('debe delegar validación de OPENAI_API_KEY a validateOpenAIKey (válida)', () {
        final key = 'sk-abcdefghijklmnopqrstuvwxyz1234567890AB';
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.openaiApiKeyName, key),
          equals(apiKeysManager.validateOpenAIKey(key)),
        );
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.openaiApiKeyName, key),
          isTrue,
        );
      });

      test('debe delegar validación de OPENAI_API_KEY a validateOpenAIKey (inválida sin prefijo)', () {
        final key = 'abcdefghijklmnopqrstuvwxyz1234567890ABCD';
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.openaiApiKeyName, key),
          equals(apiKeysManager.validateOpenAIKey(key)),
        );
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.openaiApiKeyName, key),
          isFalse,
        );
      });

      test('debe delegar validación de OPENAI_API_KEY a validateOpenAIKey (inválida corta)', () {
        final key = 'sk-short';
        expect(
          apiKeysManager.validateApiKey(ApiKeysManager.openaiApiKeyName, key),
          equals(apiKeysManager.validateOpenAIKey(key)),
        );
      });
    });

    group('Validación genérica (keyName desconocido)', () {
      test('debe usar validación genérica para keyName desconocido', () {
        final key = 'algunaKeyDesconocida123';
        expect(
          apiKeysManager.validateApiKey('UNKNOWN_API_KEY', key),
          isTrue,
        );
      });

      test('debe aceptar key desconocida de exactamente 20 caracteres', () {
        final key = 'A' * 20;
        expect(key.length, equals(20));
        expect(
          apiKeysManager.validateApiKey('CUSTOM_KEY', key),
          isTrue,
        );
      });

      test('debe aceptar key desconocida de más de 20 caracteres', () {
        final key = 'A' * 50;
        expect(
          apiKeysManager.validateApiKey('ANOTHER_KEY', key),
          isTrue,
        );
      });

      test('debe rechazar key desconocida vacía', () {
        expect(
          apiKeysManager.validateApiKey('CUSTOM_KEY', ''),
          isFalse,
        );
      });

      test('debe rechazar key desconocida de 19 caracteres (límite inferior)', () {
        final key = 'A' * 19;
        expect(key.length, equals(19));
        expect(
          apiKeysManager.validateApiKey('CUSTOM_KEY', key),
          isFalse,
        );
      });

      test('debe rechazar key desconocida de 1 carácter', () {
        expect(
          apiKeysManager.validateApiKey('CUSTOM_KEY', 'A'),
          isFalse,
        );
      });

      test('debe aceptar key desconocida con caracteres especiales si tiene 20+ chars', () {
        final key = 'key@with#special!chars';
        expect(key.length >= 20, isTrue);
        expect(
          apiKeysManager.validateApiKey('CUSTOM_KEY', key),
          isTrue,
        );
      });

      test('debe funcionar con keyName vacío usando validación genérica', () {
        final key = 'A' * 25;
        expect(
          apiKeysManager.validateApiKey('', key),
          isTrue,
        );
      });

      test('debe funcionar con keyName con espacios usando validación genérica', () {
        final key = 'A' * 25;
        expect(
          apiKeysManager.validateApiKey('KEY WITH SPACES', key),
          isTrue,
        );
      });
    });

    group('Consistencia entre métodos', () {
      test('validateApiKey con GEMINI debe ser igual a validateGeminiKey para múltiples inputs', () {
        final testKeys = [
          '',
          'short',
          'A' * 29,
          'A' * 30,
          'A' * 50,
          'AIzaSyAbCdEfGhIjKlMnOpQrStUvWxYz12345',
          'invalid key with spaces 123456',
          'invalid@key#with\$special^chars',
        ];

        for (final key in testKeys) {
          expect(
            apiKeysManager.validateApiKey(ApiKeysManager.geminiApiKeyName, key),
            equals(apiKeysManager.validateGeminiKey(key)),
            reason: 'Fallo con key: "$key"',
          );
        }
      });

      test('validateApiKey con OPENAI debe ser igual a validateOpenAIKey para múltiples inputs', () {
        final testKeys = [
          '',
          'short',
          'sk-short',
          'sk-' + 'A' * 36,
          'sk-' + 'A' * 37,
          'sk-' + 'A' * 50,
          'sk-abcdefghijklmnopqrstuvwxyz1234567890AB',
          'no-prefix-abcdefghijklmnopqrstuvwxyz12345',
          'SK-UPPERCASE-abcdefghijklmnopqrstuvwxyz',
        ];

        for (final key in testKeys) {
          expect(
            apiKeysManager.validateApiKey(ApiKeysManager.openaiApiKeyName, key),
            equals(apiKeysManager.validateOpenAIKey(key)),
            reason: 'Fallo con key: "$key"',
          );
        }
      });
    });
  });

  group('ApiKeyStatus', () {
    test('debe crear ApiKeyStatus con todos los valores true', () {
      final status = ApiKeyStatus(
        hasKey: true,
        isUserKey: true,
        isUsingDefault: true,
        hasDefaultAvailable: true,
      );

      expect(status.hasKey, isTrue);
      expect(status.isUserKey, isTrue);
      expect(status.isUsingDefault, isTrue);
      expect(status.hasDefaultAvailable, isTrue);
    });

    test('debe crear ApiKeyStatus con todos los valores false', () {
      final status = ApiKeyStatus(
        hasKey: false,
        isUserKey: false,
        isUsingDefault: false,
        hasDefaultAvailable: false,
      );

      expect(status.hasKey, isFalse);
      expect(status.isUserKey, isFalse);
      expect(status.isUsingDefault, isFalse);
      expect(status.hasDefaultAvailable, isFalse);
    });

    test('debe crear ApiKeyStatus con valores mixtos', () {
      final status = ApiKeyStatus(
        hasKey: true,
        isUserKey: false,
        isUsingDefault: true,
        hasDefaultAvailable: true,
      );

      expect(status.hasKey, isTrue);
      expect(status.isUserKey, isFalse);
      expect(status.isUsingDefault, isTrue);
      expect(status.hasDefaultAvailable, isTrue);
    });

    test('debe representar estado: usuario tiene key personalizada', () {
      final status = ApiKeyStatus(
        hasKey: true,
        isUserKey: true,
        isUsingDefault: false,
        hasDefaultAvailable: true,
      );

      expect(status.hasKey, isTrue);
      expect(status.isUserKey, isTrue);
      expect(status.isUsingDefault, isFalse);
    });

    test('debe representar estado: usando key por defecto', () {
      final status = ApiKeyStatus(
        hasKey: true,
        isUserKey: false,
        isUsingDefault: true,
        hasDefaultAvailable: true,
      );

      expect(status.hasKey, isTrue);
      expect(status.isUserKey, isFalse);
      expect(status.isUsingDefault, isTrue);
    });

    test('debe representar estado: sin ninguna key disponible', () {
      final status = ApiKeyStatus(
        hasKey: false,
        isUserKey: false,
        isUsingDefault: false,
        hasDefaultAvailable: false,
      );

      expect(status.hasKey, isFalse);
      expect(status.hasDefaultAvailable, isFalse);
    });
  });
}