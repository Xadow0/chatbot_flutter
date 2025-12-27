class CommandsHelp {
  static const String evaluarPrompt = '''
📝 Comando: /evaluarprompt

Uso: /evaluarprompt [tu pregunta o texto]

Descripción:
Este comando evalúa y mejora tu prompt, analizando si tiene los componentes necesarios (Task, Context, Referencias) y proporcionando sugerencias de mejora.

Ejemplos:
• /evaluarprompt ¿Qué es Flutter?
• /evaluarprompt Explica qué son los widgets
• /evaluarprompt Dame consejos para aprender programación

Nota: La primera vez puede tardar unos segundos en responder.
''';

  static const String traducir = '''
🌐 Comando: /traducir

Uso: /traducir [idioma] [texto a traducir]
      /traducir [texto a traducir]  (traduce al inglés por defecto)

Descripción:
Este comando traduce tu texto al idioma especificado manteniendo la intención, el tono y el significado original. No hace traducciones literales, sino que busca equivalentes naturales.

Idiomas soportados:
Inglés, español, francés, alemán, italiano, portugués, chino, japonés, coreano, ruso, árabe

Ejemplos:
• /traducir inglés Hola, ¿cómo estás?
• /traducir francés Me gusta mucho este proyecto
• /traducir Esto está chupado
• /traducir japonés Buenos días

Características:
• Mantiene expresiones idiomáticas
• Conserva el formato original
• Respeta nombres propios y código
• No explica, solo traduce

Nota: La traducción es contextual y expresiva.
''';

  static const String resumir = '''
📋 Comando: /resumir

Uso: /resumir [texto largo]

Descripción:
Este comando resume textos largos extrayendo las ideas principales y presentándolas de forma clara y concisa. Ideal para artículos, documentos o textos extensos.

Ejemplos:
• /resumir [pegar artículo completo]
• /resumir [pegar capítulo de libro]
• /resumir [pegar documento técnico]

Características:
• Extrae ideas principales
• Mantiene objetividad
• Estructura clara y organizada
• Conserva términos técnicos importantes
• Adapta longitud según el texto original

Nota: Cuanto más largo el texto, más detallado será el resumen.
''';

  static const String codigo = '''
💻 Comando: /codigo

Uso: /codigo [descripción de lo que necesitas]

Descripción:
Este comando genera código limpio y bien documentado basado en tu descripción. Incluye explicaciones y ejemplos de uso siguiendo las mejores prácticas.

Ejemplos:
• /codigo función para ordenar lista de números
• /codigo componente React de formulario de login
• /codigo script Python para leer archivos CSV
• /codigo algoritmo de búsqueda binaria en Java

Características:
• Detecta el lenguaje apropiado (o pregunta si es necesario)
• Código limpio y legible
• Comentarios explicativos
• Buenas prácticas y manejo de errores
• Ejemplos de uso incluidos

Nota: El código generado es funcional y sigue convenciones estándar.
''';

  static const String corregir = '''
✍️ Comando: /corregir

Uso: /corregir [texto con errores]

Descripción:
Este comando corrige errores ortográficos, gramaticales y de estilo en tu texto, y explica qué se corrigió y por qué.

Ejemplos:
• /corregir Este es un teksto con herrores
• /corregir Ayer fuimos al cine y veiamos una pelicula
• /corregir el projectos esta casi terminado

Tipos de correcciones:
• Ortografía (tildes, letras, mayúsculas)
• Gramática (concordancia, tiempos verbales)
• Puntuación (comas, puntos, signos)
• Estilo (claridad, repeticiones)

Características:
• Texto corregido completo
• Explicación de cambios realizados
• Mantiene el sentido original
• Respeta el tono del texto
• Sugerencias opcionales de mejora

Nota: Si el texto está perfecto, te lo indicará.
''';

  static const String explicar = '''
🎓 Comando: /explicar

Uso: /explicar [concepto o pregunta]

Descripción:
Este comando explica conceptos de forma clara, didáctica y fácil de entender. Ideal para aprender nuevos temas o aclarar dudas.

Ejemplos:
• /explicar ¿Qué es async/await?
• /explicar diferencia entre let, const y var en JavaScript
• /explicar cómo funciona la memoria RAM
• /explicar ¿Qué es machine learning?

Características:
• Definición simple inicial
• Desarrollo profundo del tema
• Ejemplos prácticos y analogías
• Progresión de básico a avanzado
• Sin jerga innecesaria

Nota: Las explicaciones son progresivas y accesibles para todos los niveles.
''';

  static const String comparar = '''
⚖️ Comando: /comparar

Uso: /comparar [opción A] vs [opción B]
      /comparar [opción A], [opción B] y [opción C]

Descripción:
Este comando compara dos o más opciones de forma objetiva, destacando ventajas, desventajas y casos de uso apropiados para cada una.

Ejemplos:
• /comparar Flutter vs React Native
• /comparar Python vs JavaScript
• /comparar MySQL vs PostgreSQL vs MongoDB
• /comparar Docker vs máquinas virtuales

Características:
• Análisis equilibrado y objetivo
• Tabla comparativa de características
• Ventajas y desventajas de cada opción
• Casos de uso ideales
• Conclusión sin sesgos

Criterios incluidos:
• Funcionalidad
• Facilidad de uso
• Rendimiento
• Comunidad y soporte
• Casos de uso apropiados

Nota: La comparación es neutral y ayuda a tomar decisiones informadas.
''';

  static String getAllCommands() {
    return '''
🤖 Comandos Disponibles

1. /evaluarprompt [texto]
   Evalúa tu prompt y obtén una versión mejorada de él, identificando Tarea, Contexto y Referencias.
   
   Ejemplo: /evaluarprompt Explícame programación funcional

2. /traducir [idioma] [texto]
   Traduce tu texto al idioma especificado (inglés por defecto) manteniendo intención y tono.
   
   Ejemplo: /traducir inglés Me encanta programar en Flutter

3. /resumir [texto largo]
   Resume textos extensos extrayendo las ideas principales de forma clara y concisa.
   
   Ejemplo: /resumir [pegar artículo completo aquí]

4. /codigo [descripción]
   Genera código limpio y documentado basado en tu descripción con ejemplos de uso.
   
   Ejemplo: /codigo función para ordenar array de objetos

5. /corregir [texto]
   Corrige errores ortográficos, gramaticales y de estilo explicando los cambios.
   
   Ejemplo: /corregir Este es un teksto con herrores

6. /explicar [concepto]
   Explica conceptos de forma didáctica con ejemplos y analogías fáciles de entender.
   
   Ejemplo: /explicar ¿Qué es async/await?

7. /comparar [opción A] vs [opción B]
   Compara opciones objetivamente con ventajas, desventajas y casos de uso.
   
   Ejemplo: /comparar Flutter vs React Native

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Escribe "ayuda" o "comandos" para ver esta información.
''';
  }

  /// Obtiene la ayuda de un comando específico
  static String? getCommandHelp(String command) {
    switch (command.toLowerCase()) {
      case '/evaluarprompt':
      case 'evaluarprompt':
        return evaluarPrompt;
      case '/traducir':
      case 'traducir':
        return traducir;
      case '/resumir':
      case 'resumir':
        return resumir;
      case '/codigo':
      case 'codigo':
      case 'código':
        return codigo;
      case '/corregir':
      case 'corregir':
        return corregir;
      case '/explicar':
      case 'explicar':
        return explicar;
      case '/comparar':
      case 'comparar':
        return comparar;
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
- **Ollama Local** - 100% privado en tu PC. El primer uso debe instalar la aplicación Ollama,
y descargar el modelo elegido localmente, por lo que tardará unos minutos en estar listo.

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

${getAllCommands()}

¿En qué puedo ayudarte hoy?
''';
  }
}