import 'package:flutter/material.dart';

class Module3ContextExplanationPage extends StatelessWidget {
  final VoidCallback onNext;

  const Module3ContextExplanationPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'El Contexto en las Conversaciones',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'El contexto de la conversación y los mensajes anteriores influyen directamente en los resultados que una IA te da.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),

                  const Text(
                    'Existen varias estrategias para mejorar las respuestas mediante iteración y reformulación:',
                    style: TextStyle(fontSize: 16, height: 1.5, fontWeight: FontWeight.w600),
                  ),

                  const SizedBox(height: 16),

                  // 1. Refinar la conversación actual
                  _buildStrategyCard(
                    context,
                    icon: Icons.tune,
                    title: 'Refinar la conversación actual',
                    color: Colors.blue,
                    description:
                        'Úsalo cuando la IA te da información correcta pero el formato, tono o nivel de detalle no es el que necesitas. Esta estrategia aprovecha el contexto ya establecido.\n\n'
                        'Ejemplo real:\n'
                        'Le pediste a la IA: "Explícame cómo funciona la fotosíntesis"\n'
                        'La IA te dio una explicación técnica con muchos términos científicos.\n\n'
                        'Puedes refinar diciendo:\n'
                        '• "Hazlo más sencillo, como si le explicaras a un niño de 10 años"\n'
                        '• "Resume esto en 3 puntos clave"\n'
                        '• "Ahora ponlo en formato de lista con viñetas"\n'
                        '• "Añade un ejemplo cotidiano para entenderlo mejor"',
                  ),

                  const SizedBox(height: 12),

                  // 2. Empezar desde cero
                  _buildStrategyCard(
                    context,
                    icon: Icons.refresh,
                    title: 'Empezar desde cero (Nueva conversación)',
                    color: Colors.green,
                    description:
                        'Úsalo cuando la conversación ha tomado un rumbo completamente equivocado o la IA ha malinterpretado tu intención desde el principio. Al crear una nueva conversación, evitas arrastrar contexto erróneo.\n\n'
                        'Cuándo hacerlo:\n'
                        '• La IA asumió algo incorrecto y sus respuestas siguientes parten de esa suposición\n'
                        '• Probaste varios ajustes pero la respuesta sigue sin ser útil\n'
                        '• Quieres un enfoque totalmente diferente\n'
                        '• La conversación se volvió confusa con muchas idas y venidas\n\n'
                        'Ejemplo real:\n'
                        'Pediste: "Ayúdame con una receta de pasta"\n'
                        'La IA asumió que querías pasta italiana con salsa de tomate.\n'
                        'En realidad buscabas una receta de pasta casera (hacer la masa desde cero).\n\n'
                        '→ Crear nueva conversación y reformular: "Enséñame a hacer pasta fresca casera desde cero"',
                  ),

                  const SizedBox(height: 12),

                  // 3. Iteración guiada por ejemplos
                  _buildStrategyCard(
                    context,
                    icon: Icons.style,
                    title: 'Iteración guiada por ejemplos',
                    color: Colors.purple,
                    description:
                        'Úsalo cuando necesitas que la IA siga un formato, estilo o estructura muy específica. Mostrarle un ejemplo es más efectivo que describirlo con palabras.\n\n'
                        'Ejemplo real:\n'
                        'Quieres que la IA escriba descripciones de productos para tu tienda online, pero sus textos son muy genéricos.\n\n'
                        'Le muestras un ejemplo:\n'
                        '"Aquí tienes un ejemplo del estilo que busco:\n\n'
                        '✨ Camiseta Vintage Wave - 29.99€\n'
                        'Suave como una brisa de verano. Esta camiseta de algodón 100% orgánico te abraza con su corte relajado. Perfect para esos días donde el estilo casual es tu mejor aliado.\n\n'
                        'Ahora escribe una descripción similar para estos otros productos: [lista de productos]"',
                  ),

                  const SizedBox(height: 12),

                  // 4. Meta-preguntas
                  _buildStrategyCard(
                    context,
                    icon: Icons.help_outline,
                    title: 'Meta-preguntas',
                    color: Colors.orange,
                    description:
                        'Úsalo cuando no estás seguro de cómo pedir algo o sientes que tus instrucciones no son claras. Deja que la IA te ayude a mejorar tu propia pregunta.\n\n'
                        'Ejemplo real:\n'
                        'Quieres crear un plan de entrenamiento pero no sabes qué información necesita la IA.\n\n'
                        'Preguntas meta útiles:\n'
                        '• "¿Qué información necesitas de mí para crear un buen plan de entrenamiento?"\n'
                        '• "¿Cómo debería estructurar mi pregunta para obtener mejores resultados?"\n'
                        '• "¿Qué detalles adicionales harían tu respuesta más precisa?"\n\n'
                        'La IA te dirá: "Necesitaría saber tu nivel actual, objetivos, días disponibles, lesiones previas, equipamiento..."\n\n'
                        'Esto te ayuda a reformular tu pregunta de forma más completa.',
                  ),

                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: Colors.amber[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Consejo: Combina estas estrategias. Por ejemplo, usa meta-preguntas para entender qué necesitas, luego refina la conversación con ejemplos para obtener el resultado perfecto.',
                            style: TextStyle(fontSize: 14, height: 1.4, fontStyle: FontStyle.italic),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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