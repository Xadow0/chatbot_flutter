import 'package:flutter/material.dart';

class Module4ConclusionPage extends StatelessWidget {
  final VoidCallback onFinish;

  const Module4ConclusionPage({super.key, required this.onFinish});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¡Módulo 4 Completado!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Resumen de técnicas aprendidas
                  const Text(
                    'Has dominado las técnicas avanzadas de prompting profesional:',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  _buildAchievementCard(
                    icon: Icons.account_tree,
                    title: 'Planificación y Descomposición',
                    description:
                        'Ahora puedes dividir proyectos complejos en tareas manejables y ejecutarlas sistemáticamente.',
                    color: Colors.blue,
                  ),

                  const SizedBox(height: 12),

                  _buildAchievementCard(
                    icon: Icons.psychology,
                    title: 'Meta-Preguntas',
                    description:
                        'Sabes cómo construir prompts perfectos que usarás una y otra vez con resultados consistentes.',
                    color: Colors.purple,
                  ),

                  const SizedBox(height: 12),

                  _buildAchievementCard(
                    icon: Icons.description,
                    title: 'Plantillas Avanzadas',
                    description:
                        'Tienes una biblioteca de prompts listos para acelerar tu trabajo diario.',
                    color: Colors.green,
                  ),

                  const SizedBox(height: 12),

                  _buildAchievementCard(
                    icon: Icons.bolt,
                    title: 'Comandos Personalizados',
                    description:
                        'Aprendiste a guardar tus meta-prompts como comandos reutilizables para acceder a ellos con un solo toque.',
                    color: Colors.orange,
                  ),

                  const SizedBox(height: 24),

                  // Siguiente paso
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withValues(alpha: 0.1),
                          Colors.blue.withValues(alpha: 0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.purple.withValues(alpha: 0.3),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.rocket_launch,
                                color: Colors.purple[700], size: 32),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Tu próximo paso',
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
                          'Ahora es momento de aplicar estas técnicas en tu trabajo real:\n\n'
                          '1. Ve a "Mis Comandos" y crea tu primer comando personalizado\n'
                          '2. Usa meta-preguntas para diseñar prompts perfectos\n'
                          '3. Guarda los mejores como comandos editables\n'
                          '4. Accede a ellos rápidamente desde el chat\n\n'
                          'En pocas semanas, estos comandos se convertirán en tu sistema personal de productividad con IA.',
                          style: TextStyle(fontSize: 15, height: 1.6),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Tip sobre comandos Editables vs Automáticos
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.indigo.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.tune, color: Colors.indigo[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dominando los Modos de Comando',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 12),
                              _TipBullet(
                                icon: Icons.edit_note,
                                title: 'Modo Editable',
                                text:
                                    'Ideal para plantillas con huecos ([TEMA]). El prompt se pega en el chat para que lo completes.',
                              ),
                              SizedBox(height: 8),
                              _TipBullet(
                                icon: Icons.bolt,
                                title: 'Modo Automático',
                                text:
                                    'Usa {{content}} en el prompt. Al escribir "/resumir texto", el "texto" reemplaza automáticamente a {{content}}.',
                              ),
                              SizedBox(height: 8),
                              _TipBullet(
                                icon: Icons.mouse,
                                title: 'Edición Rápida',
                                text:
                                    '¿Necesitas cambiar un comando automático solo una vez? Haz click derecho (o mantén presionado) sobre el chip y elige "Editar prompt".',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tips finales
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_awesome,
                            color: Colors.amber[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recuerda',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Las mejores técnicas son las que realmente usas. '
                                'Empieza con una técnica, domínala, y luego añade las demás. '
                                'La maestría viene con la práctica constante.',
                                style: TextStyle(fontSize: 14, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Estadística de progreso
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
                                '¡Felicidades!',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Has completado el Módulo 4 de Técnicas Avanzadas y Comandos',
                                style: TextStyle(fontSize: 14),
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

  Widget _buildAchievementCard({
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
            child: Icon(icon, color: color, size: 28),
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
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
          Icon(Icons.check_circle, color: color, size: 24),
        ],
      ),
    );
  }
}

class _TipBullet extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _TipBullet({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.indigo[700]),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: 13,
                  height: 1.4),
              children: [
                TextSpan(
                    text: '$title: ',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                TextSpan(text: text),
              ],
            ),
          ),
        ),
      ],
    );
  }
}