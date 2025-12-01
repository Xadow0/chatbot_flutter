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
                        'Cuando la dirección de la respuesta es correcta pero necesita ajustes. Puedes pedir cambios de estilo, formato, claridad o nivel de detalle sin empezar de cero.\n\n'
                        'Ejemplos:\n'
                        '- “Hazlo más breve y directo.”\n'
                        '- “Explícalo para principiantes.”\n'
                        '- “Convierte esta respuesta en una tabla.”',
                  ),

                  const SizedBox(height: 12),

                  // 2. Empezar desde cero
                  _buildStrategyCard(
                    context,
                    icon: Icons.refresh,
                    title: 'Empezar desde cero',
                    color: Colors.green,
                    description:
                        'Ideal cuando la conversación se ha desviado o el enfoque inicial no era el adecuado. Reiniciar evita arrastrar errores o supuestos incorrectos.\n\n'
                        'Ejemplos:\n'
                        '- “Voy a reformular la petición desde cero.”\n'
                        '- “Olvida el historial anterior y genera una propuesta nueva basada en esto.”',
                  ),

                  const SizedBox(height: 12),

                  // 3. Iteración guiada por ejemplos
                  _buildStrategyCard(
                    context,
                    icon: Icons.style,
                    title: 'Iteración guiada por ejemplos',
                    color: Colors.purple,
                    description:
                        'Puedes enseñar a la IA el tipo de salida exacta que buscas mediante ejemplos. Esto mejora la coherencia en tono, estructura y calidad.\n\n'
                        'Ejemplos:\n'
                        '- “Aquí tienes un ejemplo del estilo que quiero. Reescribe tu respuesta siguiendo ese formato.”\n'
                        '- “Imita esta estructura: definición → ejemplo → síntesis.”',
                  ),

                  const SizedBox(height: 12),

                  // 4. Meta-preguntas
                  _buildStrategyCard(
                    context,
                    icon: Icons.help_outline,
                    title: 'Meta-preguntas',
                    color: Colors.orange,
                    description:
                        'A veces no sabes exactamente cómo formular tu petición. Las meta-preguntas permiten que la IA te diga qué necesita o cómo mejorar tu instrucción.\n\n'
                        'Ejemplos:\n'
                        '- “¿Qué información te falta para dar la mejor respuesta posible?”\n'
                        '- “Reformula mi solicitud para hacerla más clara.”\n'
                        '- “Proponme una manera más efectiva de pedir esto.”',
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'En este módulo aprenderás cuándo usar cada estrategia, cómo aplicarlas y cómo combinarlas para obtener mejores resultados.',
                    style: TextStyle(fontSize: 16, height: 1.5, fontStyle: FontStyle.italic),
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
