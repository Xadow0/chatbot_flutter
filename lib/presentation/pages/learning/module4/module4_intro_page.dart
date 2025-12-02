import 'package:flutter/material.dart';

class Module4IntroPage extends StatelessWidget {
  final VoidCallback onStart;

  const Module4IntroPage({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Módulo 4: Técnicas Avanzadas',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Expanded(
            child: SingleChildScrollView(
              child: Text(
                'En este módulo aprenderás técnicas profesionales para trabajar con IA: '
                'planificación y descomposición de tareas complejas, uso de meta-preguntas '
                'para construir prompts perfectos, y creación de plantillas reutilizables. '
                'Estas técnicas transformarán la IA en tu sistema de trabajo personal. '
                'Pulsa "Comenzar" cuando estés listo.',
                style: TextStyle(fontSize: 16, height: 1.5),
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