class CommandsHelp {
  static const String probarPrompt = '''
📝 Comando: probar prompt

Uso: probar prompt [tu pregunta o texto]

Descripción:
Este comando envía tu mensaje a la IA de Gemini con un contexto mejorado para obtener respuestas más precisas y útiles.

Ejemplos:
• probar prompt ¿Qué es Flutter?
• probar prompt Explica qué son los widgets
• probar prompt Dame consejos para aprender programación

Nota: La primera vez puede tardar unos segundos en responder.
''';

  static String getAllCommands() {
    return '''
🤖 Comandos Disponibles

1. probar prompt [texto]
   Envía tu mensaje a Gemini AI para obtener respuestas inteligentes.
   
   Ejemplo: probar prompt ¿Cómo funciona Flutter?

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

💡 Más comandos próximamente:
• /traductor - Traducir texto
• /resumen - Resumir contenido
• /codigo - Generar código
• /corregir - Corregir gramática

Escribe "ayuda" para ver esta información.
''';
  }
}