class CommandsHelp {
  static const String probarPrompt = '''
📝 Comando: /tryprompt

Uso: /tryprompt [tu pregunta o texto]

Descripción:
Este comando evalúa y mejora tu prompt, analizando si tiene los componentes necesarios (Task, Context, Referencias) y proporcionando sugerencias de mejora.

Ejemplos:
• /tryprompt ¿Qué es Flutter?
• /tryprompt Explica qué son los widgets
• /tryprompt Dame consejos para aprender programación

Nota: La primera vez puede tardar unos segundos en responder.
''';

  static const String translate = '''
🌐 Comando: /translate

Uso: /translate [texto a traducir]

Descripción:
Este comando traduce tu texto al inglés manteniendo la intención, el tono y el significado original. No hace traducciones literales, sino que busca equivalentes naturales.

Ejemplos:
• /translate Hola, ¿cómo estás?
• /translate Me gusta mucho este proyecto
• /translate Esto está chupado

Características:
• Mantiene expresiones idiomáticas
• Conserva el formato original
• Respeta nombres propios y código
• No explica, solo traduce

Nota: La traducción es contextual y expresiva.
''';

  static String getAllCommands() {
    return '''
🤖 Comandos Disponibles

1. /tryprompt [texto]
   Evalúa tu prompt y obtén una versión mejorada de él, identificando Tarea, Contexto y Referencias.
   
   Ejemplo: /tryprompt Explícame programación funcional

2. /translate [texto]
   Traduce tu texto al inglés manteniendo intención y tono para utilizar inteligencias artificiales que tengan mejores resultados en este idioma.
   
   Ejemplo: /translate Me encanta programar en Flutter

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Escribe "ayuda" o "comandos" para ver esta información.
''';
  }

  /// Obtiene la ayuda de un comando específico
  static String? getCommandHelp(String command) {
    switch (command.toLowerCase()) {
      case '/tryprompt':
      case 'tryprompt':
        return probarPrompt;
      case '/translate':
      case 'translate':
        return translate;
      default:
        return null;
    }
  }

  /// Genera el mensaje de bienvenida completo para nuevos chats
  static String getWelcomeMessage() {
    return '''
¡Bienvenido al chat! 🎉

Soy tu asistente de aprendizaje de IA y Prompting.

**Proveedores disponibles:**
- **Gemini** - IA de Google (rápida y potente)
- **OpenAI** - ChatGPT (el más conocido)
- **Ollama (Remoto)** - Tu propio servidor de IA

**Proveedor privado:**
- **Ollama Local** - 100% privado en tu PC (sin instalación, embebido)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${getAllCommands()}

¿En qué puedo ayudarte hoy?
''';
  }
}