import '../constants/languages_data.dart';

/// Resultado de la detección de idioma
class LanguageDetectionResult {
  /// Idioma detectado en español (ej: 'Francés')
  final String languageName;
  
  /// Texto restante después de extraer el idioma
  final String remainingText;
  
  /// Indica si se detectó un idioma explícito
  final bool wasDetected;

  LanguageDetectionResult({
    required this.languageName,
    required this.remainingText,
    required this.wasDetected,
  });

  /// Constructor para cuando no se detecta idioma (usa el por defecto)
  factory LanguageDetectionResult.defaultLanguage(String text, {String defaultLang = 'inglés'}) {
    return LanguageDetectionResult(
      languageName: defaultLang,
      remainingText: text,
      wasDetected: false,
    );
  }

  /// Constructor para cuando se detecta un idioma
  factory LanguageDetectionResult.detected(String language, String text) {
    return LanguageDetectionResult(
      languageName: language,
      remainingText: text,
      wasDetected: true,
    );
  }
}

/// Servicio para detectar idiomas en texto
/// 
/// Detecta idiomas al inicio del texto usando nombres en español, inglés,
/// nombres nativos, códigos ISO y aliases comunes
class LanguageDetector {
  /// Detecta el idioma al inicio del contenido
  /// 
  /// Parámetros:
  /// - [content]: texto donde buscar el idioma
  /// - [defaultLanguage]: idioma por defecto si no se detecta ninguno (default: 'inglés')
  /// 
  /// Retorna [LanguageDetectionResult] con el idioma detectado y el texto restante
  /// 
  /// Ejemplo:
  /// ```dart
  /// final result = LanguageDetector.detectLanguage('francés hello world');
  /// print(result.languageName); // 'Francés'
  /// print(result.remainingText); // 'hello world'
  /// print(result.wasDetected); // true
  /// ```
  static LanguageDetectionResult detectLanguage(
    String content, {
    String defaultLanguage = 'inglés',
  }) {
    if (content.trim().isEmpty) {
      return LanguageDetectionResult.defaultLanguage(content, defaultLang: defaultLanguage);
    }

    final lowerContent = content.toLowerCase();

    // Iterar sobre todos los idiomas disponibles
    for (final langData in LanguagesData.languages) {
      // 1. Recopilar variantes estándar (nombres y códigos ISO)
      final standardVariations = [
        langData['spanish'],
        langData['english'],
        langData['native'],
        langData['iso639_1'],
        langData['iso639_3'],
      ].whereType<String>().toList();

      // 2. Recopilar aliases si existen
      final aliases = (langData['aliases'] as List<String>?) ?? [];

      // 3. Combinar todas las variaciones
      final allVariations = [...standardVariations, ...aliases]
          .where((s) => s.isNotEmpty)
          .map((s) => s.toLowerCase())
          .toList();

      // Ordenar por longitud descendente para evitar falsos positivos
      // (ej: "cat" vs "catalan", "frances" vs "francesca")
      allVariations.sort((a, b) => b.length.compareTo(a.length));

      // Buscar coincidencia
      for (final variation in allVariations) {
        if (lowerContent.startsWith(variation)) {
          // Verificar límite de palabra para evitar matches parciales
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

    // No se detectó ningún idioma, usar el predeterminado
    return LanguageDetectionResult.defaultLanguage(content, defaultLang: defaultLanguage);
  }

  /// Obtiene información completa de un idioma por su nombre
  /// 
  /// Parámetros:
  /// - [languageName]: nombre del idioma en cualquier formato
  /// 
  /// Retorna el mapa con toda la información del idioma o null si no se encuentra
  /// 
  /// Ejemplo:
  /// ```dart
  /// final info = LanguageDetector.getLanguageInfo('frances');
  /// print(info?['native']); // 'Français'
  /// print(info?['iso639_1']); // 'fr'
  /// ```
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

  /// Lista todos los idiomas soportados
  /// 
  /// Retorna una lista con los nombres en español de todos los idiomas
  /// 
  /// Ejemplo:
  /// ```dart
  /// final languages = LanguageDetector.getSupportedLanguages();
  /// print(languages.first); // 'Inglés'
  /// ```
  static List<String> getSupportedLanguages() {
    return LanguagesData.languages
        .map((lang) => lang['spanish'] as String)
        .toList();
  }

  /// Obtiene el código ISO 639-1 de un idioma
  /// 
  /// Parámetros:
  /// - [languageName]: nombre del idioma en cualquier formato
  /// 
  /// Retorna el código ISO 639-1 (2 letras) o null si no se encuentra
  /// 
  /// Ejemplo:
  /// ```dart
  /// final code = LanguageDetector.getLanguageCode('español');
  /// print(code); // 'es'
  /// ```
  static String? getLanguageCode(String languageName) {
    final info = getLanguageInfo(languageName);
    return info?['iso639_1'] as String?;
  }

  /// Valida si un nombre de idioma es soportado
  /// 
  /// Parámetros:
  /// - [languageName]: nombre del idioma a validar
  /// 
  /// Retorna true si el idioma es soportado
  /// 
  /// Ejemplo:
  /// ```dart
  /// print(LanguageDetector.isLanguageSupported('francés')); // true
  /// print(LanguageDetector.isLanguageSupported('klingon')); // false
  /// ```
  static bool isLanguageSupported(String languageName) {
    return getLanguageInfo(languageName) != null;
  }
}