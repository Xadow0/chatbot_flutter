import 'package:flutter/material.dart';

class Module5ContextExplanationPage extends StatelessWidget {
  final VoidCallback onNext;

  const Module5ContextExplanationPage({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ética y Responsabilidad en el Uso de IA',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'La IA no es neutral. No es un oráculo infalible. Es una herramienta creada por humanos, entrenada con datos humanos, y por tanto, hereda nuestros sesgos, errores y limitaciones.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Tres principios fundamentales que debes interiorizar:',
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Principio 1: Sesgos
                  _buildPrincipleCard(
                    context,
                    number: '1',
                    icon: Icons.psychology_alt,
                    title: 'La IA Tiene Sesgos',
                    color: Colors.red,
                    description:
                        'Las IAs se entrenan con datos del mundo real. Si esos datos contienen prejuicios raciales, de género, socioeconómicos o culturales, la IA los aprenderá y reproducirá.\n\n'
                        '¿Qué significa esto?\n'
                        '• Una IA puede dar respuestas racistas, sexistas o xenófobas\n'
                        '• Puede perpetuar estereotipos dañinos\n'
                        '• Puede discriminar sin que te des cuenta\n\n'
                        'Ejemplo real:\n'
                        'Una IA de reclutamiento de Amazon discriminaba a mujeres porque se entrenó con CVs históricos donde casi todos los seleccionados eran hombres.\n\n'
                        '⚠️ Tu responsabilidad: Cuestiona las respuestas. No asumas que son objetivas o verdaderas solo porque vienen de una IA.',
                  ),

                  const SizedBox(height: 12),

                  // Principio 2: Decisiones importantes
                  _buildPrincipleCard(
                    context,
                    number: '2',
                    icon: Icons.gavel,
                    title: 'No Delegues Decisiones Importantes',
                    color: Colors.orange,
                    description:
                        'La IA puede ayudarte a informarte, pero NUNCA debe tomar decisiones importantes por ti. Especialmente cuando afectan a personas reales.\n\n'
                        '❌ Nunca uses IA para:\n'
                        '• Diagnosticar enfermedades\n'
                        '• Decidir quién es válido para un trabajo\n'
                        '• Determinar inocencia o culpabilidad\n'
                        '• Evaluar si alguien es "digno" de algo\n'
                        '• Tomar decisiones financieras importantes\n\n'
                        'Ejemplo real:\n'
                        'Un sistema de IA de justicia predictiva en EE.UU. recomendaba sentencias más largas para personas de minorías étnicas debido a sesgos en los datos históricos.\n\n'
                        '✅ Puedes usar IA para:\n'
                        '• Investigar y recopilar información\n'
                        '• Generar ideas y opciones\n'
                        '• Analizar datos desde múltiples perspectivas\n\n'
                        'Pero la decisión final, la responsabilidad y la justificación son TUYAS. "Lo hice porque la IA me lo dijo" no es una excusa válida.',
                  ),

                  const SizedBox(height: 12),

                  // Principio 3: Responsabilidad personal
                  _buildPrincipleCard(
                    context,
                    number: '3',
                    icon: Icons.account_circle,
                    title: 'Tú Eres el Responsable',
                    color: Colors.purple,
                    description:
                        'La IA es una herramienta. Como un martillo, un coche o un cuchillo, puede usarse para crear o para destruir. La responsabilidad de su uso recae en ti.\n\n'
                        'Limitaciones de seguridad:\n'
                        '• Las IAs actuales tienen "filtros" para evitar contenido dañino\n'
                        '• Estos filtros NO son perfectos\n'
                        '• Con ingeniería de prompts, pueden evadirse\n'
                        '• Esto NO te exime de responsabilidad\n\n'
                        'Ejemplo real:\n'
                        'Una persona usó IA para generar tutoriales de fabricación de explosivos reformulando sus preguntas para evadir filtros. Fue procesada penalmente.\n\n'
                        'La analogía del arma:\n'
                        'Si alguien dispara a otra persona, ¿culpamos a la pistola? No. La pistola es una herramienta. El responsable es quien aprieta el gatillo.\n\n'
                        'Lo mismo con la IA:\n'
                        '• Si generas contenido ilegal → Tú eres responsable\n'
                        '• Si usas IA para acosar → Tú eres responsable\n'
                        '• Si creas desinformación → Tú eres responsable\n'
                        '• Si discriminas basándote en IA → Tú eres responsable\n\n'
                        '⚖️ La ley es clara: El usuario es responsable del uso que hace de la herramienta.',
                  ),

                  const SizedBox(height: 20),

                  // Caja de reflexión
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.lightbulb,
                            color: Colors.blue[700], size: 32),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reflexión Final',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'La IA es increíblemente útil, pero no es mágica. Es un reflejo de nosotros: de nuestros datos, nuestros sesgos, nuestras decisiones.\n\n'
                                'Úsala para amplificar tu inteligencia, no para reemplazar tu criterio.\n\n'
                                'Úsala para crear, no para dañar.\n\n'
                                'Úsala con consciencia de que cada resultado que obtienes tiene una consecuencia en el mundo real.',
                                style: TextStyle(fontSize: 15, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Advertencia legal
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.red.withValues(alpha: 0.4), width: 2),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning, color: Colors.red[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Advertencia Legal',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Usar IA para crear contenido ilegal, difamar, acosar, discriminar o cualquier otra actividad dañina o ilegal te hace legalmente responsable. La ignorancia no es defensa.',
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
            child: ElevatedButton(
              onPressed: onNext,
              child: const Text('Continuar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrincipleCard(
    BuildContext context, {
    required String number,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              Icon(icon, color: color, size: 32),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: const TextStyle(fontSize: 15, height: 1.6),
          ),
        ],
      ),
    );
  }
}