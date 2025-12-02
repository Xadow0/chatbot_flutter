import 'package:flutter/material.dart';
import 'dart:async';

enum TechniqueType {
  descomposicion,
  metaPreguntas,
  plantillas,
  practica, // Nueva fase: ejercicio práctico
}

class Module4PracticePage extends StatefulWidget {
  final List<TechniqueType> techniqueSequence;
  final VoidCallback onNext;

  const Module4PracticePage({
    super.key,
    required this.techniqueSequence,
    required this.onNext,
  });

  @override
  State<Module4PracticePage> createState() => _Module4PracticePageState();
}

class _Module4PracticePageState extends State<Module4PracticePage> {
  int _currentTechniqueIndex = 0;

  void _nextTechnique() {
    if (_currentTechniqueIndex < widget.techniqueSequence.length - 1) {
      setState(() {
        _currentTechniqueIndex++;
      });
    } else {
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentTechnique = widget.techniqueSequence[_currentTechniqueIndex];

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Indicador de progreso
          LinearProgressIndicator(
            value: (_currentTechniqueIndex + 1) / widget.techniqueSequence.length,
          ),
          const SizedBox(height: 24),

          Text(
            'Ejercicio ${_currentTechniqueIndex + 1} de ${widget.techniqueSequence.length}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 8),

          Expanded(
            child: _buildTechniqueContent(currentTechnique),
          ),
        ],
      ),
    );
  }

  Widget _buildTechniqueContent(TechniqueType technique) {
    switch (technique) {
      case TechniqueType.descomposicion:
        return AnimatedTechniqueWidget(
          technique: technique,
          onComplete: _nextTechnique,
        );
      case TechniqueType.metaPreguntas:
        return AnimatedTechniqueWidget(
          technique: technique,
          onComplete: _nextTechnique,
        );
      case TechniqueType.plantillas:
        return AnimatedTechniqueWidget(
          technique: technique,
          onComplete: _nextTechnique,
        );
      case TechniqueType.practica:
        return PracticeExerciseWidget(
          onComplete: _nextTechnique,
        );
    }
  }
}

// ============================================================================
// WIDGET DE ANIMACIÓN DIDÁCTICA
// ============================================================================

class AnimatedTechniqueWidget extends StatefulWidget {
  final TechniqueType technique;
  final VoidCallback onComplete;

  const AnimatedTechniqueWidget({
    super.key,
    required this.technique,
    required this.onComplete,
  });

  @override
  State<AnimatedTechniqueWidget> createState() => _AnimatedTechniqueWidgetState();
}

class _AnimatedTechniqueWidgetState extends State<AnimatedTechniqueWidget> {
  int _currentStep = 0;
  bool _animationPaused = false;
  Timer? _animationTimer;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    super.dispose();
  }

  void _startAnimation() {
    final steps = _getStepsForTechnique();
    
    _animationTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (!_animationPaused && mounted) {
        setState(() {
          if (_currentStep < steps.length - 1) {
            _currentStep++;
          } else {
            timer.cancel();
          }
        });
      }
    });
  }

  void _skipAnimation() {
    _animationTimer?.cancel();
    setState(() {
      _currentStep = _getStepsForTechnique().length - 1;
    });
  }

  List<AnimationStep> _getStepsForTechnique() {
    switch (widget.technique) {
      case TechniqueType.descomposicion:
        return _descomposicionSteps;
      case TechniqueType.metaPreguntas:
        return _metaPreguntasSteps;
      case TechniqueType.plantillas:
        return _plantillasSteps;
      default:
        return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final steps = _getStepsForTechnique();
    final currentStepData = steps[_currentStep];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título
        Text(
          _getTechniqueTitle(),
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),

        // Controles de animación
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Paso ${_currentStep + 1} de ${steps.length}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            TextButton.icon(
              onPressed: _skipAnimation,
              icon: const Icon(Icons.skip_next, size: 20),
              label: const Text('Saltar animación'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ],
        ),

        const SizedBox(height: 8),

        // Barra de progreso de pasos
        LinearProgressIndicator(
          value: (_currentStep + 1) / steps.length,
          backgroundColor: Colors.grey[200],
          valueColor: AlwaysStoppedAnimation<Color>(
            _getTechniqueColor(),
          ),
        ),

        const SizedBox(height: 24),

        // Contenido animado
        Expanded(
          child: SingleChildScrollView(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 500),
              child: _buildStepContent(currentStepData),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botón de continuar (solo visible en el último paso)
        if (_currentStep == steps.length - 1)
          Center(
            child: ElevatedButton(
              onPressed: widget.onComplete,
              child: const Text('Continuar'),
            ),
          ),
      ],
    );
  }

  String _getTechniqueTitle() {
    switch (widget.technique) {
      case TechniqueType.descomposicion:
        return 'Caso 1: Planificación y Descomposición';
      case TechniqueType.metaPreguntas:
        return 'Caso 2: Meta-Preguntas';
      case TechniqueType.plantillas:
        return 'Caso 3: Plantillas Avanzadas';
      default:
        return '';
    }
  }

  Color _getTechniqueColor() {
    switch (widget.technique) {
      case TechniqueType.descomposicion:
        return Colors.blue;
      case TechniqueType.metaPreguntas:
        return Colors.purple;
      case TechniqueType.plantillas:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildStepContent(AnimationStep step) {
    return Container(
      key: ValueKey<int>(_currentStep),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icono y título del paso
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: step.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: step.color.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(step.icon, color: step.color, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    step.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: step.color,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Contenido del paso
          if (step.description != null) ...[
            Text(
              step.description!,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 16),
          ],

          // Ejemplo visual
          if (step.example != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        step.exampleIcon ?? Icons.chat_bubble_outline,
                        color: Colors.grey[600],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        step.exampleLabel ?? 'Ejemplo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    step.example!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

          // Resultado/explicación
          if (step.result != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: step.color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: step.color.withOpacity(0.2), width: 2),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle, color: step.color, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      step.result!,
                      style: const TextStyle(fontSize: 14, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// MODELOS DE DATOS PARA ANIMACIONES
// ============================================================================

class AnimationStep {
  final String title;
  final String? description;
  final String? example;
  final String? exampleLabel;
  final IconData? exampleIcon;
  final String? result;
  final IconData icon;
  final Color color;

  AnimationStep({
    required this.title,
    this.description,
    this.example,
    this.exampleLabel,
    this.exampleIcon,
    this.result,
    required this.icon,
    required this.color,
  });
}

// ============================================================================
// PASOS DE ANIMACIÓN: DESCOMPOSICIÓN
// ============================================================================

final List<AnimationStep> _descomposicionSteps = [
  AnimationStep(
    title: 'La Situación',
    description: 'María trabaja en marketing y necesita crear una presentación de 20 diapositivas para proponer un nuevo proyecto. Tiene poco tiempo y no sabe por dónde empezar.',
    icon: Icons.person,
    color: Colors.blue,
  ),
  AnimationStep(
    title: 'El Error Común ❌',
    description: 'María intenta pedirle todo de golpe a la IA:',
    example: '"Crea una presentación completa de 20 diapositivas sobre mi proyecto de app móvil. Incluye análisis de mercado, competencia, desarrollo, costos, proyecciones y marketing."',
    exampleLabel: 'Prompt de María',
    exampleIcon: Icons.error_outline,
    result: '❌ Resultado: La IA genera contenido genérico y superficial. María tiene que rehacerlo todo.',
    icon: Icons.close,
    color: Colors.red,
  ),
  AnimationStep(
    title: 'La Solución: Paso 1 - Planificar',
    description: 'María decide usar la técnica de descomposición. Primero, pide ayuda para planificar:',
    example: '"Ayúdame a estructurar una presentación de negocio para una app móvil de productividad. Dame: 1) Secciones principales, 2) Diapositivas por sección, 3) Puntos clave de cada una."',
    exampleLabel: 'Planificación',
    exampleIcon: Icons.lightbulb,
    result: '✅ La IA le devuelve un plan detallado con 5 secciones y 20 diapositivas distribuidas lógicamente.',
    icon: Icons.account_tree,
    color: Colors.blue,
  ),
  AnimationStep(
    title: 'La Solución: Paso 2 - Ejecutar por Partes',
    description: 'Ahora María genera cada sección por separado:',
    example: '"Genera el contenido para la Sección 1: Análisis de Mercado (diapositivas 1-5). Incluye: tamaño del mercado, tendencias actuales, oportunidad identificada y datos relevantes."',
    exampleLabel: 'Primera sección',
    exampleIcon: Icons.edit,
    result: '✅ Contenido detallado, específico y bien fundamentado para las primeras 5 diapositivas.',
    icon: Icons.content_paste,
    color: Colors.blue,
  ),
  AnimationStep(
    title: 'El Resultado Final 🎯',
    description: 'María continúa el proceso con cada sección. Después de 5 prompts específicos, tiene una presentación profesional y completa.',
    example: '• Sección 1: Análisis de Mercado ✓\n• Sección 2: Competencia ✓\n• Sección 3: Propuesta de Valor ✓\n• Sección 4: Plan de Desarrollo ✓\n• Sección 5: Proyecciones Financieras ✓',
    exampleLabel: 'Presentación completa',
    exampleIcon: Icons.check_circle,
    result: '🎉 María ahorró 3 horas de trabajo y obtuvo contenido de calidad profesional. La clave: dividir la tarea compleja en pasos manejables.',
    icon: Icons.emoji_events,
    color: Colors.green,
  ),
];

// ============================================================================
// PASOS DE ANIMACIÓN: META-PREGUNTAS
// ============================================================================

final List<AnimationStep> _metaPreguntasSteps = [
  AnimationStep(
    title: 'La Situación',
    description: 'Carlos tiene una tienda online y necesita escribir 50 descripciones de productos. Quiere que sean consistentes y atractivas, pero no sabe cómo estructurar el prompt perfecto.',
    icon: Icons.person,
    color: Colors.purple,
  ),
  AnimationStep(
    title: 'El Error Común ❌',
    description: 'Carlos escribe prompts vagos cada vez:',
    example: '"Escribe una descripción de producto para esta camiseta."\n\n[Resultado: Texto genérico]\n\n"Ahora para estos zapatos."\n\n[Resultado: Estilo completamente diferente]\n\n"Para este gorro."\n\n[Resultado: Otra vez diferente]',
    exampleLabel: 'Enfoque inconsistente',
    exampleIcon: Icons.error_outline,
    result: '❌ Problema: Cada descripción es diferente. Pierde tiempo ajustando cada una. No hay consistencia en su catálogo.',
    icon: Icons.close,
    color: Colors.red,
  ),
  AnimationStep(
    title: 'La Solución: Hacer Meta-Preguntas',
    description: 'Carlos decide crear un prompt reutilizable. Primero pregunta:',
    example: '"Quiero crear un prompt que genere descripciones de productos para mi tienda de ropa deportiva. ¿Qué información necesitas de mí para ayudarme a construir ese prompt perfecto?"',
    exampleLabel: 'Meta-pregunta',
    exampleIcon: Icons.psychology,
    result: '✅ La IA responde con una lista de preguntas clave que Carlos debe responder.',
    icon: Icons.help_outline,
    color: Colors.purple,
  ),
  AnimationStep(
    title: 'La Construcción del Prompt',
    description: 'La IA le pregunta y Carlos responde:',
    example: 'IA: "¿Longitud? ¿Tono? ¿Estructura? ¿Call-to-action?"\n\nCarlos responde:\n• 150-200 palabras\n• Tono inspirador y profesional\n• Beneficios + uso recomendado\n• Sí, incluir CTA motivador\n• Párrafos cortos, fácil de leer',
    exampleLabel: 'Definiendo parámetros',
    exampleIcon: Icons.settings,
    result: '✅ La IA tiene toda la información necesaria para crear el prompt ideal.',
    icon: Icons.build,
    color: Colors.purple,
  ),
  AnimationStep(
    title: 'El Prompt Perfecto 🎯',
    description: 'La IA genera el prompt final:',
    example: '"Escribe una descripción de producto deportivo entre 150-200 palabras. Tono inspirador y profesional. Estructura: 1) Introducción atractiva, 2) 3 beneficios principales, 3) Uso recomendado, 4) CTA motivador. Párrafos cortos.\n\nProducto: [NOMBRE DEL PRODUCTO]"',
    exampleLabel: 'Prompt reutilizable',
    exampleIcon: Icons.star,
    result: '🎉 Carlos ahora tiene un prompt que puede usar para todos sus productos. Solo cambia el nombre y obtiene descripciones consistentes y profesionales. ¡Ahorra horas de trabajo!',
    icon: Icons.emoji_events,
    color: Colors.green,
  ),
];

// ============================================================================
// PASOS DE ANIMACIÓN: PLANTILLAS
// ============================================================================

final List<AnimationStep> _plantillasSteps = [
  AnimationStep(
    title: 'La Situación',
    description: 'Laura es project manager y cada día escribe muchos emails: solicitudes, seguimientos, respuestas... Pierde mucho tiempo pensando cómo redactar cada uno.',
    icon: Icons.person,
    color: Colors.green,
  ),
  AnimationStep(
    title: 'El Error Común ❌',
    description: 'Laura escribe cada email desde cero:',
    example: '[Lunes 9:00] "Ayúdame a escribir un email para pedir una reunión"\n\n[Lunes 11:30] "Necesito un email de seguimiento de proyecto"\n\n[Martes 10:00] "Cómo respondo a esta solicitud formal"\n\n[Martes 15:00] "Email para solicitar más recursos"',
    exampleLabel: 'Sin sistema',
    exampleIcon: Icons.error_outline,
    result: '❌ Problema: Cada vez tiene que explicar el contexto desde cero. Pierde 15-20 minutos por email. El formato es inconsistente.',
    icon: Icons.close,
    color: Colors.red,
  ),
  AnimationStep(
    title: 'La Solución: Crear Plantillas',
    description: 'Laura decide crear plantillas reutilizables para sus emails más frecuentes:',
    example: '📧 Plantilla 1: Email de Solicitud\n"Escribe un email profesional de solicitud:\n• Destinatario: [nombre/cargo]\n• Solicitud: [qué pido]\n• Contexto: [por qué]\n• Urgencia: [alta/media/baja]\n• Tono: [formal/cordial]"',
    exampleLabel: 'Plantilla de solicitud',
    exampleIcon: Icons.description,
    result: '✅ Laura guarda esta plantilla en un documento.',
    icon: Icons.save,
    color: Colors.green,
  ),
  AnimationStep(
    title: 'Uso de la Plantilla',
    description: 'Cuando necesita escribir un email de solicitud:',
    example: '"Escribe un email profesional de solicitud:\n• Destinatario: Director de IT\n• Solicitud: Acceso a servidor de pruebas\n• Contexto: Necesario para testing del nuevo módulo\n• Urgencia: alta\n• Tono: formal pero cordial"',
    exampleLabel: 'Plantilla completada',
    exampleIcon: Icons.edit,
    result: '✅ En 30 segundos tiene un email perfecto. Solo tuvo que rellenar los campos.',
    icon: Icons.flash_on,
    color: Colors.green,
  ),
  AnimationStep(
    title: 'Su Biblioteca de Plantillas 🎯',
    description: 'Laura crea plantillas para todas sus necesidades frecuentes:',
    example: '📚 Biblioteca de Laura:\n\n✉️ Email de Solicitud\n✉️ Email de Seguimiento\n✉️ Email de Actualización\n✉️ Email de Respuesta Formal\n📊 Resumen Ejecutivo\n📋 Informe de Estado\n✍️ Notas de Reunión',
    exampleLabel: 'Kit de plantillas',
    exampleIcon: Icons.folder,
    result: '🎉 Laura ahora escribe emails en 2 minutos en vez de 15. Ahorró 2 horas diarias y sus comunicaciones son más profesionales y consistentes.',
    icon: Icons.emoji_events,
    color: Colors.green,
  ),
];

// ============================================================================
// WIDGET DE EJERCICIO PRÁCTICO
// ============================================================================

class PracticeExerciseWidget extends StatefulWidget {
  final VoidCallback onComplete;

  const PracticeExerciseWidget({
    super.key,
    required this.onComplete,
  });

  @override
  State<PracticeExerciseWidget> createState() => _PracticeExerciseWidgetState();
}

class _PracticeExerciseWidgetState extends State<PracticeExerciseWidget> {
  bool _showInstructions = true;

  @override
  Widget build(BuildContext context) {
    if (_showInstructions) {
      return _buildInstructions();
    } else {
      return _buildPracticeChat();
    }
  }

  Widget _buildInstructions() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎯 Ejercicio Práctico Final',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.1),
                  Colors.purple.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tu Misión',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Text(
                  'Imagina que eres responsable de crear contenido para el blog de tu empresa. Necesitas escribir 3 artículos sobre inteligencia artificial.',
                  style: TextStyle(fontSize: 15, height: 1.5),
                ),
                SizedBox(height: 16),
                Text(
                  'Debes aplicar las 3 técnicas aprendidas:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '1️⃣ Descomposición: Planifica la estructura de tus 3 artículos\n\n'
                  '2️⃣ Meta-preguntas: Crea el prompt perfecto para escribir artículos de blog\n\n'
                  '3️⃣ Plantillas: Genera el primer artículo usando tu plantilla',
                  style: TextStyle(fontSize: 14, height: 1.8),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: Colors.amber[700], size: 24),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Guía de Pasos',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Paso 1: Pide a la IA que te ayude a planificar los 3 artículos\n\n'
                        'Paso 2: Pregunta qué información necesita para crear un prompt perfecto de artículo de blog\n\n'
                        'Paso 3: Usa ese prompt para generar el primer artículo',
                        style: TextStyle(fontSize: 14, height: 1.6),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          Center(
            child: ElevatedButton.icon(
              onPressed: () {
                // Navegar a la página de chat
                Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: {'newConversation': true},
                ).then((_) {
                  // Cuando regrese del chat, volver a mostrar instrucciones
                  if (mounted) {
                    setState(() {
                      _showInstructions = true;
                    });
                  }
                });
              },
              icon: const Icon(Icons.chat),
              label: const Text('Abrir Chat de Práctica'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: TextButton(
              onPressed: widget.onComplete,
              child: const Text('Saltar ejercicio y continuar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPracticeChat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con explicación compacta
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.school, color: Colors.blue, size: 24),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Aplica las 3 técnicas en una conversación real',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.help_outline, size: 20),
                onPressed: () {
                  setState(() {
                    _showInstructions = true;
                  });
                },
                tooltip: 'Ver instrucciones',
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Mensaje de inicio del ejercicio
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.psychology,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Chat de Práctica',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aquí podrás conversar con la IA y aplicar\nlas técnicas que has aprendido',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Botones de acción
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showInstructions = true;
                  });
                },
                icon: const Icon(Icons.info_outline, size: 20),
                label: const Text('Ver Guía'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: widget.onComplete,
                icon: const Icon(Icons.check, size: 20),
                label: const Text('Finalizar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}