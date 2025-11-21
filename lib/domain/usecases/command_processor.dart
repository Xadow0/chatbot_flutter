import 'package:flutter/foundation.dart';
import '../../domain/entities/command_entity.dart';
import '../../domain/repositories/command_repository.dart'; // Asegúrate de importar tu repositorio

/// Resultado del procesamiento de un comando
class CommandResult {
  final bool isCommand;
  final CommandEntity? command; // Referencia a la entidad del comando ejecutado
  final String? processedMessage;
  final String? error;

  CommandResult({
    required this.isCommand,
    this.command,
    this.processedMessage,
    this.error,
  });

  factory CommandResult.notCommand() {
    return CommandResult(isCommand: false);
  }

  factory CommandResult.success(CommandEntity command, String message) {
    return CommandResult(
      isCommand: true,
      command: command,
      processedMessage: message,
    );
  }

  factory CommandResult.error(CommandEntity? command, String error) {
    return CommandResult(
      isCommand: true,
      command: command,
      error: error,
    );
  }
}

abstract class AIServiceBase {
  Future<String> generateContent(String prompt);
  Future<String> generateContentWithoutHistory(String prompt);
}

class CommandProcessor {
  final AIServiceBase _aiService;
  final CommandRepository _commandRepository;

  // Lista de idiomas para la lógica de detección (Hardcoded porque es lógica de negocio)
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

  CommandProcessor(this._aiService, this._commandRepository);

  /// Detecta si el mensaje es un comando buscando en la base de datos/repositorio
  Future<CommandResult> processMessage(String message) async {
    final normalizedMessage = message.trim();
    if (!normalizedMessage.startsWith('/')) {
      return CommandResult.notCommand();
    }

    debugPrint('🔍 [CommandProcessor] Analizando mensaje: $normalizedMessage');

    try {
      // 1. Obtener todos los comandos disponibles (Sistema + Usuario)
      final commands = await _commandRepository.getAllCommands();
      
      // 2. Buscar coincidencia con el trigger
      // Ordenamos por longitud desc (para que /traduciringles no coincida con /traducir por error si existieran ambos)
      commands.sort((a, b) => b.trigger.length.compareTo(a.trigger.length));
      
      final matchingCommand = commands.firstWhere(
        (cmd) => normalizedMessage.toLowerCase().startsWith(cmd.trigger.toLowerCase()),
        orElse: () => throw Exception('No match'), // Usamos try/catch para el flujo
      );

      debugPrint('   ✅ Comando detectado: ${matchingCommand.trigger} (${matchingCommand.title})');

      // 3. Enrutar según el tipo de sistema
      switch (matchingCommand.systemType) {
        case SystemCommandType.none:
          return await _processUserCommand(matchingCommand, message);
        
        case SystemCommandType.traducir:
          return await _processTraducir(matchingCommand, message);

        // Los siguientes comparten lógica simple (Template + Contenido),
        // pero mantenemos el switch por si quieres añadir lógica específica a futuro.
        case SystemCommandType.evaluarPrompt:
        case SystemCommandType.resumir:
        case SystemCommandType.codigo:
        case SystemCommandType.corregir:
        case SystemCommandType.explicar:
        case SystemCommandType.comparar:
          return await _processStandardSystemCommand(matchingCommand, message);
      }

    } catch (e) {
      // Si no se encontró comando o hubo error en repositorio
      if (e.toString().contains('No match')) {
         debugPrint('   ℹ️ No es un comando registrado.');
         return CommandResult.notCommand();
      }
      debugPrint('   ❌ Error recuperando comandos: $e');
      return CommandResult.notCommand();
    }
  }

  /// Procesa comandos personalizados del usuario (Simples)
  /// Concatena el Prompt del usuario + el Input actual
  Future<CommandResult> _processUserCommand(CommandEntity command, String message) async {
    try {
      final content = _extractContentAfterCommand(message, command.trigger);
      
      // Si el usuario definió un placeholder {{content}}, lo usamos. Si no, concatenamos.
      String finalPrompt;
      if (command.promptTemplate.contains('{{content}}')) {
        finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);
      } else {
        finalPrompt = '${command.promptTemplate}\n\n$content';
      }

      debugPrint('   🤖 Enviando Prompt Usuario a IA...');
      final response = await _aiService.generateContentWithoutHistory(finalPrompt);
      return CommandResult.success(command, response);
    } catch (e) {
      return CommandResult.error(command, 'Error ejecutando comando: $e');
    }
  }

  /// Procesa comandos estándar del sistema que solo requieren inyección de contenido
  /// (Evaluar, Resumir, Código, Corregir, Explicar, Comparar)
  Future<CommandResult> _processStandardSystemCommand(CommandEntity command, String message) async {
    try {
      final content = _extractContentAfterCommand(message, command.trigger);
      
      if (content.isEmpty) {
        return CommandResult.error(command, 'Por favor, añade el contenido después del comando.');
      }

      // Inyectamos el contenido en el template que viene del Modelo/Firebase
      final finalPrompt = command.promptTemplate.replaceAll('{{content}}', content);

      debugPrint('   🤖 Enviando Prompt Sistema (${command.title}) a IA...');
      final response = await _aiService.generateContentWithoutHistory(finalPrompt);
      return CommandResult.success(command, response);
    } catch (e) {
      return CommandResult.error(command, 'Error: $e');
    }
  }

  /// Lógica avanzada específica para TRADUCIR (Mantiene tu algoritmo original)
  Future<CommandResult> _processTraducir(CommandEntity command, String message) async {
    try {
      final contentRaw = _extractContentAfterCommand(message, command.trigger);
      if (contentRaw.isEmpty) {
        return CommandResult.error(command, 'Uso: ${command.trigger} [idioma opcional] [texto]');
      }

      final lowerContent = contentRaw.toLowerCase();
      String targetLanguage = 'inglés'; // Default
      String textToTranslate = contentRaw;
      bool languageFound = false;

      // --- TU LÓGICA DE DETECCIÓN DE IDIOMA ORIGINAL ---
      for (final langData in languages) {
        final variations = [
          langData['spanish'], langData['english'], langData['native'],
          langData['iso639_1'], langData['iso639_3'],
        ].whereType<String>().where((s) => s.isNotEmpty).map((s) => s.toLowerCase()).toList();

        variations.sort((a, b) => b.length.compareTo(a.length));

        for (final variation in variations) {
          if (lowerContent.startsWith(variation)) {
            final isWordBoundary = lowerContent.length == variation.length || 
                                  lowerContent[variation.length] == ' ';
            if (isWordBoundary) {
              targetLanguage = langData['spanish']!; 
              textToTranslate = contentRaw.substring(variation.length).trim();
              languageFound = true;
              break;
            }
          }
        }
        if (languageFound) break;
      }
      // ---------------------------------------------------

      if (textToTranslate.isEmpty) {
         return CommandResult.error(command, 'Falta el texto a traducir.');
      }

      // Usamos el template del Modelo (entity) y reemplazamos las DOS variables
      final finalPrompt = command.promptTemplate
          .replaceAll('{{targetLanguage}}', targetLanguage)
          .replaceAll('{{content}}', textToTranslate);

      debugPrint('   🌍 Traduciendo a: $targetLanguage');
      final response = await _aiService.generateContentWithoutHistory(finalPrompt);
      return CommandResult.success(command, response);

    } catch (e) {
      return CommandResult.error(command, 'Error de traducción: $e');
    }
  }

  String _extractContentAfterCommand(String message, String trigger) {
    // Aseguramos case-insensitive matching para el trigger
    final msgLower = message.toLowerCase();
    final trigLower = trigger.toLowerCase();
    
    final index = msgLower.indexOf(trigLower);
    if (index == -1) return message; // Fallback raro
    
    final contentStart = index + trigger.length;
    if (contentStart >= message.length) return '';
    
    return message.substring(contentStart).trim();
  }
}