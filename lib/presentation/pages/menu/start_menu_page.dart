import 'package:flutter/material.dart';
import '../../../config/routes.dart';

class StartMenuPage extends StatelessWidget {
  const StartMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menú de Inicio'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bienvenido al Chatbot',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Chat Libre'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.chat,
                    arguments: {'mode': 'free'},
                  );
                },
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.history_edu_outlined),
                label: const Text('Chat de Historia'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.chat,
                    arguments: {'mode': 'story'},
                  );
                },
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                icon: const Icon(Icons.settings),
                label: const Text('Ajustes'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  Navigator.pushNamed(context, AppRoutes.settings);
                },
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () {
                  // Aún sin funcionalidad
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Créditos próximamente'),
                    ),
                  );
                },
                child: const Text('Créditos'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
