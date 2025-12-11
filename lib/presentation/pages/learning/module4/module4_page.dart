import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'module4_intro_page.dart';
import 'module4_context_explanation_page.dart';
import 'module4_practice_page.dart';
import 'module4_commands_tutorial_page.dart';
import 'module4_conclusion_page.dart';

class Module4Page extends StatefulWidget {
  const Module4Page({super.key});

  @override
  State<Module4Page> createState() => _Module4PageState();
}

class _Module4PageState extends State<Module4Page> {
  int _currentPage = 0;

  void _nextPage() {
    setState(() {
      _currentPage++;
    });
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  void _goHome() {
    Navigator.pop(context);
  }

  Future<void> _completeModule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('module_4_completed', true);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Header con navegación
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: _previousPage,
                    tooltip: 'Volver',
                  ),
                  IconButton(
                    icon: const Icon(Icons.home_rounded, size: 28),
                    onPressed: _goHome,
                    tooltip: 'Salir al menú',
                  ),
                ],
              ),
            ),
            // Contenido de la página actual
            Expanded(
              child: _buildCurrentPage(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    switch (_currentPage) {
      case 0:
        return Module4IntroPage(onStart: _nextPage);
      case 1:
        return Module4ContextExplanationPage(onNext: _nextPage);
      case 2:
        return Module4PracticePage(
          techniqueSequence: [
            TechniqueType.descomposicion,
            TechniqueType.metaPreguntas,
            TechniqueType.plantillas,
          ],
          onNext: _nextPage,
        );
      case 3:
        // Nueva página: Tutorial de Comandos
        return Module4CommandsTutorialPage(onNext: _nextPage);
      case 4:
        return Module4ConclusionPage(onFinish: _completeModule);
      default:
        return const SizedBox();
    }
  }
}