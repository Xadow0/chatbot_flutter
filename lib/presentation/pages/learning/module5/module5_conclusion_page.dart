import 'package:flutter/material.dart';

class Module5ConclusionPage extends StatelessWidget {
  final VoidCallback onFinish;

  const Module5ConclusionPage({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¡Módulo 5 Completado!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Has completado uno de los módulos más importantes: Ética y Responsabilidad en el uso de IA.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.red.withValues(alpha: 0.1),
                          Colors.orange.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.red.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lo Que Has Aprendido',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 16),
                        Text(
                          '1. La IA NO es neutral\n'
                          '   → Tiene los sesgos de sus datos de entrenamiento\n'
                          '   → Puede ser discriminatoria sin intención\n'
                          '   → Debes cuestionar sus respuestas siempre\n\n'
                          '2. NO delegues decisiones importantes\n'
                          '   → La IA informa, TÚ decides\n'
                          '   → "La IA me lo dijo" no es excusa válida\n'
                          '   → La responsabilidad final es tuya\n\n'
                          '3. TÚ eres el responsable\n'
                          '   → La IA es solo una herramienta\n'
                          '   → Tu intención y acciones definen las consecuencias\n'
                          '   → Las consecuencias legales son reales',
                          style: TextStyle(fontSize: 15, height: 1.8),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  _buildReminderCard(
                    icon: Icons.warning_amber,
                    title: 'Verifica Siempre',
                    description:
                        'Contrasta información importante con fuentes oficiales, expertos reales y múltiples perspectivas. La IA puede estar equivocada.',
                    color: Colors.orange,
                  ),

                  const SizedBox(height: 12),

                  _buildReminderCard(
                    icon: Icons.search,
                    title: 'Busca Sesgos',
                    description:
                        'Pregúntate: ¿Esta respuesta discrimina? ¿Perpetúa estereotipos? ¿Favorece a un grupo sobre otro? Si es así, descártala.',
                    color: Colors.red,
                  ),

                  const SizedBox(height: 12),

                  _buildReminderCard(
                    icon: Icons.account_circle,
                    title: 'Asume la Responsabilidad',
                    description:
                        'Cada resultado que obtienes de la IA y usas en el mundo real es tu responsabilidad. Actúa en consecuencia.',
                    color: Colors.purple,
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.blue.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.handshake,
                                color: Colors.blue[700], size: 32),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Tu Compromiso',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Al usar IA, te comprometes a:\n\n'
                          '✓ Usarla para crear, no para destruir\n'
                          '✓ Cuestionar sus respuestas críticamente\n'
                          '✓ No delegar decisiones que afecten a personas\n'
                          '✓ Verificar información importante\n'
                          '✓ Identificar y rechazar sesgos\n'
                          '✓ Asumir responsabilidad por tus acciones\n'
                          '✓ Respetar los límites éticos y legales\n\n'
                          'La IA es increíblemente poderosa. Úsala con sabiduría.',
                          style: TextStyle(fontSize: 15, height: 1.8),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.green.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.emoji_events,
                            color: Colors.green[700], size: 40),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '¡Enhorabuena!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Ahora no solo sabes usar IA, sabes usarla responsablemente. Esto te diferencia del resto.',
                                style: TextStyle(fontSize: 14, height: 1.5),
                              ),
                            ],
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
            child: ElevatedButton.icon(
              onPressed: onFinish,
              icon: const Icon(Icons.check_circle),
              label: const Text('Finalizar Módulo'),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard({
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
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
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(fontSize: 14, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}