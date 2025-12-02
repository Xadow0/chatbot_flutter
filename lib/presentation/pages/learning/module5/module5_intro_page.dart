import 'package:flutter/material.dart';

class Module5IntroPage extends StatelessWidget {
  final VoidCallback onStart;

  const Module5IntroPage({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Módulo 5: Ética y Buenas Prácticas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'La IA es una herramienta poderosa, pero como toda herramienta, '
                    'debe usarse con responsabilidad y consciencia.',
                    style: TextStyle(fontSize: 16, height: 1.5),
                  ),
                  const SizedBox(height: 16),
                  
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber, color: Colors.orange[700], size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Lo que aprenderás',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                '• Los sesgos de la IA y cómo identificarlos\n'
                                '• Por qué no puedes delegar decisiones importantes\n'
                                '• La responsabilidad del uso de la IA\n'
                                '• Límites éticos y legales',
                                style: TextStyle(fontSize: 14, height: 1.6),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Este módulo es fundamental. No importa qué tan bien domines la IA, '
                    'si no entiendes sus limitaciones y responsabilidades, puedes causar daño '
                    'real a personas reales.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: ElevatedButton(
              onPressed: onStart,
              child: const Text('Comenzar'),
            ),
          ),
        ],
      ),
    );
  }
}