import '../../domain/entities/command_entity.dart';

class CommandModel extends CommandEntity {
  const CommandModel({
    required super.id,
    required super.trigger,
    required super.title,
    required super.description,
    required super.promptTemplate,
    super.isSystem,
    super.systemType,
    super.isEditable,
    super.folderId,
  });

  factory CommandModel.fromJson(Map<String, dynamic> json) {
    return CommandModel(
      id: json['id'] as String,
      trigger: json['trigger'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      promptTemplate: json['promptTemplate'] as String,
      isSystem: json['isSystem'] as bool? ?? false,
      systemType: _stringToEnum(json['systemType'] as String?),
      isEditable: json['isEditable'] as bool? ?? false,
      folderId: json['folderId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trigger': trigger,
      'title': title,
      'description': description,
      'promptTemplate': promptTemplate,
      'isSystem': isSystem,
      'systemType': systemType.name,
      'isEditable': isEditable,
      'folderId': folderId,
    };
  }

  factory CommandModel.fromEntity(CommandEntity entity) {
    return CommandModel(
      id: entity.id,
      trigger: entity.trigger,
      title: entity.title,
      description: entity.description,
      promptTemplate: entity.promptTemplate,
      isSystem: entity.isSystem,
      systemType: entity.systemType,
      isEditable: entity.isEditable,
      folderId: entity.folderId,
    );
  }

  @override
  CommandModel copyWith({
    String? id,
    String? trigger,
    String? title,
    String? description,
    String? promptTemplate,
    bool? isSystem,
    SystemCommandType? systemType,
    bool? isEditable,
    String? folderId,
    bool clearFolderId = false,
  }) {
    return CommandModel(
      id: id ?? this.id,
      trigger: trigger ?? this.trigger,
      title: title ?? this.title,
      description: description ?? this.description,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      isSystem: isSystem ?? this.isSystem,
      systemType: systemType ?? this.systemType,
      isEditable: isEditable ?? this.isEditable,
      folderId: clearFolderId ? null : (folderId ?? this.folderId),
    );
  }

  static SystemCommandType _stringToEnum(String? value) {
    if (value == null) return SystemCommandType.none;
    try {
      return SystemCommandType.values.firstWhere(
        (e) => e.name == value,
        orElse: () => SystemCommandType.none,
      );
    } catch (_) {
      return SystemCommandType.none;
    }
  }

  /// Retorna los comandos por defecto con sus PROMPTS COMPLETOS y placeholders.
  /// Las variables dinámicas (como el idioma detectado) se representan con {{variable}}.
  /// 
  /// NOTA: Los comandos del sistema siempre son NO editables (isEditable: false)
  /// ya que tienen lógica especial de procesamiento.
  static List<CommandModel> getDefaultCommands() {
    return [
      // --- EVALUAR PROMPT ---
      const CommandModel(
        id: 'cmd_evaluar',
        trigger: '/evaluarprompt',
        title: 'Evaluar Prompt',
        description: 'Evalúa y mejora tu prompt identificando Task, Context y Referencias.',
        isSystem: true,
        systemType: SystemCommandType.evaluarPrompt,
        isEditable: false,
        promptTemplate: '''
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
{{content}}

**Fin del mensaje del usuario.**
''',
      ),

      // --- TRADUCIR ---
      const CommandModel(
        id: 'cmd_traducir',
        trigger: '/traducir',
        title: 'Traducir Texto',
        description: 'Traduce texto manteniendo intención y tono. Detecta idiomas automáticamente.',
        isSystem: true,
        systemType: SystemCommandType.traducir,
        isEditable: false,
        promptTemplate: '''
Actúa como un traductor experto especializado en lenguaje natural y contexto conversacional.  
Tu tarea es traducir el texto proporcionado por el usuario al **{{targetLanguage}}**, manteniendo **la intención, el tono, el registro, y el significado original**.  
Evita traducciones literales o robóticas: prioriza la **fidelidad semántica y expresiva**.  

**Instrucciones específicas:**
1. Si el texto incluye expresiones idiomáticas, regionalismos o metáforas, tradúcelas a equivalentes naturales en {{targetLanguage}}.
2. Si hay ambigüedad, conserva el sentido más probable según el contexto.
3. Mantén el formato del texto original (listas, negritas, comillas, etc.).
4. No expliques tu traducción, simplemente ofrece la versión traducida.
5. Si el texto incluye partes que no deberían traducirse (por ejemplo, nombres propios, comandos o código), déjalos tal cual.
6. Si el texto ya está en {{targetLanguage}}, indícalo al usuario brevemente y devuelve el texto sin cambios.

**Texto a traducir:**
{{content}}

**Fin del texto a traducir.**
''',
      ),

      // --- RESUMIR ---
      const CommandModel(
        id: 'cmd_resumir',
        trigger: '/resumir',
        title: 'Resumir Texto',
        description: 'Resume textos largos extrayendo ideas principales de forma clara y concisa.',
        isSystem: true,
        systemType: SystemCommandType.resumir,
        isEditable: false,
        promptTemplate: '''
Actúa como un experto en síntesis y análisis de textos.  
Tu tarea es crear un **resumen claro y conciso** del texto proporcionado, extrayendo las ideas principales y eliminando información redundante o poco relevante.

**Instrucciones específicas:**
1. **Identifica las ideas principales:** Extrae los conceptos clave, argumentos centrales y conclusiones importantes.
2. **Mantén la objetividad:** No agregues opiniones personales ni interpretaciones que no estén en el texto original.
3. **Estructura clara:** Organiza el resumen de forma lógica con párrafos cortos o puntos clave según la longitud del texto.
4. **Longitud del resumen:** - Para textos cortos (< 500 palabras): 3-5 líneas
   - Para textos medianos (500-2000 palabras): 1-2 párrafos
   - Para textos largos (> 2000 palabras): 3-4 párrafos con ideas principales
5. **Conserva términos técnicos:** Si el texto incluye terminología especializada importante, mantenla en el resumen.
6. **Claridad:** El resumen debe ser comprensible para alguien que no haya leído el texto original.

**Restricciones:**
* No incluyas frases como "el texto habla de" o "el autor menciona"
* Ve directo al contenido
* Mantén el tono profesional y objetivo

**Texto a resumir:**
{{content}}

**Fin del texto a resumir.**
''',
      ),

      // --- CÓDIGO ---
      const CommandModel(
        id: 'cmd_codigo',
        trigger: '/codigo',
        title: 'Generar Código',
        description: 'Genera código limpio y documentado basado en tu descripción.',
        isSystem: true,
        systemType: SystemCommandType.codigo,
        isEditable: false,
        promptTemplate: '''
Actúa como un desarrollador experto y mentor de programación.  
Tu tarea es generar código de alta calidad basado en la descripción proporcionada por el usuario.

**Instrucciones específicas:**
1. **Detecta el lenguaje/tecnología:** Si el usuario no especifica, infiere el lenguaje más apropiado según la descripción e indícalo al usuario.
2. **Código limpio y legible:** - Usa nombres descriptivos para variables y funciones
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
{{content}}

**Fin de la descripción.**
''',
      ),

      // --- CORREGIR ---
      const CommandModel(
        id: 'cmd_corregir',
        trigger: '/corregir',
        title: 'Corregir Texto',
        description: 'Corrección ortográfica, gramatical y de estilo con explicación de cambios.',
        isSystem: true,
        systemType: SystemCommandType.corregir,
        isEditable: false,
        promptTemplate: '''
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
{{content}}

**Fin del texto a corregir.**
''',
      ),

      // --- EXPLICAR ---
      const CommandModel(
        id: 'cmd_explicar',
        trigger: '/explicar',
        title: 'Explicar Concepto',
        description: 'Explica conceptos de forma didáctica, progresiva y con ejemplos.',
        isSystem: true,
        systemType: SystemCommandType.explicar,
        isEditable: false,
        promptTemplate: '''
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
{{content}}

**Fin del concepto solicitado.**
''',
      ),

      // --- COMPARAR ---
      const CommandModel(
        id: 'cmd_comparar',
        trigger: '/comparar',
        title: 'Comparar Opciones',
        description: 'Compara dos o más opciones destacando ventajas, desventajas y casos de uso.',
        isSystem: true,
        systemType: SystemCommandType.comparar,
        isEditable: false,
        promptTemplate: '''
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
{{content}}

**Fin de las opciones.**
''',
      ),
    ];
  }
}