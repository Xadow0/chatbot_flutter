import 'package:flutter/material.dart';

class Module4ContextExplanationPage extends StatelessWidget {
  final VoidCallback onNext;

  const Module4ContextExplanationPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Técnicas Avanzadas de Prompting',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Para proyectos complejos y trabajo profesional, necesitas dominar técnicas que te permitan organizar, estructurar y reutilizar tus interacciones con la IA de forma eficiente.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Estas son las tres técnicas profesionales que transformarán tu forma de trabajar con IA:',
                    style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 16),

                  // 1. Planificación y descomposición
                  _buildStrategyCard(
                    context,
                    icon: Icons.account_tree,
                    title: 'Planificación y Descomposición de Tareas',
                    color: Colors.blue,
                    description:
                        'Úsalo cuando enfrentes proyectos grandes que parecen abrumadores. La IA puede ayudarte a dividir cualquier tarea compleja en pasos manejables y luego ejecutarlos uno por uno.\n\n'
                        'Cómo funciona:\n'
                        '• Primera conversación: Planifica y divide la tarea\n'
                        '• Conversaciones siguientes: Genera cada parte específica\n'
                        '• Usa proyectos para mantener el contexto compartido\n\n'
                        'Ejemplo real - Crear un curso online:\n\n'
                        'Conversación 1 (Planificación):\n'
                        '"Necesito crear un curso online sobre fotografía para principiantes. Ayúdame a estructurarlo: módulos, lecciones por módulo, duración estimada y objetivos de aprendizaje."\n\n'
                        'La IA te devuelve un plan completo con 5 módulos.\n\n'
                        'Conversación 2 (Ejecución - Módulo 1):\n'
                        '"Basándote en el plan que creamos, escribe el contenido completo del Módulo 1: Fundamentos de la Cámara. Incluye explicaciones, ejemplos prácticos y ejercicios."\n\n'
                        'Conversación 3 (Ejecución - Módulo 2):\n'
                        '"Ahora genera el Módulo 2: Composición y Encuadre, siguiendo la misma estructura del módulo anterior."\n\n'
                        'Ventaja: Cada conversación se enfoca en una parte específica, obteniendo mejores resultados que intentar generar todo de golpe.',
                  ),

                  const SizedBox(height: 12),

                  // 2. Meta-preguntas para construcción de prompts
                  _buildStrategyCard(
                    context,
                    icon: Icons.psychology,
                    title: 'Meta-Preguntas para Construcción de Prompts',
                    color: Colors.purple,
                    description:
                        'Úsalo cuando necesites crear un prompt perfecto que usarás repetidamente. La IA puede ayudarte a diseñar la mejor versión de tu prompt antes de usarlo.\n\n'
                        'El proceso:\n'
                        '1. Describes lo que quieres conseguir\n'
                        '2. La IA te pregunta qué necesita saber\n'
                        '3. Respondes esas preguntas\n'
                        '4. La IA construye el prompt optimizado\n'
                        '5. Guardas ese prompt para usarlo una y otra vez\n\n'
                        'Ejemplo real - Prompt para reseñas de productos:\n\n'
                        'Tú: "Quiero un prompt que me ayude a escribir reseñas de productos tecnológicos para mi blog. ¿Qué información deberías incluir en ese prompt para que funcione perfectamente?"\n\n'
                        'IA: "Para crear el mejor prompt necesito saber:\n'
                        '• ¿Qué tono usas? (técnico, casual, humorístico)\n'
                        '• ¿Cuál es la estructura típica de tus reseñas?\n'
                        '• ¿Qué aspectos siempre evalúas? (diseño, rendimiento, precio...)\n'
                        '• ¿Qué longitud tienen tus reseñas?\n'
                        '• ¿Incluyes puntuaciones o rankings?"\n\n'
                        'Tú respondes cada punto.\n\n'
                        'IA: "Perfecto. Aquí está tu prompt optimizado:\n\n'
                        '\'Escribe una reseña de producto tecnológico con estas características: [incluye todos los detalles que especificaste]. Producto a reseñar: [NOMBRE DEL PRODUCTO]\'"\n\n'
                        'Ahora tienes un prompt listo para usar con cualquier producto.',
                  ),

                  const SizedBox(height: 12),

                  // 3. Plantillas avanzadas (Prompt Recipes)
                  _buildStrategyCard(
                    context,
                    icon: Icons.description,
                    title: 'Plantillas Avanzadas (Prompt Recipes)',
                    color: Colors.green,
                    description:
                        'Úsalo cuando realices tareas repetitivas o tengas necesidades recurrentes. Las plantillas pre-diseñadas te ahorran tiempo y garantizan resultados consistentes.\n\n'
                        'Tipos de plantillas útiles:\n\n'
                        '📝 Plantilla para emails profesionales:\n'
                        '"Escribe un email [formal/informal] para [destinatario] sobre [tema]. Tono: [amigable/directo/persuasivo]. Longitud: [corto/medio/largo]. Incluye: [puntos específicos]."\n\n'
                        '📊 Plantilla para análisis de datos:\n'
                        '"Analiza estos datos: [datos]. Identifica: 1) Tendencias principales, 2) Anomalías, 3) Insights clave, 4) Recomendaciones accionables. Presenta en formato ejecutivo."\n\n'
                        '✍️ Plantilla para contenido redes sociales:\n'
                        '"Crea [número] posts para [red social] sobre [tema]. Estilo: [descripción del estilo]. Objetivo: [generar engagement/educar/vender]. Incluye: hashtags relevantes y call-to-action."\n\n'
                        '🎯 Plantilla para lluvia de ideas:\n'
                        '"Genera [número] ideas creativas para [objetivo]. Contexto: [descripción]. Restricciones: [limitaciones]. Formato: título + descripción breve. Ordena de más a menos viable."\n\n'
                        'Crea tu biblioteca: Guarda las plantillas que más uses y modifícalas según necesites. Con el tiempo, tendrás un arsenal de prompts listos para cualquier situación.',
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Flujo de trabajo profesional: Usa meta-preguntas para diseñar tus plantillas perfectas. Luego usa esas plantillas para planificar proyectos grandes. Cada técnica potencia a las demás.',
                            style: TextStyle(fontSize: 14, height: 1.4, fontStyle: FontStyle.italic),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.workspace_premium, color: Colors.blue[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Beneficio clave: Estas técnicas transforman a la IA de un simple asistente en tu sistema de trabajo. No solo obtienes mejores respuestas, creas procesos reproducibles y escalables.',
                            style: TextStyle(fontSize: 14, height: 1.4, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Center(
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategyCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}