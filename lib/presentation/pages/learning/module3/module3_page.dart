import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'module3_intro_page.dart';
import 'module3_context_explanation_page.dart';
import 'module3_iteration_page.dart';
import 'module3_conclusion_page.dart';

class Module3Page extends StatefulWidget {
  const Module3Page({super.key});

  @override
  State<Module3Page> createState() => _Module3PageState();
}

class _Module3PageState extends State<Module3Page> {
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
    await prefs.setBool('module_3_completed', true);
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                // Esto separa los elementos: uno a la izquierda, otro a la derecha
                mainAxisAlignment: MainAxisAlignment.spaceBetween, 
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: _previousPage,
                    tooltip: 'Volver',
                  ),
                  // Añadimos el botón de Casa aquí, igual que en el Módulo 2
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
        return Module3IntroPage(onStart: _nextPage);
      case 1:
        return Module3ContextExplanationPage(onNext: _nextPage);
      case 2:
        return Module3IterationPage(
          iterationSequence: [
            IterationType.reformular,
            IterationType.aclarar,
            IterationType.ejemplificar,
            IterationType.acotar
          ],
          onNext: _nextPage,
        );
      case 3:
        return Module3ConclusionPage(onFinish: _completeModule);
      default:
        return const SizedBox();
    }
  }
}