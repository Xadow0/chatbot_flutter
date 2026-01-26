import 'package:flutter_test/flutter_test.dart';

// =============================================================================
// STUB DE DATOS DE IDIOMAS
// =============================================================================

class LanguagesData {
  static const List<Map<String, Object>> languages = [
    {
      'spanish': 'Inglés',
      'english': 'English',
      'native': 'English',
      'iso639_1': 'en',
      'iso639_3': 'eng',
      'aliases': <String>['ingles'],
    },
    {
      'spanish': 'Español',
      'english': 'Spanish',
      'native': 'Español',
      'iso639_1': 'es',
      'iso639_3': 'spa',
      'aliases': <String>['espanol', 'castellano'],
    },
    {
      'spanish': 'Francés',
      'english': 'French',
      'native': 'Français',
      'iso639_1': 'fr',
      'iso639_3': 'fra',
      'aliases': <String>['frances'],
    },
    {
      'spanish': 'Alemán',
      'english': 'German',
      'native': 'Deutsch',
      'iso639_1': 'de',
      'iso639_3': 'deu',
      'aliases': <String>['aleman'],
    },
    {
      'spanish': 'Italiano',
      'english': 'Italian',
      'native': 'Italiano',
      'iso639_1': 'it',
      'iso639_3': 'ita',
      'aliases': <String>[],
    },
    {
      'spanish': 'Portugués',
      'english': 'Portuguese',
      'native': 'Português',
      'iso639_1': 'pt',
      'iso639_3': 'por',
      'aliases': <String>['portugues'],
    },
    {
      'spanish': 'Chino',
      'english': 'Chinese',
      'native': '中文',
      'iso639_1': 'zh',
      'iso639_3': 'zho',
      'aliases': <String>['mandarin'],
    },
    {
      'spanish': 'Japonés',
      'english': 'Japanese',
      'native': '日本語',
      'iso639_1': 'ja',
      'iso639_3': 'jpn',
      'aliases': <String>['japones'],
    },
    {
      'spanish': 'Coreano',
      'english': 'Korean',
      'native': '한국어',
      'iso639_1': 'ko',
      'iso639_3': 'kor',
      'aliases': <String>[],
    },
    {
      'spanish': 'Ruso',
      'english': 'Russian',
      'native': 'Русский',
      'iso639_1': 'ru',
      'iso639_3': 'rus',
      'aliases': <String>[],
    },
    {
      'spanish': 'Árabe',
      'english': 'Arabic',
      'native': 'العربية',
      'iso639_1': 'ar',
      'iso639_3': 'ara',
      'aliases': <String>['arabe'],
    },
    {
      'spanish': 'Catalán',
      'english': 'Catalan',
      'native': 'Català',
      'iso639_1': 'ca',
      'iso639_3': 'cat',
      'aliases': <String>['catalan'],
    },
  ];
}

// =============================================================================
// CÓDIGO BAJO PRUEBA
// =============================================================================

class LanguageDetectionResult {
  final String languageName;
  final String remainingText;
  final bool wasDetected;

  LanguageDetectionResult({
    required this.languageName,
    required this.remainingText,
    required this.wasDetected,
  });

  factory LanguageDetectionResult.defaultLanguage(String text,
      {String defaultLang = 'inglés'}) {
    return LanguageDetectionResult(
      languageName: defaultLang,
      remainingText: text,
      wasDetected: false,
    );
  }

  factory LanguageDetectionResult.detected(String language, String text) {
    return LanguageDetectionResult(
      languageName: language,
      remainingText: text,
      wasDetected: true,
    );
  }
}

class LanguageDetector {
  static LanguageDetectionResult detectLanguage(
    String content, {
    String defaultLanguage = 'inglés',
  }) {
    if (content.trim().isEmpty) {
      return LanguageDetectionResult.defaultLanguage(content,
          defaultLang: defaultLanguage);
    }

    final lowerContent = content.toLowerCase();

    for (final langData in LanguagesData.languages) {
      final standardVariations = [
        langData['spanish'],
        langData['english'],
        langData['native'],
        langData['iso639_1'],
        langData['iso639_3'],
      ].whereType<String>().toList();

      final aliases = (langData['aliases'] as List<String>?) ?? [];

      final allVariations = [...standardVariations, ...aliases]
          .where((s) => s.isNotEmpty)
          .map((s) => s.toLowerCase())
          .toList();

      allVariations.sort((a, b) => b.length.compareTo(a.length));

      for (final variation in allVariations) {
        if (lowerContent.startsWith(variation)) {
          final isWordBoundary = lowerContent.length == variation.length ||
              lowerContent[variation.length] == ' ';

          if (isWordBoundary) {
            final languageName = langData['spanish'] as String;
            final remainingText = content.substring(variation.length).trim();

            return LanguageDetectionResult.detected(languageName, remainingText);
          }
        }
      }
    }

    return LanguageDetectionResult.defaultLanguage(content,
        defaultLang: defaultLanguage);
  }

  static Map<String, Object>? getLanguageInfo(String languageName) {
    final searchTerm = languageName.toLowerCase().trim();

    for (final langData in LanguagesData.languages) {
      final standardVariations = [
        langData['spanish'],
        langData['english'],
        langData['native'],
        langData['iso639_1'],
        langData['iso639_3'],
      ].whereType<String>().map((s) => s.toLowerCase()).toList();

      final aliases = (langData['aliases'] as List<String>?)
              ?.map((s) => s.toLowerCase())
              .toList() ??
          [];

      final allVariations = [...standardVariations, ...aliases];

      if (allVariations.contains(searchTerm)) {
        return langData;
      }
    }

    return null;
  }

  static List<String> getSupportedLanguages() {
    return LanguagesData.languages
        .map((lang) => lang['spanish'] as String)
        .toList();
  }

  static String? getLanguageCode(String languageName) {
    final info = getLanguageInfo(languageName);
    return info?['iso639_1'] as String?;
  }

  static bool isLanguageSupported(String languageName) {
    return getLanguageInfo(languageName) != null;
  }
}

// =============================================================================
// TESTS
// =============================================================================

void main() {
  // ---------------------------------------------------------------------------
  // LanguageDetectionResult Tests
  // ---------------------------------------------------------------------------
  group('LanguageDetectionResult', () {
    group('constructor', () {
      test('crea instancia con todos los parámetros', () {
        final result = LanguageDetectionResult(
          languageName: 'Francés',
          remainingText: 'hello world',
          wasDetected: true,
        );

        expect(result.languageName, equals('Francés'));
        expect(result.remainingText, equals('hello world'));
        expect(result.wasDetected, isTrue);
      });

      test('permite valores vacíos', () {
        final result = LanguageDetectionResult(
          languageName: '',
          remainingText: '',
          wasDetected: false,
        );

        expect(result.languageName, isEmpty);
        expect(result.remainingText, isEmpty);
        expect(result.wasDetected, isFalse);
      });
    });

    group('factory defaultLanguage', () {
      test('crea resultado con idioma por defecto inglés', () {
        final result = LanguageDetectionResult.defaultLanguage('some text');

        expect(result.languageName, equals('inglés'));
        expect(result.remainingText, equals('some text'));
        expect(result.wasDetected, isFalse);
      });

      test('permite especificar idioma por defecto personalizado', () {
        final result = LanguageDetectionResult.defaultLanguage(
          'some text',
          defaultLang: 'español',
        );

        expect(result.languageName, equals('español'));
        expect(result.remainingText, equals('some text'));
        expect(result.wasDetected, isFalse);
      });

      test('preserva texto original sin modificar', () {
        const originalText = '  texto con espacios  ';
        final result = LanguageDetectionResult.defaultLanguage(originalText);

        expect(result.remainingText, equals(originalText));
      });
    });

    group('factory detected', () {
      test('crea resultado con idioma detectado', () {
        final result = LanguageDetectionResult.detected('Alemán', 'guten tag');

        expect(result.languageName, equals('Alemán'));
        expect(result.remainingText, equals('guten tag'));
        expect(result.wasDetected, isTrue);
      });

      test('permite texto restante vacío', () {
        final result = LanguageDetectionResult.detected('Italiano', '');

        expect(result.languageName, equals('Italiano'));
        expect(result.remainingText, isEmpty);
        expect(result.wasDetected, isTrue);
      });
    });
  });

  // ---------------------------------------------------------------------------
  // LanguageDetector.detectLanguage Tests
  // ---------------------------------------------------------------------------
  group('LanguageDetector.detectLanguage', () {
    group('detección básica', () {
      test('detecta idioma en español al inicio', () {
        final result = LanguageDetector.detectLanguage('francés hello world');

        expect(result.languageName, equals('Francés'));
        expect(result.remainingText, equals('hello world'));
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma en inglés al inicio', () {
        final result = LanguageDetector.detectLanguage('french hello world');

        expect(result.languageName, equals('Francés'));
        expect(result.remainingText, equals('hello world'));
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma en nombre nativo', () {
        final result = LanguageDetector.detectLanguage('Deutsch hallo welt');

        expect(result.languageName, equals('Alemán'));
        expect(result.remainingText, equals('hallo welt'));
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma por código ISO 639-1', () {
        final result = LanguageDetector.detectLanguage('fr bonjour monde');

        expect(result.languageName, equals('Francés'));
        expect(result.remainingText, equals('bonjour monde'));
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma por código ISO 639-3', () {
        final result = LanguageDetector.detectLanguage('fra bonjour');

        expect(result.languageName, equals('Francés'));
        expect(result.remainingText, equals('bonjour'));
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma por alias', () {
        final result = LanguageDetector.detectLanguage('castellano hola mundo');

        expect(result.languageName, equals('Español'));
        expect(result.remainingText, equals('hola mundo'));
        expect(result.wasDetected, isTrue);
      });
    });

    group('case insensitivity', () {
      test('detecta idioma en mayúsculas', () {
        final result = LanguageDetector.detectLanguage('FRANCÉS hello');

        expect(result.languageName, equals('Francés'));
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma en minúsculas', () {
        final result = LanguageDetector.detectLanguage('francés hello');

        expect(result.languageName, equals('Francés'));
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma en mixed case', () {
        final result = LanguageDetector.detectLanguage('FrAnCéS hello');

        expect(result.languageName, equals('Francés'));
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma inglés en mayúsculas', () {
        final result = LanguageDetector.detectLanguage('GERMAN hallo');

        expect(result.languageName, equals('Alemán'));
        expect(result.wasDetected, isTrue);
      });
    });

    group('boundary detection', () {
      test('no detecta idioma si no hay límite de palabra', () {
        // "frances" es un alias pero "francesca" no debería coincidir
        final result = LanguageDetector.detectLanguage('francesca is a name');

        expect(result.wasDetected, isFalse);
        expect(result.remainingText, equals('francesca is a name'));
      });

      test('detecta idioma cuando es la única palabra', () {
        final result = LanguageDetector.detectLanguage('francés');

        expect(result.languageName, equals('Francés'));
        expect(result.remainingText, isEmpty);
        expect(result.wasDetected, isTrue);
      });

      test('detecta idioma seguido de espacio', () {
        final result = LanguageDetector.detectLanguage('francés texto');

        expect(result.languageName, equals('Francés'));
        expect(result.remainingText, equals('texto'));
        expect(result.wasDetected, isTrue);
      });

      test('no detecta "cat" como catalán si hay más texto pegado', () {
        final result = LanguageDetector.detectLanguage('catalog of items');

        // "cat" es código ISO pero "catalog" no tiene límite de palabra
        expect(result.wasDetected, isFalse);
      });

      test('detecta "catalán" correctamente', () {
        final result = LanguageDetector.detectLanguage('catalán hola');

        expect(result.languageName, equals('Catalán'));
        expect(result.wasDetected, isTrue);
      });
    });

    group('default language', () {
      test('retorna idioma por defecto cuando no detecta idioma', () {
        final result = LanguageDetector.detectLanguage('hello world');

        expect(result.languageName, equals('inglés'));
        expect(result.remainingText, equals('hello world'));
        expect(result.wasDetected, isFalse);
      });

      test('permite especificar idioma por defecto personalizado', () {
        final result = LanguageDetector.detectLanguage(
          'hello world',
          defaultLanguage: 'español',
        );

        expect(result.languageName, equals('español'));
        expect(result.wasDetected, isFalse);
      });

      test('usa idioma por defecto con texto vacío', () {
        final result = LanguageDetector.detectLanguage('');

        expect(result.languageName, equals('inglés'));
        expect(result.remainingText, equals(''));
        expect(result.wasDetected, isFalse);
      });

      test('usa idioma por defecto con solo espacios', () {
        final result = LanguageDetector.detectLanguage('   ');

        expect(result.languageName, equals('inglés'));
        expect(result.wasDetected, isFalse);
      });
    });

    group('remaining text', () {
      test('trim del texto restante', () {
        final result = LanguageDetector.detectLanguage('francés   mucho espacio  ');

        expect(result.remainingText, equals('mucho espacio'));
      });

      test('preserva espacios internos en texto restante', () {
        final result = LanguageDetector.detectLanguage('francés palabra1  palabra2');

        expect(result.remainingText, equals('palabra1  palabra2'));
      });

      test('texto restante vacío cuando solo hay idioma', () {
        final result = LanguageDetector.detectLanguage('italiano');

        expect(result.remainingText, isEmpty);
      });
    });

    group('idiomas específicos', () {
      test('detecta inglés', () {
        final result = LanguageDetector.detectLanguage('inglés hello');
        expect(result.languageName, equals('Inglés'));
      });

      test('detecta español', () {
        final result = LanguageDetector.detectLanguage('español hola');
        expect(result.languageName, equals('Español'));
      });

      test('detecta chino', () {
        final result = LanguageDetector.detectLanguage('chino 你好');
        expect(result.languageName, equals('Chino'));
      });

      test('detecta japonés', () {
        final result = LanguageDetector.detectLanguage('japonés こんにちは');
        expect(result.languageName, equals('Japonés'));
      });

      test('detecta coreano', () {
        final result = LanguageDetector.detectLanguage('korean 안녕하세요');
        expect(result.languageName, equals('Coreano'));
      });

      test('detecta ruso', () {
        final result = LanguageDetector.detectLanguage('russian привет');
        expect(result.languageName, equals('Ruso'));
      });

      test('detecta árabe', () {
        final result = LanguageDetector.detectLanguage('árabe مرحبا');
        expect(result.languageName, equals('Árabe'));
      });

      test('detecta portugués', () {
        final result = LanguageDetector.detectLanguage('portugués olá');
        expect(result.languageName, equals('Portugués'));
      });
    });

    group('detección con nombres nativos unicode', () {
      test('detecta chino por nombre nativo', () {
        final result = LanguageDetector.detectLanguage('中文 hello');
        expect(result.languageName, equals('Chino'));
      });

      test('detecta japonés por nombre nativo', () {
        final result = LanguageDetector.detectLanguage('日本語 hello');
        expect(result.languageName, equals('Japonés'));
      });

      test('detecta coreano por nombre nativo', () {
        final result = LanguageDetector.detectLanguage('한국어 hello');
        expect(result.languageName, equals('Coreano'));
      });

      test('detecta ruso por nombre nativo', () {
        final result = LanguageDetector.detectLanguage('Русский hello');
        expect(result.languageName, equals('Ruso'));
      });

      test('detecta árabe por nombre nativo', () {
        final result = LanguageDetector.detectLanguage('العربية hello');
        expect(result.languageName, equals('Árabe'));
      });
    });

    group('aliases', () {
      test('detecta español por alias "espanol" sin tilde', () {
        final result = LanguageDetector.detectLanguage('espanol hola');
        expect(result.languageName, equals('Español'));
      });

      test('detecta inglés por alias "ingles" sin tilde', () {
        final result = LanguageDetector.detectLanguage('ingles hello');
        expect(result.languageName, equals('Inglés'));
      });

      test('detecta francés por alias "frances" sin tilde', () {
        final result = LanguageDetector.detectLanguage('frances bonjour');
        expect(result.languageName, equals('Francés'));
      });

      test('detecta alemán por alias "aleman" sin tilde', () {
        final result = LanguageDetector.detectLanguage('aleman hallo');
        expect(result.languageName, equals('Alemán'));
      });

      test('detecta chino por alias "mandarin"', () {
        final result = LanguageDetector.detectLanguage('mandarin 你好');
        expect(result.languageName, equals('Chino'));
      });

      test('detecta árabe por alias "arabe" sin tilde', () {
        final result = LanguageDetector.detectLanguage('arabe مرحبا');
        expect(result.languageName, equals('Árabe'));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // LanguageDetector.getLanguageInfo Tests
  // ---------------------------------------------------------------------------
  group('LanguageDetector.getLanguageInfo', () {
    test('retorna información completa por nombre en español', () {
      final info = LanguageDetector.getLanguageInfo('Francés');

      expect(info, isNotNull);
      expect(info!['spanish'], equals('Francés'));
      expect(info['english'], equals('French'));
      expect(info['native'], equals('Français'));
      expect(info['iso639_1'], equals('fr'));
      expect(info['iso639_3'], equals('fra'));
    });

    test('retorna información por nombre en inglés', () {
      final info = LanguageDetector.getLanguageInfo('German');

      expect(info, isNotNull);
      expect(info!['spanish'], equals('Alemán'));
    });

    test('retorna información por nombre nativo', () {
      final info = LanguageDetector.getLanguageInfo('Deutsch');

      expect(info, isNotNull);
      expect(info!['spanish'], equals('Alemán'));
    });

    test('retorna información por código ISO 639-1', () {
      final info = LanguageDetector.getLanguageInfo('es');

      expect(info, isNotNull);
      expect(info!['spanish'], equals('Español'));
    });

    test('retorna información por código ISO 639-3', () {
      final info = LanguageDetector.getLanguageInfo('jpn');

      expect(info, isNotNull);
      expect(info!['spanish'], equals('Japonés'));
    });

    test('retorna información por alias', () {
      final info = LanguageDetector.getLanguageInfo('castellano');

      expect(info, isNotNull);
      expect(info!['spanish'], equals('Español'));
    });

    test('es case insensitive', () {
      final info1 = LanguageDetector.getLanguageInfo('FRANCÉS');
      final info2 = LanguageDetector.getLanguageInfo('francés');
      final info3 = LanguageDetector.getLanguageInfo('FrAnCéS');

      expect(info1, isNotNull);
      expect(info2, isNotNull);
      expect(info3, isNotNull);
      expect(info1!['spanish'], equals(info2!['spanish']));
      expect(info2['spanish'], equals(info3!['spanish']));
    });

    test('trim de espacios', () {
      final info = LanguageDetector.getLanguageInfo('  francés  ');

      expect(info, isNotNull);
      expect(info!['spanish'], equals('Francés'));
    });

    test('retorna null para idioma no soportado', () {
      final info = LanguageDetector.getLanguageInfo('klingon');

      expect(info, isNull);
    });

    test('retorna null para string vacío', () {
      final info = LanguageDetector.getLanguageInfo('');

      expect(info, isNull);
    });

    test('retorna null para solo espacios', () {
      final info = LanguageDetector.getLanguageInfo('   ');

      expect(info, isNull);
    });

    test('incluye aliases en la información retornada', () {
      final info = LanguageDetector.getLanguageInfo('español');

      expect(info, isNotNull);
      expect(info!['aliases'], isA<List>());
      expect((info['aliases'] as List), contains('castellano'));
    });
  });

  // ---------------------------------------------------------------------------
  // LanguageDetector.getSupportedLanguages Tests
  // ---------------------------------------------------------------------------
  group('LanguageDetector.getSupportedLanguages', () {
    test('retorna lista no vacía', () {
      final languages = LanguageDetector.getSupportedLanguages();

      expect(languages, isNotEmpty);
    });

    test('retorna nombres en español', () {
      final languages = LanguageDetector.getSupportedLanguages();

      expect(languages, contains('Inglés'));
      expect(languages, contains('Español'));
      expect(languages, contains('Francés'));
      expect(languages, contains('Alemán'));
      expect(languages, contains('Italiano'));
      expect(languages, contains('Portugués'));
      expect(languages, contains('Chino'));
      expect(languages, contains('Japonés'));
    });

    test('retorna lista del tamaño correcto', () {
      final languages = LanguageDetector.getSupportedLanguages();

      expect(languages.length, equals(LanguagesData.languages.length));
    });

    test('mantiene orden de la fuente de datos', () {
      final languages = LanguageDetector.getSupportedLanguages();

      // Primer idioma en LanguagesData es Inglés
      expect(languages.first, equals('Inglés'));
    });

    test('no contiene duplicados', () {
      final languages = LanguageDetector.getSupportedLanguages();
      final uniqueLanguages = languages.toSet();

      expect(languages.length, equals(uniqueLanguages.length));
    });

    test('todos los elementos son strings no vacíos', () {
      final languages = LanguageDetector.getSupportedLanguages();

      for (final lang in languages) {
        expect(lang, isA<String>());
        expect(lang, isNotEmpty);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // LanguageDetector.getLanguageCode Tests
  // ---------------------------------------------------------------------------
  group('LanguageDetector.getLanguageCode', () {
    test('retorna código ISO 639-1 por nombre en español', () {
      expect(LanguageDetector.getLanguageCode('español'), equals('es'));
      expect(LanguageDetector.getLanguageCode('francés'), equals('fr'));
      expect(LanguageDetector.getLanguageCode('alemán'), equals('de'));
      expect(LanguageDetector.getLanguageCode('italiano'), equals('it'));
    });

    test('retorna código por nombre en inglés', () {
      expect(LanguageDetector.getLanguageCode('Spanish'), equals('es'));
      expect(LanguageDetector.getLanguageCode('French'), equals('fr'));
      expect(LanguageDetector.getLanguageCode('German'), equals('de'));
    });

    test('retorna código por nombre nativo', () {
      expect(LanguageDetector.getLanguageCode('Deutsch'), equals('de'));
      expect(LanguageDetector.getLanguageCode('Français'), equals('fr'));
      expect(LanguageDetector.getLanguageCode('Português'), equals('pt'));
    });

    test('retorna código por alias', () {
      expect(LanguageDetector.getLanguageCode('castellano'), equals('es'));
      expect(LanguageDetector.getLanguageCode('mandarin'), equals('zh'));
    });

    test('es case insensitive', () {
      expect(LanguageDetector.getLanguageCode('ESPAÑOL'), equals('es'));
      expect(LanguageDetector.getLanguageCode('español'), equals('es'));
      expect(LanguageDetector.getLanguageCode('EsPaÑoL'), equals('es'));
    });

    test('retorna null para idioma no soportado', () {
      expect(LanguageDetector.getLanguageCode('klingon'), isNull);
      expect(LanguageDetector.getLanguageCode('elvish'), isNull);
    });

    test('retorna null para string vacío', () {
      expect(LanguageDetector.getLanguageCode(''), isNull);
    });

    test('códigos son de 2 caracteres', () {
      final languages = ['español', 'francés', 'alemán', 'inglés', 'italiano'];

      for (final lang in languages) {
        final code = LanguageDetector.getLanguageCode(lang);
        expect(code, isNotNull);
        expect(code!.length, equals(2));
      }
    });

    test('códigos son minúsculas', () {
      final code = LanguageDetector.getLanguageCode('Español');

      expect(code, equals('es'));
      expect(code, equals(code!.toLowerCase()));
    });
  });

  // ---------------------------------------------------------------------------
  // LanguageDetector.isLanguageSupported Tests
  // ---------------------------------------------------------------------------
  group('LanguageDetector.isLanguageSupported', () {
    test('retorna true para idiomas soportados en español', () {
      expect(LanguageDetector.isLanguageSupported('español'), isTrue);
      expect(LanguageDetector.isLanguageSupported('francés'), isTrue);
      expect(LanguageDetector.isLanguageSupported('alemán'), isTrue);
      expect(LanguageDetector.isLanguageSupported('inglés'), isTrue);
    });

    test('retorna true para idiomas soportados en inglés', () {
      expect(LanguageDetector.isLanguageSupported('Spanish'), isTrue);
      expect(LanguageDetector.isLanguageSupported('French'), isTrue);
      expect(LanguageDetector.isLanguageSupported('German'), isTrue);
      expect(LanguageDetector.isLanguageSupported('English'), isTrue);
    });

    test('retorna true para nombres nativos', () {
      expect(LanguageDetector.isLanguageSupported('Deutsch'), isTrue);
      expect(LanguageDetector.isLanguageSupported('Français'), isTrue);
      expect(LanguageDetector.isLanguageSupported('中文'), isTrue);
      expect(LanguageDetector.isLanguageSupported('日本語'), isTrue);
    });

    test('retorna true para códigos ISO', () {
      expect(LanguageDetector.isLanguageSupported('es'), isTrue);
      expect(LanguageDetector.isLanguageSupported('fr'), isTrue);
      expect(LanguageDetector.isLanguageSupported('de'), isTrue);
      expect(LanguageDetector.isLanguageSupported('spa'), isTrue);
      expect(LanguageDetector.isLanguageSupported('fra'), isTrue);
    });

    test('retorna true para aliases', () {
      expect(LanguageDetector.isLanguageSupported('castellano'), isTrue);
      expect(LanguageDetector.isLanguageSupported('mandarin'), isTrue);
      expect(LanguageDetector.isLanguageSupported('espanol'), isTrue);
    });

    test('retorna false para idiomas no soportados', () {
      expect(LanguageDetector.isLanguageSupported('klingon'), isFalse);
      expect(LanguageDetector.isLanguageSupported('elvish'), isFalse);
      expect(LanguageDetector.isLanguageSupported('dothraki'), isFalse);
    });

    test('retorna false para string vacío', () {
      expect(LanguageDetector.isLanguageSupported(''), isFalse);
    });

    test('retorna false para solo espacios', () {
      expect(LanguageDetector.isLanguageSupported('   '), isFalse);
    });

    test('es case insensitive', () {
      expect(LanguageDetector.isLanguageSupported('ESPAÑOL'), isTrue);
      expect(LanguageDetector.isLanguageSupported('español'), isTrue);
      expect(LanguageDetector.isLanguageSupported('EsPaÑoL'), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Casos edge e integración
  // ---------------------------------------------------------------------------
  group('casos edge e integración', () {
    test('detectLanguage y getLanguageInfo son consistentes', () {
      final detectionResult = LanguageDetector.detectLanguage('francés hello');
      final languageInfo =
          LanguageDetector.getLanguageInfo(detectionResult.languageName);

      expect(languageInfo, isNotNull);
      expect(languageInfo!['spanish'], equals(detectionResult.languageName));
    });

    test('todos los idiomas soportados pueden ser detectados', () {
      final supportedLanguages = LanguageDetector.getSupportedLanguages();

      for (final lang in supportedLanguages) {
        final result = LanguageDetector.detectLanguage('$lang test text');

        expect(result.wasDetected, isTrue,
            reason: 'No se detectó el idioma: $lang');
        expect(result.languageName, equals(lang));
      }
    });

    test('todos los idiomas soportados tienen código ISO', () {
      final supportedLanguages = LanguageDetector.getSupportedLanguages();

      for (final lang in supportedLanguages) {
        final code = LanguageDetector.getLanguageCode(lang);

        expect(code, isNotNull, reason: 'No hay código ISO para: $lang');
      }
    });

    test('getLanguageCode retorna mismo resultado que getLanguageInfo', () {
      final languages = ['español', 'francés', 'alemán', 'inglés'];

      for (final lang in languages) {
        final code = LanguageDetector.getLanguageCode(lang);
        final info = LanguageDetector.getLanguageInfo(lang);

        expect(code, equals(info?['iso639_1']));
      }
    });

    test('maneja texto con múltiples idiomas (solo detecta el primero)', () {
      final result =
          LanguageDetector.detectLanguage('francés español alemán text');

      expect(result.languageName, equals('Francés'));
      expect(result.remainingText, equals('español alemán text'));
    });

    test('maneja caracteres especiales en texto restante', () {
      final result =
          LanguageDetector.detectLanguage('español ¡Hola! ¿Cómo estás? @#\$%');

      expect(result.languageName, equals('Español'));
      expect(result.remainingText, equals('¡Hola! ¿Cómo estás? @#\$%'));
    });

    test('maneja saltos de línea en texto', () {
      final result =
          LanguageDetector.detectLanguage('francés línea1\nlínea2\nlínea3');

      expect(result.languageName, equals('Francés'));
      expect(result.remainingText, contains('\n'));
    });

    test('prioriza variación más larga para evitar falsos positivos', () {
      // "catalán" (7 chars) debería detectarse antes que "cat" (3 chars)
      final result = LanguageDetector.detectLanguage('catalán hola');

      expect(result.languageName, equals('Catalán'));
      expect(result.wasDetected, isTrue);
    });
  });
}