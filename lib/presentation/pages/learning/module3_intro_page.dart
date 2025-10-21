import 'package:flutter/material.dart';

class Module3IntroPage extends StatelessWidget {
  final VoidCallback onStart;

  const Module3IntroPage({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Módulo 3: Iteraciones y Mejora',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Expanded(
            child: SingleChildScrollView(
              child: Text(
                'En este módulo aprenderás técnicas para iterar sobre respuestas, aclarar preguntas, dar ejemplos y acotar el alcance de las respuestas. Pulsa "Comenzar" cuando estés listo.',
                style: TextStyle(fontSize: 16),
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
