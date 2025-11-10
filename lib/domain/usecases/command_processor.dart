import 'package:flutter/foundation.dart';

/// Tipos de comandos disponibles en el sistema
enum CommandType {
  evaluarPrompt, // Comando /evaluarprompt para evaluar y mejorar prompts
  traducir,      // Comando /traducir para traducir texto a otro idioma
  resumir,       // Comando /resumir para resumir textos largos
  codigo,        // Comando /codigo para generar código
  corregir,      // Comando /corregir para corregir texto
  explicar,      // Comando /explicar para explicar conceptos
  comparar,      // Comando /comparar para comparar dos opciones
  none,          // No es un comando
}

/// Resultado del procesamiento de un comando
class CommandResult {
  final bool isCommand;
  final CommandType type;
  final String? processedMessage;
  final String? error;

  CommandResult({
    required this.isCommand,
    required this.type,
    this.processedMessage,
    this.error,
  });

  /// Constructor para cuando el mensaje NO es un comando
  factory CommandResult.notCommand() {
    return CommandResult(
      isCommand: false,
      type: CommandType.none,
    );
  }

  /// Constructor para cuando el comando se procesó exitosamente
  factory CommandResult.success(CommandType type, String message) {
    return CommandResult(
      isCommand: true,
      type: type,
      processedMessage: message,
    );
  }

  /// Constructor para cuando hubo un error al procesar el comando
  factory CommandResult.error(CommandType type, String error) {
    return CommandResult(
      isCommand: true,
      type: type,
      error: error,
    );
  }
}

/// Interfaz base que todos los servicios de IA deben implementar
/// Esto permite que CommandProcessor funcione con cualquier servicio:
/// - GeminiService (a través de GeminiServiceAdapter)
/// - OpenAIService (a través de OpenAIServiceAdapter)
/// - OllamaService (a través de OllamaServiceAdapter)
/// - LocalOllamaService (a través de LocalOllamaServiceAdapter)
abstract class AIServiceBase {
  /// Genera contenido CON historial de conversación (usado para chat normal)
  Future<String> generateContent(String prompt);
  
  /// Genera contenido SIN historial (usado para comandos como /evaluarprompt y /traducir)
  /// Este método debe enviar SOLO el prompt sin contexto adicional
  Future<String> generateContentWithoutHistory(String prompt);
}

/// Procesador de comandos que utiliza el servicio de IA actualmente seleccionado
/// 
/// Este procesador detecta y ejecuta comandos especiales que comienzan con '/'.
/// Cada comando utiliza la IA seleccionada por el usuario (Gemini, OpenAI, Ollama, etc.)
/// para generar respuestas especializadas.
/// 
/// **Flujo de trabajo:**
/// 1. El usuario escribe un mensaje
/// 2. ChatProvider -> SendMessageUseCase -> CommandProcessor
/// 3. Si es un comando, se procesa con la IA activa SIN HISTORIAL
/// 4. Si NO es un comando, se devuelve un eco local (sin IA)
/// 
/// **IMPORTANTE:** Los comandos como /evaluarprompt y /traducir usan `generateContentWithoutHistory`
/// para evitar que el historial de la conversación interfiera con el análisis/traducción.
class CommandProcessor {
  final AIServiceBase _aiService;

  final languages = [
    // --- Idiomas de la lista original ---
    { 'spanish': 'Inglés', 'english': 'English', 'native': 'English', 'iso639_1': 'en', 'iso639_3': 'eng' },
    { 'spanish': 'Español', 'english': 'Spanish', 'native': 'Español', 'iso639_1': 'es', 'iso639_3': 'spa' },
    { 'spanish': 'Francés', 'english': 'French', 'native': 'Français', 'iso639_1': 'fr', 'iso639_3': 'fra' },
    { 'spanish': 'Alemán', 'english': 'German', 'native': 'Deutsch', 'iso639_1': 'de', 'iso639_3': 'deu' },
    { 'spanish': 'Italiano', 'english': 'Italian', 'native': 'Italiano', 'iso639_1': 'it', 'iso639_3': 'ita' },
    { 'spanish': 'Portugués', 'english': 'Portuguese', 'native': 'Português', 'iso639_1': 'pt', 'iso639_3': 'por' },
    { 'spanish': 'Ruso', 'english': 'Russian', 'native': 'Русский', 'iso639_1': 'ru', 'iso639_3': 'rus' },
    { 'spanish': 'Árabe', 'english': 'Arabic', 'native': 'العربية الفصحى', 'iso639_1': 'ar', 'iso639_3': 'arb' },
    { 'spanish': 'Japonés', 'english': 'Japanese', 'native': '日本語', 'iso639_1': 'ja', 'iso639_3': 'jpn' },
    { 'spanish': 'Coreano', 'english': 'Korean', 'native': '한국어', 'iso639_1': 'ko', 'iso639_3': 'kor' },

    // --- Variantes de Chino ---
    { 'spanish': 'Chino Mandarín', 'english': 'Mandarin Chinese', 'native': '普通话 / 國語', 'iso639_1': 'zh', 'iso639_3': 'cmn' },
    { 'spanish': 'Chino Cantonés', 'english': 'Cantonese Chinese', 'native': '廣東話 / 粤语', 'iso639_1': 'zh', 'iso639_3': 'yue' },

    // --- Principales de Asia ---
    { 'spanish': 'Hindi', 'english': 'Hindi', 'native': 'हिन्दी', 'iso639_1': 'hi', 'iso639_3': 'hin' },
    { 'spanish': 'Bengalí', 'english': 'Bengali', 'native': 'বাংলা', 'iso639_1': 'bn', 'iso639_3': 'ben' },
    { 'spanish': 'Panyabí', 'english': 'Punjabi', 'native': 'ਪੰਜਾਬੀ / پن٘جابی', 'iso639_1': 'pa', 'iso639_3': 'pan' },
    { 'spanish': 'Urdu', 'english': 'Urdu', 'native': 'اردو', 'iso639_1': 'ur', 'iso639_3': 'urd' },
    { 'spanish': 'Indonesio', 'english': 'Indonesian', 'native': 'Bahasa Indonesia', 'iso639_1': 'id', 'iso639_3': 'ind' },
    { 'spanish': 'Malayo', 'english': 'Malay', 'native': 'Bahasa Melayu', 'iso639_1': 'ms', 'iso639_3': 'msa' },
    { 'spanish': 'Turco', 'english': 'Turkish', 'native': 'Türkçe', 'iso639_1': 'tr', 'iso639_3': 'tur' },
    { 'spanish': 'Vietnamita', 'english': 'Vietnamese', 'native': 'Tiếng Việt', 'iso639_1': 'vi', 'iso639_3': 'vie' },
    { 'spanish': 'Tailandés', 'english': 'Thai', 'native': 'ภาษาไทย', 'iso639_1': 'th', 'iso639_3': 'tha' },
    { 'spanish': 'Persa', 'english': 'Persian', 'native': 'فارسی', 'iso639_1': 'fa', 'iso639_3': 'fas' },
    { 'spanish': 'Tamil', 'english': 'Tamil', 'native': 'தமிழ்', 'iso639_1': 'ta', 'iso639_3': 'tam' },
    { 'spanish': 'Telugu', 'english': 'Telugu', 'native': 'తెలుగు', 'iso639_1': 'te', 'iso639_3': 'tel' },
    { 'spanish': 'Maratí', 'english': 'Marathi', 'native': 'मराठी', 'iso639_1': 'mr', 'iso639_3': 'mar' },
    { 'spanish': 'Tagalo', 'english': 'Tagalog', 'native': 'Tagalog', 'iso639_1': 'tl', 'iso639_3': 'tgl' },
    { 'spanish': 'Javanés', 'english': 'Javanese', 'native': 'Basa Jawa', 'iso639_1': 'jv', 'iso639_3': 'jav' },
    { 'spanish': 'Jemer', 'english': 'Khmer', 'native': 'ខ្មែរ', 'iso639_1': 'km', 'iso639_3': 'khm' },
    { 'spanish': 'Birmano', 'english': 'Burmese', 'native': 'မြန်မာဘာသာ', 'iso639_1': 'my', 'iso639_3': 'mya' },

    // --- Principales de Europa ---
    { 'spanish': 'Neerlandés', 'english': 'Dutch', 'native': 'Nederlands', 'iso639_1': 'nl', 'iso639_3': 'nld' },
    { 'spanish': 'Polaco', 'english': 'Polish', 'native': 'Polski', 'iso639_1': 'pl', 'iso639_3': 'pol' },
    { 'spanish': 'Ucraniano', 'english': 'Ukrainian', 'native': 'Українська', 'iso639_1': 'uk', 'iso639_3': 'ukr' },
    { 'spanish': 'Griego', 'english': 'Greek', 'native': 'Ελληνικά', 'iso639_1': 'el', 'iso639_3': 'ell' },
    { 'spanish': 'Sueco', 'english': 'Swedish', 'native': 'Svenska', 'iso639_1': 'sv', 'iso639_3': 'swe' },
    { 'spanish': 'Noruego', 'english': 'Norwegian', 'native': 'Norsk (Bokmål/Nynorsk)', 'iso639_1': 'no', 'iso639_3': 'nor' },
    { 'spanish': 'Danés', 'english': 'Danish', 'native': 'Dansk', 'iso639_1': 'da', 'iso639_3': 'dan' },
    { 'spanish': 'Finlandés', 'english': 'Finnish', 'native': 'Suomi', 'iso639_1': 'fi', 'iso639_3': 'fin' },
    { 'spanish': 'Checo', 'english': 'Czech', 'native': 'Čeština', 'iso639_1': 'cs', 'iso639_3': 'ces' },
    { 'spanish': 'Húngaro', 'english': 'Hungarian', 'native': 'Magyar', 'iso639_1': 'hu', 'iso639_3': 'hun' },
    { 'spanish': 'Rumano', 'english': 'Romanian', 'native': 'Română', 'iso639_1': 'ro', 'iso639_3': 'ron' },
    { 'spanish': 'Hebreo', 'english': 'Hebrew', 'native': 'עברית', 'iso639_1': 'he', 'iso639_3': 'heb' },
    { 'spanish': 'Búlgaro', 'english': 'Bulgarian', 'native': 'Български', 'iso639_1': 'bg', 'iso639_3': 'bul' },
    { 'spanish': 'Croata', 'english': 'Croatian', 'native': 'Hrvatski', 'iso639_1': 'hr', 'iso639_3': 'hrv' },
    { 'spanish': 'Serbio', 'english': 'Serbian', 'native': 'Српски / Srpski', 'iso639_1': 'sr', 'iso639_3': 'srp' },
    { 'spanish': 'Eslovaco', 'english': 'Slovak', 'native': 'Slovenčina', 'iso639_1': 'sk', 'iso639_3': 'slk' },
    { 'spanish': 'Esloveno', 'english': 'Slovenian', 'native': 'Slovenščina', 'iso639_1': 'sl', 'iso639_3': 'slv' },
    { 'spanish': 'Lituano', 'english': 'Lithuanian', 'native': 'Lietuvių', 'iso639_1': 'lt', 'iso639_3': 'lit' },
    { 'spanish': 'Letón', 'english': 'Latvian', 'native': 'Latviešu', 'iso639_1': 'lv', 'iso639_3': 'lav' },
    { 'spanish': 'Estonio', 'english': 'Estonian', 'native': 'Eesti', 'iso639_1': 'et', 'iso639_3': 'est' },
    { 'spanish': 'Islandés', 'english': 'Icelandic', 'native': 'Íslenska', 'iso639_1': 'is', 'iso639_3': 'isl' },
    { 'spanish': 'Irlandés', 'english': 'Irish', 'native': 'Gaeilge', 'iso639_1': 'ga', 'iso639_3': 'gle' },
    { 'spanish': 'Galés', 'english': 'Welsh', 'native': 'Cymraeg', 'iso639_1': 'cy', 'iso639_3': 'cym' },

    // --- Idiomas Cooficiales de España ---
    { 'spanish': 'Catalán', 'english': 'Catalan', 'native': 'Català', 'iso639_1': 'ca', 'iso639_3': 'cat' },
    { 'spanish': 'Gallego', 'english': 'Galician', 'native': 'Galego', 'iso639_1': 'gl', 'iso639_3': 'glg' },
    { 'spanish': 'Euskera', 'english': 'Basque', 'native': 'Euskara', 'iso639_1': 'eu', 'iso639_3': 'eus' },
    { 'spanish': 'Aranés', 'english': 'Aranese', 'native': 'Aranés', 'iso639_1': 'oc', 'iso639_3': 'oci' },

    // --- Principales de África ---
    { 'spanish': 'Suaheli', 'english': 'Swahili', 'native': 'Kiswahili', 'iso639_1': 'sw', 'iso639_3': 'swh' },
    { 'spanish': 'Hausa', 'english': 'Hausa', 'native': 'Hausa', 'iso639_1': 'ha', 'iso639_3': 'hau' },
    { 'spanish': 'Yoruba', 'english': 'Yoruba', 'native': 'Yorùbá', 'iso639_1': 'yo', 'iso639_3': 'yor' },
    { 'spanish': 'Igbo', 'english': 'Igbo', 'native': 'Igbo', 'iso639_1': 'ig', 'iso639_3': 'ibo' },
    { 'spanish': 'Amhárico', 'english': 'Amharic', 'native': 'አማርኛ', 'iso639_1': 'am', 'iso639_3': 'amh' },
    { 'spanish': 'Somalí', 'english': 'Somali', 'native': 'Soomaali', 'iso639_1': 'so', 'iso639_3': 'som' },
    { 'spanish': 'Zulú', 'english': 'Zulu', 'native': 'isiZulu', 'iso639_1': 'zu', 'iso639_3': 'zul' },
    { 'spanish': 'Xhosa', 'english': 'Xhosa', 'native': 'isiXhosa', 'iso639_1': 'xh', 'iso639_3': 'xho' },
    { 'spanish': 'Afrikáans', 'english': 'Afrikaans', 'native': 'Afrikaans', 'iso639_1': 'af', 'iso639_3': 'afr' },

    // --- Principales de América (Indígenas) ---
    { 'spanish': 'Quechua', 'english': 'Quechua', 'native': 'Runa Simi', 'iso639_1': 'qu', 'iso639_3': 'que' },
    { 'spanish': 'Guaraní', 'english': 'Guarani', 'native': 'Avañe\'ẽ', 'iso639_1': 'gn', 'iso639_3': 'grn' },
    { 'spanish': 'Náhuatl', 'english': 'Nahuatl', 'native': 'Nāhuatl', 'iso639_1': 'nah', 'iso639_3': 'nah' },
    { 'spanish': 'Maya Yucateco', 'english': 'Yucatec Maya', 'native': 'Maaya T\'aan', 'iso639_1': 'yua', 'iso639_3': 'yua' },

    // --- Clásicos / Construidos ---
    { 'spanish': 'Latín', 'english': 'Latin', 'native': 'Latina', 'iso639_1': 'la', 'iso639_3': 'lat' },
    { 'spanish': 'Griego Antiguo', 'english': 'Ancient Greek', 'native': 'Ἀρχαία Ἑλληνική', 'iso639_1': 'grc', 'iso639_3': 'grc' },
    { 'spanish': 'Sánscrito', 'english': 'Sanskrit', 'native': 'संस्कृतम्', 'iso639_1': 'sa', 'iso639_3': 'san' },
    { 'spanish': 'Esperanto', 'english': 'Esperanto', 'native': 'Esperanto', 'iso639_1': 'eo', 'iso639_3': 'epo' },
  ];

  CommandProcessor(this._aiService);

  /// Detecta si el mensaje es un comando y lo procesa
  /// 
  /// Retorna:
  /// - [CommandResult.notCommand()] si no es un comando
  /// - [CommandResult.success()] si el comando se procesó correctamente
  /// 
  /// Lanza:
  /// - [Exception] si hubo un error al procesar el comando (ej. error de red)
  Future<CommandResult> processMessage(String message) async {
    final normalizedMessage = message.trim().toLowerCase();

    debugPrint('🔍 [CommandProcessor] Analizando mensaje...');
    debugPrint('   📝 Contenido: ${message.length > 50 ? "${message.substring(0, 50)}..." : message}');

    // Detectar comando "/evaluarprompt"
    if (normalizedMessage.startsWith('/evaluarprompt')) {
      debugPrint('   ✅ Comando detectado: /evaluarprompt');
      return await _processEvaluarPrompt(message);
    }

    // Detectar comando "/traducir"
    if (normalizedMessage.startsWith('/traducir')) {
      debugPrint('   ✅ Comando detectado: /traducir');
      return await _processTraducir(message);
    }

    // Detectar comando "/resumir"
    if (normalizedMessage.startsWith('/resumir')) {
      debugPrint('   ✅ Comando detectado: /resumir');
      return await _processResumir(message);
    }

    // Detectar comando "/codigo"
    if (normalizedMessage.startsWith('/codigo')) {
      debugPrint('   ✅ Comando detectado: /codigo');
      return await _processCodigo(message);
    }

    // Detectar comando "/corregir"
    if (normalizedMessage.startsWith('/corregir')) {
      debugPrint('   ✅ Comando detectado: /corregir');
      return await _processCorregir(message);
    }

    // Detectar comando "/explicar"
    if (normalizedMessage.startsWith('/explicar')) {
      debugPrint('   ✅ Comando detectado: /explicar');
      return await _processExplicar(message);
    }

    // Detectar comando "/comparar"
    if (normalizedMessage.startsWith('/comparar')) {
      debugPrint('   ✅ Comando detectado: /comparar');
      return await _processComparar(message);
    }

    // No es un comando
    debugPrint('   ℹ️ No es un comando, retornando como mensaje normal');
    return CommandResult.notCommand();
  }


  
  /// Procesa el comando "/evaluarprompt" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando evalúa y mejora el prompt proporcionado por el usuario,
  /// utilizando la IA actualmente seleccionada (Gemini, OpenAI, Ollama, etc.)
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con el análisis del prompt.
  Future<CommandResult> _processEvaluarPrompt(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /evaluarprompt...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/evaluarprompt');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.evaluarPrompt,
          'Por favor, escribe algo después de "/evaluarprompt".\nEjemplo: /evaluarprompt ¿Qué es Flutter?',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para evaluación
      final enhancedPrompt = _buildEvaluarPromptPrompt(content);
      debugPrint('   🎯 Prompt especializado creado (${enhancedPrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = enhancedPrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // especializado sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Respuesta recibida de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.evaluarPrompt, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      
      // ===================================================================
      // ▼▼▼ MODIFICACIÓN CRÍTICA ▼▼▼
      // ===================================================================
      // En lugar de devolver un CommandResult.error, relanzamos la excepción
      // para que ChatProvider pueda capturarla y reaccionar.
      rethrow;
      // ===================================================================
    }
  }

  /// Procesa el comando "/traducir" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando traduce el texto proporcionado al idioma especificado manteniendo
  /// la intención, tono y significado original.
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con la traducción.
  Future<CommandResult> _processTraducir(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /traducir...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/traducir');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.traducir,
          'Por favor, escribe algo después de "/traducir".\nEjemplo: /traducir inglés Hola, ¿cómo estás?',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para traducción
      final translatePrompt = _buildTraducirPrompt(content);
      debugPrint('   🎯 Prompt de traducción creado (${translatePrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = translatePrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // de traducción sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Traducción recibida de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.traducir, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      
      // ===================================================================
      // ▼▼▼ MODIFICACIÓN CRÍTICA ▼▼▼
      // ===================================================================
      // Relanzamos la excepción también aquí.
      rethrow;
      // ===================================================================
    }
  }
    /// Procesa el comando "/resumir" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando resume textos largos extrayendo las ideas principales
  /// y presentándolas de forma clara y concisa.
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con el resumen.
  Future<CommandResult> _processResumir(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /resumir...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/resumir');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.resumir,
          'Por favor, proporciona un texto para resumir después de "/resumir".\nEjemplo: /resumir [pegar artículo o texto largo]',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para resumen
      final resumirPrompt = _buildResumirPrompt(content);
      debugPrint('   🎯 Prompt de resumen creado (${resumirPrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = resumirPrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // de resumen sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Resumen recibido de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.resumir, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      return CommandResult.error(
        CommandType.resumir,
        'Error al procesar el comando: ${e.toString()}',
      );
    }
  }

  /// Procesa el comando "/codigo" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando genera código basado en la descripción proporcionada,
  /// incluyendo explicaciones y buenas prácticas.
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con la generación de código.
  Future<CommandResult> _processCodigo(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /codigo...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/codigo');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.codigo,
          'Por favor, describe el código que necesitas después de "/codigo".\nEjemplo: /codigo función para ordenar lista de números',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para generación de código
      final codigoPrompt = _buildCodigoPrompt(content);
      debugPrint('   🎯 Prompt de código creado (${codigoPrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = codigoPrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // de código sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Código recibido de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.codigo, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      return CommandResult.error(
        CommandType.codigo,
        'Error al procesar el comando: ${e.toString()}',
      );
    }
  }

  /// Procesa el comando "/corregir" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando corrige errores ortográficos, gramaticales y de estilo
  /// en el texto proporcionado, explicando las correcciones realizadas.
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con la corrección.
  Future<CommandResult> _processCorregir(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /corregir...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/corregir');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.corregir,
          'Por favor, escribe el texto a corregir después de "/corregir".\nEjemplo: /corregir Este es un teksto con herrores',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para corrección
      final corregirPrompt = _buildCorregirPrompt(content);
      debugPrint('   🎯 Prompt de corrección creado (${corregirPrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = corregirPrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // de corrección sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Corrección recibida de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.corregir, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      return CommandResult.error(
        CommandType.corregir,
        'Error al procesar el comando: ${e.toString()}',
      );
    }
  }

  /// Procesa el comando "/explicar" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando explica conceptos de forma clara y didáctica,
  /// adaptándose al nivel de conocimiento del usuario.
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con la explicación.
  Future<CommandResult> _processExplicar(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /explicar...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/explicar');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.explicar,
          'Por favor, indica qué concepto quieres que explique después de "/explicar".\nEjemplo: /explicar ¿Qué es async/await?',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para explicación
      final explicarPrompt = _buildExplicarPrompt(content);
      debugPrint('   🎯 Prompt de explicación creado (${explicarPrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = explicarPrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // de explicación sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Explicación recibida de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.explicar, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      return CommandResult.error(
        CommandType.explicar,
        'Error al procesar el comando: ${e.toString()}',
      );
    }
  }

  /// Procesa el comando "/comparar" usando la IA seleccionada SIN HISTORIAL
  /// 
  /// Este comando compara dos opciones o conceptos de forma objetiva,
  /// destacando ventajas, desventajas y casos de uso.
  /// 
  /// **IMPORTANTE:** Usa `generateContentWithoutHistory` para evitar que mensajes
  /// anteriores interfieran con la comparación.
  Future<CommandResult> _processComparar(String message) async {
    try {
      debugPrint('🔧 [CommandProcessor] Procesando comando /comparar...');
      
      // Extraer el contenido después del comando
      final content = _extractContentAfterCommand(message, '/comparar');
      
      if (content.isEmpty) {
        debugPrint('   ⚠️ Comando sin contenido');
        return CommandResult.error(
          CommandType.comparar,
          'Por favor, indica qué opciones quieres comparar después de "/comparar".\nEjemplo: /comparar Flutter vs React Native',
        );
      }

      debugPrint('   📄 Contenido extraído: ${content.length > 50 ? "${content.substring(0, 50)}..." : content}');
      
      // Construir el prompt especializado para comparación
      final compararPrompt = _buildCompararPrompt(content);
      debugPrint('   🎯 Prompt de comparación creado (${compararPrompt.length} caracteres)');

      // Normalizar espacios antes de enviar a la IA
      final trimmedPrompt = compararPrompt.trim();
      
      debugPrint('   🤖 Enviando a la IA seleccionada SIN HISTORIAL...');
      debugPrint('   ⚡ Usando generateContentWithoutHistory para evitar interferencia del historial');
      
      // CRÍTICO: Usar generateContentWithoutHistory para que solo se envíe el prompt
      // de comparación sin ningún mensaje anterior de la conversación
      final response = await _aiService.generateContentWithoutHistory(trimmedPrompt);
      
      debugPrint('   ✅ Comparación recibida de la IA (${response.length} caracteres)');

      return CommandResult.success(CommandType.comparar, response);
    } catch (e) {
      debugPrint('   ❌ Error procesando comando: $e');
      return CommandResult.error(
        CommandType.comparar,
        'Error al procesar el comando: ${e.toString()}',
      );
    }
  }

  /// Extrae el contenido después del comando
  String _extractContentAfterCommand(String message, String command) {
    final startIndex = message.toLowerCase().indexOf(command.toLowerCase());
    if (startIndex == -1) return '';
    
    final contentStart = startIndex + command.length;
    return message.substring(contentStart).trim();
  }

  /// Construye el prompt especializado para evaluación y mejora de prompts
  /// 
  /// Este prompt instruye a la IA para que analice y mejore el prompt del usuario,
  /// identificando los tres componentes clave: Task, Context y Referencias
  String _buildEvaluarPromptPrompt(String userContent) {
    return '''
Actúa como un evaluador y mejorador de prompts para el prompt que adjunto como "Mensaje del usuario". No repitas tu función ni el mensaje del usuario, céntrate en mejorar el prompt. 
El usuario mandará un prompt para que lo evalúes y mejores, para cada caso, debes identificar los tres pasos que cualquier prompt debería tener:
1. Task 
2. Context
3. Referencias

Si cualquiera de las tres partes es faltante o deficiente, debes indicar al usuario como mejorarlo, haciendo las preguntas generales para que el usuario las conteste en el tema en específico del que trate el prompt.

Estos son los pasos que debes cumplir para evaluar y mejorar el prompt:

**Instrucciones:**
1. **Identifica el objetivo principal** cuál es el objetivo que este prompt busca que tú (la IA) cumplas.
2. **Tamaño y complejidad del objetivo:** ¿Es el objetivo que el prompt propone grande y complicado para la IA?  Si es así, ¿como desglosarlo en objetivos mas pequeños?
3. **Estructura y expresión del prompt:** ¿Está este prompt bien estructurado y expresado para lograr su objetivo de manera efectiva?    
4. **Necesidades de un prompt complejo:** Si el objetivo es grande y/o complicado, ¿incluye este prompt un contexto completo, instrucciones claras y por pasos, ejemplos relevantes y un formato de respuesta adecuado para la IA?
5. **Añade una referencias adecuadas para el resultado:** ¿Que tipo de estructura quieres que tenga la respuesta (lista, tabla, párrafos)? ¿Que tono, longitud y estilo? Es necesario un ejemplo claro de respuesta?
6. **Reescribe el prompt mejorado** incorporando todas las mejoras que hayas señalado. Asegúrate de que el prompt resultante sea claro y completo. Proporciona este prompt mejorado en un formato markdown. Todas las partes que deban ser reemplazadas o completadas por el usuario estaran entre corchetes [].

**Restricciones:**
* Tu respuesta no debe superar los 4000 tokens.
* Céntrate en la explicación de las mejoras y en la generación del prompt mejorado, sin dar rodeos o información superflua en el formato de la explicación.

**Mensaje del usuario:**
$userContent

**Fin del mensaje del usuario.**
''';
  }

  /// Construye el prompt especializado para traducción
  /// 
  /// Este prompt instruye a la IA para que traduzca manteniendo la intención,
  /// tono, registro y significado original del texto. Detecta automáticamente
  /// el idioma de destino o usa inglés por defecto.
  String _buildTraducirPrompt(String userContent) {
  final lowerContent = userContent.toLowerCase();
  
  // Valores por defecto
  String targetLanguage = 'inglés'; // Idioma por defecto (ya en español)
  String textToTranslate = userContent;
  bool languageFound = false;

  // Iterar sobre la lista estructurada de idiomas
  for (final langData in languages) {
    
    // 1. Crear una lista de todas las posibles variaciones para este idioma
    final variations = [
      langData['spanish'],
      langData['english'],
      langData['native'],
      langData['iso639_1'],
      langData['iso639_3'],
    ]
        .whereType<String>() // Filtrar nulos (si alguna clave no existe)
        .where((s) => s.isNotEmpty) // Filtrar vacíos
        .map((s) => s.toLowerCase()) // Convertir a minúsculas
        .toList();

    // 2. Ordenar las variaciones por longitud, de mayor a menor
    //    Esto es CRUCIAL para que "español" se detecte antes que "es"
    variations.sort((a, b) => b.length.compareTo(a.length));

    // 3. Comprobar cada variación
    for (final variation in variations) {
      if (lowerContent.startsWith(variation)) {
        // 4. Comprobar límite de palabra:
        //    Debe ser seguido por un espacio o ser el final del texto.
        //    Esto evita que "en" (inglés) coincida con "entiendo que..."
        final isWordBoundary = lowerContent.length == variation.length || 
                              lowerContent[variation.length] == ' ';
        
        if (isWordBoundary) {
          // ¡Coincidencia encontrada!
          
          // REQUISITO CUMPLIDO:
          // Asignar la versión en ESPAÑOL del idioma al prompt
          targetLanguage = langData['spanish']!; // Usamos '!' porque sabemos que 'spanish' existe

          // Extraer el texto después del idioma
          textToTranslate = userContent.substring(variation.length).trim();
          
          languageFound = true;
          break; // Salir del bucle de variaciones
        }
      }
    }

    if (languageFound) {
      break; // Salir del bucle principal de idiomas
    }
  }
    
    return '''
Actúa como un traductor experto especializado en lenguaje natural y contexto conversacional.  
Tu tarea es traducir el texto proporcionado por el usuario al **$targetLanguage**, manteniendo **la intención, el tono, el registro, y el significado original**.  
Evita traducciones literales o robóticas: prioriza la **fidelidad semántica y expresiva**.  

**Instrucciones específicas:**
1. Si el texto incluye expresiones idiomáticas, regionalismos o metáforas, tradúcelas a equivalentes naturales en $targetLanguage.
2. Si hay ambigüedad, conserva el sentido más probable según el contexto.
3. Mantén el formato del texto original (listas, negritas, comillas, etc.).
4. No expliques tu traducción, simplemente ofrece la versión traducida.
5. Si el texto incluye partes que no deberían traducirse (por ejemplo, nombres propios, comandos o código), déjalos tal cual.
6. Si el texto ya está en $targetLanguage, indícalo al usuario brevemente y devuelve el texto sin cambios.

**Texto a traducir:**
$textToTranslate

**Fin del texto a traducir.**
''';
  }

  /// Construye el prompt especializado para resumir textos
  /// 
  /// Este prompt instruye a la IA para que extraiga las ideas principales
  /// y las presente de forma clara, concisa y estructurada.
  String _buildResumirPrompt(String userContent) {
    return '''
Actúa como un experto en síntesis y análisis de textos.  
Tu tarea es crear un **resumen claro y conciso** del texto proporcionado, extrayendo las ideas principales y eliminando información redundante o poco relevante.

**Instrucciones específicas:**
1. **Identifica las ideas principales:** Extrae los conceptos clave, argumentos centrales y conclusiones importantes.
2. **Mantén la objetividad:** No agregues opiniones personales ni interpretaciones que no estén en el texto original.
3. **Estructura clara:** Organiza el resumen de forma lógica con párrafos cortos o puntos clave según la longitud del texto.
4. **Longitud del resumen:** 
   - Para textos cortos (< 500 palabras): 3-5 líneas
   - Para textos medianos (500-2000 palabras): 1-2 párrafos
   - Para textos largos (> 2000 palabras): 3-4 párrafos con ideas principales
5. **Conserva términos técnicos:** Si el texto incluye terminología especializada importante, mantenla en el resumen.
6. **Claridad:** El resumen debe ser comprensible para alguien que no haya leído el texto original.

**Restricciones:**
* No incluyas frases como "el texto habla de" o "el autor menciona"
* Ve directo al contenido
* Mantén el tono profesional y objetivo

**Texto a resumir:**
$userContent

**Fin del texto a resumir.**
''';
  }

  /// Construye el prompt especializado para generar código
  /// 
  /// Este prompt instruye a la IA para que genere código limpio, bien documentado
  /// y siguiendo las mejores prácticas del lenguaje o tecnología solicitada.
  String _buildCodigoPrompt(String userContent) {
    return '''
Actúa como un desarrollador experto y mentor de programación.  
Tu tarea es generar código de alta calidad basado en la descripción proporcionada por el usuario.

**Instrucciones específicas:**
1. **Detecta el lenguaje/tecnología:** Si el usuario no especifica, infiere el lenguaje más apropiado según la descripción o pregunta cuál prefiere.
2. **Código limpio y legible:** 
   - Usa nombres descriptivos para variables y funciones
   - Aplica las convenciones del lenguaje
   - Mantén la consistencia en el estilo
3. **Documentación:**
   - Incluye comentarios explicativos en partes complejas
   - Agrega docstrings o documentación según el lenguaje
4. **Buenas prácticas:**
   - Manejo de errores apropiado
   - Código modular y reutilizable
   - Eficiencia y optimización cuando sea relevante
5. **Explicación breve:** Después del código, incluye una breve explicación de cómo funciona y cómo usarlo.
6. **Ejemplos de uso:** Si es apropiado, incluye ejemplos de cómo ejecutar o usar el código.

**Restricciones:**
* El código debe ser funcional y estar probado conceptualmente
* Evita soluciones excesivamente complejas
* Si falta información crítica, indica qué necesitas saber

**Descripción del código solicitado:**
$userContent

**Fin de la descripción.**
''';
  }

  /// Construye el prompt especializado para corregir textos
  /// 
  /// Este prompt instruye a la IA para que identifique y corrija errores
  /// ortográficos, gramaticales y de estilo, explicando las correcciones.
  String _buildCorregirPrompt(String userContent) {
    return '''
Actúa como un corrector profesional de textos y experto en gramática y ortografía.  
Tu tarea es corregir todos los errores del texto proporcionado y mejorar su claridad y fluidez.

**Instrucciones específicas:**
1. **Tipos de correcciones:**
   - Ortografía: tildes, letras incorrectas, mayúsculas
   - Gramática: concordancia, tiempos verbales, estructura sintáctica
   - Puntuación: comas, puntos, signos de interrogación/exclamación
   - Estilo: repeticiones innecesarias, ambigüedades, claridad
2. **Formato de respuesta:**
   - **Texto corregido:** Presenta primero el texto completamente corregido
   - **Explicación de cambios:** Después, enumera los principales errores encontrados y por qué se corrigieron
3. **Mantén el sentido original:** No cambies el mensaje o intención del autor
4. **Respeta el tono:** Si el texto es formal, mantén la formalidad; si es informal, mantenlo así
5. **Mejoras de estilo:** Solo si es necesario, sugiere mejoras opcionales para mayor claridad

**Restricciones:**
* No reescribas completamente el texto, solo corrige errores
* Si el texto está perfecto, indícalo claramente
* Sé constructivo en las explicaciones

**Texto a corregir:**
$userContent

**Fin del texto a corregir.**
''';
  }

  /// Construye el prompt especializado para explicar conceptos
  /// 
  /// Este prompt instruye a la IA para que explique conceptos de forma
  /// didáctica, clara y adaptada al nivel del usuario.
  String _buildExplicarPrompt(String userContent) {
    return '''
Actúa como un profesor experto y comunicador claro.  
Tu tarea es explicar el concepto solicitado de forma didáctica, comprensible y completa.

**Instrucciones específicas:**
1. **Estructura de la explicación:**
   - **Definición simple:** Comienza con una explicación básica en 1-2 frases
   - **Desarrollo:** Profundiza en el concepto con más detalles
   - **Ejemplos prácticos:** Incluye ejemplos concretos y relatable
   - **Analogías:** Si ayuda, usa analogías con situaciones cotidianas
2. **Adaptación del nivel:**
   - Comienza con lo básico
   - Aumenta gradualmente la complejidad
   - Evita jerga innecesaria (o explícala si es importante)
3. **Claridad:**
   - Usa párrafos cortos
   - Enumera puntos importantes cuando sea útil
   - Destaca conceptos clave
4. **Contexto:** Si es relevante, menciona por qué este concepto es importante o dónde se aplica
5. **Verificación de comprensión:** Al final, puedes incluir una pregunta o ejercicio simple para reforzar el aprendizaje

**Restricciones:**
* No asumas conocimientos previos avanzados
* Sé preciso pero accesible
* Si el concepto es muy amplio, enfócate en lo esencial primero

**Concepto a explicar:**
$userContent

**Fin del concepto solicitado.**
''';
  }

  /// Construye el prompt especializado para comparar opciones
  /// 
  /// Este prompt instruye a la IA para que compare dos o más opciones
  /// de forma objetiva, equilibrada y estructurada.
  String _buildCompararPrompt(String userContent) {
    return '''
Actúa como un analista objetivo y experto en comparaciones.  
Tu tarea es comparar las opciones proporcionadas de forma equilibrada, destacando ventajas, desventajas y casos de uso apropiados.

**Instrucciones específicas:**
1. **Estructura de la comparación:**
   - **Introducción breve:** Presenta las opciones a comparar
   - **Tabla comparativa (si aplica):** Para características clave
   - **Análisis detallado:** Desarrolla ventajas y desventajas de cada opción
   - **Casos de uso:** Indica cuándo elegir cada opción
   - **Conclusión:** Resume la comparación sin imponer una elección
2. **Criterios de comparación:**
   - Funcionalidad
   - Facilidad de uso
   - Rendimiento
   - Costo (si es relevante)
   - Comunidad y soporte
   - Casos de uso ideales
3. **Objetividad:**
   - Presenta ambos lados de forma equilibrada
   - Evita sesgos personales
   - Reconoce que diferentes opciones son mejores en diferentes contextos
4. **Claridad:**
   - Usa viñetas o tablas para facilitar la lectura
   - Destaca diferencias clave
   - Sé específico con ejemplos concretos

**Restricciones:**
* No declares un "ganador" absoluto a menos que una opción sea claramente superior en todos los aspectos
* Basa las afirmaciones en hechos verificables
* Si falta información para comparar adecuadamente, indícalo

**Opciones a comparar:**
$userContent

**Fin de las opciones.**
''';
  }
}