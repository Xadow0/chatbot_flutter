/// Datos de idiomas con sus variaciones, códigos ISO y aliases
/// Utilizado para la detección de idiomas en comandos de traducción
class LanguagesData {
  /// Lista completa de idiomas soportados con sus variaciones
  /// 
  /// Cada entrada contiene:
  /// - spanish: nombre en español
  /// - english: nombre en inglés
  /// - native: nombre nativo
  /// - iso639_1: código ISO 639-1 (2 letras)
  /// - iso639_3: código ISO 639-3 (3 letras)
  /// - aliases: variaciones y errores comunes de escritura
  static final List<Map<String, Object>> languages = [
    // --- Idiomas Principales (Top Tier) ---
    {
      'spanish': 'Inglés',
      'english': 'English',
      'native': 'English',
      'iso639_1': 'en',
      'iso639_3': 'eng',
      'aliases': ['ingles', 'britanico', 'americano', 'inglés']
    },
    {
      'spanish': 'Español',
      'english': 'Spanish',
      'native': 'Español',
      'iso639_1': 'es',
      'iso639_3': 'spa',
      'aliases': ['espanol', 'esp', 'castellano', 'latino', 'hispano', 'español']
    },
    {
      'spanish': 'Francés',
      'english': 'French',
      'native': 'Français',
      'iso639_1': 'fr',
      'iso639_3': 'fra',
      'aliases': ['frances', 'fran', 'baguette']
    },
    {
      'spanish': 'Alemán',
      'english': 'German',
      'native': 'Deutsch',
      'iso639_1': 'de',
      'iso639_3': 'deu',
      'aliases': ['aleman', 'ger', 'deutsch', 'german']
    },
    {
      'spanish': 'Italiano',
      'english': 'Italian',
      'native': 'Italiano',
      'iso639_1': 'it',
      'iso639_3': 'ita',
      'aliases': ['ita', 'tano', 'italia']
    },
    {
      'spanish': 'Portugués',
      'english': 'Portuguese',
      'native': 'Português',
      'iso639_1': 'pt',
      'iso639_3': 'por',
      'aliases': ['portugues', 'portu', 'br', 'brasileño']
    },
    {
      'spanish': 'Ruso',
      'english': 'Russian',
      'native': 'Русский',
      'iso639_1': 'ru',
      'iso639_3': 'rus',
      'aliases': ['rusia', 'rus', 'sovietico']
    },
    {
      'spanish': 'Árabe',
      'english': 'Arabic',
      'native': 'العربية الفصحى',
      'iso639_1': 'ar',
      'iso639_3': 'arb',
      'aliases': ['arabe', 'arab']
    },
    {
      'spanish': 'Japonés',
      'english': 'Japanese',
      'native': '日本語',
      'iso639_1': 'ja',
      'iso639_3': 'jpn',
      'aliases': ['japones', 'japon', 'jp', 'nipon', 'anime']
    },
    {
      'spanish': 'Coreano',
      'english': 'Korean',
      'native': '한국어',
      'iso639_1': 'ko',
      'iso639_3': 'kor',
      'aliases': ['korea', 'surcoreano', 'kr', 'kpop']
    },

    // --- Variantes de Chino ---
    {
      'spanish': 'Chino Mandarín',
      'english': 'Mandarin Chinese',
      'native': '普通话 / 國語',
      'iso639_1': 'zh',
      'iso639_3': 'cmn',
      'aliases': ['chino', 'mandarin', 'cn', 'pekin']
    },
    {
      'spanish': 'Chino Cantonés',
      'english': 'Cantonese Chinese',
      'native': '廣東話 / 粤语',
      'iso639_1': 'zh',
      'iso639_3': 'yue',
      'aliases': ['cantones', 'canton', 'hk']
    },

    // --- Principales de Asia ---
    {
      'spanish': 'Hindi',
      'english': 'Hindi',
      'native': 'हिन्दी',
      'iso639_1': 'hi',
      'iso639_3': 'hin',
      'aliases': ['indio', 'hindu']
    },
    {
      'spanish': 'Bengalí',
      'english': 'Bengali',
      'native': 'বাংলা',
      'iso639_1': 'bn',
      'iso639_3': 'ben',
      'aliases': ['bengali', 'bangla']
    },
    {
      'spanish': 'Panyabí',
      'english': 'Punjabi',
      'native': 'ਪੰਜਾਬੀ / پن٘جابی',
      'iso639_1': 'pa',
      'iso639_3': 'pan',
      'aliases': ['panyabi', 'punjabi', 'panjabi']
    },
    {
      'spanish': 'Urdu',
      'english': 'Urdu',
      'native': 'اردو',
      'iso639_1': 'ur',
      'iso639_3': 'urd',
      'aliases': ['pakistan']
    },
    {
      'spanish': 'Indonesio',
      'english': 'Indonesian',
      'native': 'Bahasa Indonesia',
      'iso639_1': 'id',
      'iso639_3': 'ind',
      'aliases': ['indonesia', 'indo']
    },
    {
      'spanish': 'Malayo',
      'english': 'Malay',
      'native': 'Bahasa Melayu',
      'iso639_1': 'ms',
      'iso639_3': 'msa',
      'aliases': ['malayo', 'malasia']
    },
    {
      'spanish': 'Turco',
      'english': 'Turkish',
      'native': 'Türkçe',
      'iso639_1': 'tr',
      'iso639_3': 'tur',
      'aliases': ['turco', 'turquia', 'turk']
    },
    {
      'spanish': 'Vietnamita',
      'english': 'Vietnamese',
      'native': 'Tiếng Việt',
      'iso639_1': 'vi',
      'iso639_3': 'vie',
      'aliases': ['viet', 'vietnamita']
    },
    {
      'spanish': 'Tailandés',
      'english': 'Thai',
      'native': 'ภาษาไทย',
      'iso639_1': 'th',
      'iso639_3': 'tha',
      'aliases': ['tailandes', 'thai', 'tailandia']
    },
    {
      'spanish': 'Persa',
      'english': 'Persian',
      'native': 'فارسی',
      'iso639_1': 'fa',
      'iso639_3': 'fas',
      'aliases': ['persa', 'farsi', 'irani']
    },
    {
      'spanish': 'Tamil',
      'english': 'Tamil',
      'native': 'தமிழ்',
      'iso639_1': 'ta',
      'iso639_3': 'tam',
      'aliases': ['tamil']
    },
    {
      'spanish': 'Telugu',
      'english': 'Telugu',
      'native': 'తెలుగు',
      'iso639_1': 'te',
      'iso639_3': 'tel',
      'aliases': ['telugu']
    },
    {
      'spanish': 'Maratí',
      'english': 'Marathi',
      'native': 'मराठी',
      'iso639_1': 'mr',
      'iso639_3': 'mar',
      'aliases': ['marati', 'marathi']
    },
    {
      'spanish': 'Gujaratí',
      'english': 'Gujarati',
      'native': 'ગુજરાતી',
      'iso639_1': 'gu',
      'iso639_3': 'guj',
      'aliases': ['gujarati']
    },
    {
      'spanish': 'Canarés',
      'english': 'Kannada',
      'native': 'ಕನ್ನಡ',
      'iso639_1': 'kn',
      'iso639_3': 'kan',
      'aliases': ['kannada', 'canares']
    },

    // --- Europa del Este ---
    {
      'spanish': 'Polaco',
      'english': 'Polish',
      'native': 'Polski',
      'iso639_1': 'pl',
      'iso639_3': 'pol',
      'aliases': ['polaco', 'polonia']
    },
    {
      'spanish': 'Ucraniano',
      'english': 'Ukrainian',
      'native': 'Українська',
      'iso639_1': 'uk',
      'iso639_3': 'ukr',
      'aliases': ['ucraniano', 'ucrania']
    },
    {
      'spanish': 'Checo',
      'english': 'Czech',
      'native': 'Čeština',
      'iso639_1': 'cs',
      'iso639_3': 'ces',
      'aliases': ['checo', 'chequia']
    },
    {
      'spanish': 'Húngaro',
      'english': 'Hungarian',
      'native': 'Magyar',
      'iso639_1': 'hu',
      'iso639_3': 'hun',
      'aliases': ['hungaro', 'hungaria']
    },
    {
      'spanish': 'Rumano',
      'english': 'Romanian',
      'native': 'Română',
      'iso639_1': 'ro',
      'iso639_3': 'ron',
      'aliases': ['rumano', 'rumania']
    },
    {
      'spanish': 'Búlgaro',
      'english': 'Bulgarian',
      'native': 'Български',
      'iso639_1': 'bg',
      'iso639_3': 'bul',
      'aliases': ['bulgaro', 'bulgaria']
    },
    {
      'spanish': 'Serbio',
      'english': 'Serbian',
      'native': 'Српски',
      'iso639_1': 'sr',
      'iso639_3': 'srp',
      'aliases': ['serbio', 'serbia']
    },
    {
      'spanish': 'Croata',
      'english': 'Croatian',
      'native': 'Hrvatski',
      'iso639_1': 'hr',
      'iso639_3': 'hrv',
      'aliases': ['croata', 'croacia']
    },
    {
      'spanish': 'Eslovaco',
      'english': 'Slovak',
      'native': 'Slovenčina',
      'iso639_1': 'sk',
      'iso639_3': 'slk',
      'aliases': ['eslovaco', 'eslovaquia']
    },
    {
      'spanish': 'Esloveno',
      'english': 'Slovenian',
      'native': 'Slovenščina',
      'iso639_1': 'sl',
      'iso639_3': 'slv',
      'aliases': ['esloveno', 'eslovenia']
    },

    // --- Europa Nórdica ---
    {
      'spanish': 'Sueco',
      'english': 'Swedish',
      'native': 'Svenska',
      'iso639_1': 'sv',
      'iso639_3': 'swe',
      'aliases': ['sueco', 'suecia']
    },
    {
      'spanish': 'Noruego',
      'english': 'Norwegian',
      'native': 'Norsk',
      'iso639_1': 'no',
      'iso639_3': 'nor',
      'aliases': ['noruego', 'noruega']
    },
    {
      'spanish': 'Danés',
      'english': 'Danish',
      'native': 'Dansk',
      'iso639_1': 'da',
      'iso639_3': 'dan',
      'aliases': ['danes', 'dinamarca']
    },
    {
      'spanish': 'Finlandés',
      'english': 'Finnish',
      'native': 'Suomi',
      'iso639_1': 'fi',
      'iso639_3': 'fin',
      'aliases': ['finlandes', 'finlandia']
    },
    {
      'spanish': 'Islandés',
      'english': 'Icelandic',
      'native': 'Íslenska',
      'iso639_1': 'is',
      'iso639_3': 'isl',
      'aliases': ['islandes', 'islandia']
    },

    // --- Europa Occidental ---
    {
      'spanish': 'Neerlandés',
      'english': 'Dutch',
      'native': 'Nederlands',
      'iso639_1': 'nl',
      'iso639_3': 'nld',
      'aliases': ['neerlandes', 'holandes', 'flamenco', 'dutch']
    },
    {
      'spanish': 'Griego',
      'english': 'Greek',
      'native': 'Ελληνικά',
      'iso639_1': 'el',
      'iso639_3': 'ell',
      'aliases': ['griego', 'grecia']
    },
    {
      'spanish': 'Catalán',
      'english': 'Catalan',
      'native': 'Català',
      'iso639_1': 'ca',
      'iso639_3': 'cat',
      'aliases': ['catalan', 'catalunya']
    },
    {
      'spanish': 'Gallego',
      'english': 'Galician',
      'native': 'Galego',
      'iso639_1': 'gl',
      'iso639_3': 'glg',
      'aliases': ['gallego', 'galicia']
    },
    {
      'spanish': 'Vasco',
      'english': 'Basque',
      'native': 'Euskara',
      'iso639_1': 'eu',
      'iso639_3': 'eus',
      'aliases': ['vasco', 'euskera', 'pais vasco']
    },

    // --- Idiomas de África ---
    {
      'spanish': 'Suajili',
      'english': 'Swahili',
      'native': 'Kiswahili',
      'iso639_1': 'sw',
      'iso639_3': 'swa',
      'aliases': ['suajili', 'swahili', 'kiswahili']
    },
    {
      'spanish': 'Amárico',
      'english': 'Amharic',
      'native': 'አማርኛ',
      'iso639_1': 'am',
      'iso639_3': 'amh',
      'aliases': ['amarico', 'etiope']
    },
    {
      'spanish': 'Yoruba',
      'english': 'Yoruba',
      'native': 'Yorùbá',
      'iso639_1': 'yo',
      'iso639_3': 'yor',
      'aliases': ['yoruba']
    },
    {
      'spanish': 'Zulú',
      'english': 'Zulu',
      'native': 'isiZulu',
      'iso639_1': 'zu',
      'iso639_3': 'zul',
      'aliases': ['zulu', 'sudafrica']
    },
    {
      'spanish': 'Hausa',
      'english': 'Hausa',
      'native': 'Hausa',
      'iso639_1': 'ha',
      'iso639_3': 'hau',
      'aliases': ['hausa']
    },
    {
      'spanish': 'Igbo',
      'english': 'Igbo',
      'native': 'Igbo',
      'iso639_1': 'ig',
      'iso639_3': 'ibo',
      'aliases': ['igbo']
    },

    // --- Idiomas Indígenas de América ---
    {
      'spanish': 'Quechua',
      'english': 'Quechua',
      'native': 'Runa Simi',
      'iso639_1': 'qu',
      'iso639_3': 'que',
      'aliases': ['quechua', 'andes']
    },
    {
      'spanish': 'Guaraní',
      'english': 'Guarani',
      'native': 'Avañe\'ẽ',
      'iso639_1': 'gn',
      'iso639_3': 'grn',
      'aliases': ['guarani']
    },
    {
      'spanish': 'Náhuatl',
      'english': 'Nahuatl',
      'native': 'Nāhuatl',
      'iso639_1': 'nah',
      'iso639_3': 'nah',
      'aliases': ['nahuatl', 'azteca', 'mexicano']
    },
    {
      'spanish': 'Maya Yucateco',
      'english': 'Yucatec Maya',
      'native': 'Maaya T\'aan',
      'iso639_1': 'yua',
      'iso639_3': 'yua',
      'aliases': ['maya', 'mayas']
    },

    // --- Clásicos / Construidos ---
    {
      'spanish': 'Latín',
      'english': 'Latin',
      'native': 'Latina',
      'iso639_1': 'la',
      'iso639_3': 'lat',
      'aliases': ['latin', 'romano']
    },
    {
      'spanish': 'Griego Antiguo',
      'english': 'Ancient Greek',
      'native': 'Ἀρχαία Ἑλληνική',
      'iso639_1': 'grc',
      'iso639_3': 'grc',
      'aliases': ['griego antiguo']
    },
    {
      'spanish': 'Sánscrito',
      'english': 'Sanskrit',
      'native': 'संस्कृतम्',
      'iso639_1': 'sa',
      'iso639_3': 'san',
      'aliases': ['sanscrito', 'veda']
    },
    {
      'spanish': 'Esperanto',
      'english': 'Esperanto',
      'native': 'Esperanto',
      'iso639_1': 'eo',
      'iso639_3': 'epo',
      'aliases': ['esperanto']
    },
  ];
}