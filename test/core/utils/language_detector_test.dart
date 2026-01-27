import 'package:flutter_test/flutter_test.dart';
import 'package:chatbot_app/core/utils/language_detector.dart';
import 'package:chatbot_app/core/constants/languages_data.dart';

void main() {
  group('LanguageDetectionResult factories', () {
    test('defaultLanguage constructor', () {
      final result = LanguageDetectionResult.defaultLanguage(
        'hello',
        defaultLang: 'español',
      );

      expect(result.languageName, equals('español'));
      expect(result.remainingText, equals('hello'));
      expect(result.wasDetected, isFalse);
    });

    test('detected constructor', () {
      final result = LanguageDetectionResult.detected('Francés', 'bonjour');

      expect(result.languageName, equals('Francés'));
      expect(result.remainingText, equals('bonjour'));
      expect(result.wasDetected, isTrue);
    });
  });

  group('LanguageDetector.detectLanguage', () {
    test('returns default when content is empty or whitespace', () {
      final result = LanguageDetector.detectLanguage(
        '   ',
        defaultLanguage: 'alemán',
      );

      expect(result.languageName, equals('alemán'));
      expect(result.remainingText, equals('   '));
      expect(result.wasDetected, isFalse);
    });

    test('detects language by spanish name', () {
      final result = LanguageDetector.detectLanguage('francés hola mundo');

      expect(result.languageName.toLowerCase(), equals('francés'));
      expect(result.remainingText, equals('hola mundo'));
      expect(result.wasDetected, isTrue);
    });

    test('detects language by english name', () {
      final result = LanguageDetector.detectLanguage('english hello world');

      expect(result.languageName.toLowerCase(), equals('inglés'));
      expect(result.remainingText, equals('hello world'));
      expect(result.wasDetected, isTrue);
    });

    test('detects language by native name', () {
      // Ejemplo típico: Français, Deutsch, Italiano, etc.
      final french = LanguagesData.languages.firstWhere(
        (l) => (l['spanish'] as String).toLowerCase() == 'francés',
      );

      final native = french['native'] as String;

      final result =
          LanguageDetector.detectLanguage('$native bonjour tout le monde');

      expect(result.languageName.toLowerCase(), equals('francés'));
      expect(result.remainingText, equals('bonjour tout le monde'));
      expect(result.wasDetected, isTrue);
    });

    test('detects language by ISO 639-1 code', () {
      final result = LanguageDetector.detectLanguage('es hola mundo');

      expect(result.languageName.toLowerCase(), equals('español'));
      expect(result.remainingText, equals('hola mundo'));
      expect(result.wasDetected, isTrue);
    });

    test('detects language by ISO 639-3 code', () {
      final result = LanguageDetector.detectLanguage('eng hello world');

      expect(result.languageName.toLowerCase(), equals('inglés'));
      expect(result.remainingText, equals('hello world'));
      expect(result.wasDetected, isTrue);
    });

    test('detects language by alias if available', () {
      // Busca un idioma que tenga aliases definidos
      final withAlias = LanguagesData.languages.firstWhere(
        (l) => (l['aliases'] as List?) != null && (l['aliases'] as List).isNotEmpty,
      );

      final alias = (withAlias['aliases'] as List<String>).first;
      final spanishName = withAlias['spanish'] as String;

      final result = LanguageDetector.detectLanguage('$alias texto de prueba');

      expect(result.languageName, equals(spanishName));
      expect(result.remainingText, equals('texto de prueba'));
      expect(result.wasDetected, isTrue);
    });

    test('does not match partial word (word boundary check)', () {
      // Ejemplo: "francesca" NO debe detectar "frances"
      final result =
          LanguageDetector.detectLanguage('francesca hola mundo');

      expect(result.wasDetected, isFalse);
      expect(result.languageName.toLowerCase(), equals('inglés')); // default
      expect(result.remainingText, equals('francesca hola mundo'));
    });

    test('returns default language when no language is detected', () {
      final result = LanguageDetector.detectLanguage(
        'klingon tlhIngan',
        defaultLanguage: 'italiano',
      );

      expect(result.languageName, equals('italiano'));
      expect(result.remainingText, equals('klingon tlhIngan'));
      expect(result.wasDetected, isFalse);
    });
  });

  group('LanguageDetector.getLanguageInfo', () {
    test('returns language info when found (spanish name)', () {
      final info = LanguageDetector.getLanguageInfo('español');

      expect(info, isNotNull);
      expect(info!['iso639_1'], equals('es'));
    });

    test('returns language info when found (english name)', () {
      final info = LanguageDetector.getLanguageInfo('english');

      expect(info, isNotNull);
      expect(info!['spanish'].toString().toLowerCase(), equals('inglés'));
    });

    test('returns language info when found (alias)', () {
      final withAlias = LanguagesData.languages.firstWhere(
        (l) => (l['aliases'] as List?) != null && (l['aliases'] as List).isNotEmpty,
      );

      final alias = (withAlias['aliases'] as List<String>).first;

      final info = LanguageDetector.getLanguageInfo(alias);

      expect(info, isNotNull);
      expect(info!['spanish'], equals(withAlias['spanish']));
    });

    test('returns null when language is not found', () {
      final info = LanguageDetector.getLanguageInfo('klingon');

      expect(info, isNull);
    });
  });

  group('LanguageDetector.getSupportedLanguages', () {
    test('returns list of spanish language names', () {
      final languages = LanguageDetector.getSupportedLanguages();

      expect(languages, isNotEmpty);
      expect(languages.first, isA<String>());
      expect(languages.length, equals(LanguagesData.languages.length));
    });
  });

  group('LanguageDetector.getLanguageCode', () {
    test('returns ISO code when language exists', () {
      final code = LanguageDetector.getLanguageCode('español');

      expect(code, equals('es'));
    });

    test('returns null when language does not exist', () {
      final code = LanguageDetector.getLanguageCode('klingon');

      expect(code, isNull);
    });
  });

  group('LanguageDetector.isLanguageSupported', () {
    test('returns true for supported language', () {
      final supported = LanguageDetector.isLanguageSupported('francés');

      expect(supported, isTrue);
    });

    test('returns false for unsupported language', () {
      final supported = LanguageDetector.isLanguageSupported('klingon');

      expect(supported, isFalse);
    });
  });
}
