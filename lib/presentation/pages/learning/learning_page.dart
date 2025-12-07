import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LearningPage extends StatefulWidget {
  const LearningPage({super.key});

  @override
  State<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends State<LearningPage> {
  // Estado de completitud de cada módulo
  Map<int, bool> _moduleCompletion = {};

  @override
  void initState() {
    super.initState();
    _loadModuleCompletion();
  }

  Future<void> _loadModuleCompletion() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _moduleCompletion = {
        1: prefs.getBool('module_1_completed') ?? false,
        2: prefs.getBool('module_2_completed') ?? false,
        3: prefs.getBool('module_3_completed') ?? false,
        4: prefs.getBool('module_4_completed') ?? false,
        5: prefs.getBool('module_5_completed') ?? false,
      };
    });
  }

  void _navigateToModule(int moduleNumber) {
    Navigator.pushNamed(
      context,
      '/learning/module$moduleNumber',
    ).then((_) => _loadModuleCompletion());
  }

  Widget _buildModuleCard({
    required int moduleNumber,
    required String title,
    required String description,
    required bool isCompleted,
  }) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: () => _navigateToModule(moduleNumber),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono del módulo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '$moduleNumber',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Información del módulo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context)
            .colorScheme
            .onSurface
            .withAlpha((0.7 * 255).round()),
          ),
                    ),
                  ],
                ),
              ),
              // Estado de completitud
              Icon(
                isCompleted ? Icons.check_circle : Icons.circle_outlined,
                color: isCompleted
                    ? Colors.green
                    : Theme.of(context).colorScheme.outline,
                size: 32,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header con botón de retroceso
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/');
                    },
                    tooltip: 'Volver al menú principal',
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aprendizaje',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Descripción
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Aprende sobre IA a través de módulos interactivos',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withAlpha((0.7 * 255).round()),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Lista de módulos
            Expanded(
              child: ListView(
                children: [
                  _buildModuleCard(
                    moduleNumber: 1,
                    title: '¿Cómo funciona la IA?',
                    description: 'Descubre los fundamentos de la Inteligencia Artificial',
                    isCompleted: _moduleCompletion[1] ?? false,
                  ),
                  _buildModuleCard(
                    moduleNumber: 2,
                    title: 'El arte del prompting',
                    description: 'Aprende a comunicarte mejor con la IA',
                    isCompleted: _moduleCompletion[2] ?? false,
                  ),
                  _buildModuleCard(
                    moduleNumber: 3,
                    title: 'Evaluar & Iterar',
                    description: 'Ayuda a la IA a entender tus necesidades',
                    isCompleted: _moduleCompletion[3] ?? false,
                  ),
                  _buildModuleCard(
                    moduleNumber: 4,
                    title: 'Prompts avanzados y trucos útiles',
                    description: 'Explora las técnicas que usan los expertos en prompting',
                    isCompleted: _moduleCompletion[4] ?? false,
                  ),
                  _buildModuleCard(
                    moduleNumber: 5,
                    title: 'Ética y buenas prácticas',
                    description: 'Aprende sobre limitaciones y uso responsable de la IA',
                    isCompleted: _moduleCompletion[5] ?? false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}