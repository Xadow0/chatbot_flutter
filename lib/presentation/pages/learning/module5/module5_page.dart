import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'module5_intro_page.dart';
import 'module5_context_explanation_page.dart';
import 'module5_ethics_scenarios_page.dart';
import 'module5_conclusion_page.dart';

class Module5Page extends StatefulWidget {
  const Module5Page({super.key});

  @override
  State<Module5Page> createState() => _Module5PageState();
}

class _Module5PageState extends State<Module5Page> {
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

  // 1. AÑADIMOS LA FUNCIÓN PARA VOLVER AL HOME
  void _goHome() {
    Navigator.pop(context);
  }

  Future<void> _completeModule() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('module_5_completed', true);
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
            // 2. MODIFICAMOS EL HEADER
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                // Alineación para separar los botones a los extremos
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: _previousPage,
                    tooltip: 'Volver',
                  ),
                  // Nuevo botón de Casa
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
        return Module5IntroPage(onStart: _nextPage);
      case 1:
        return Module5ContextExplanationPage(onNext: _nextPage);
      case 2:
        return Module5EthicsScenariosPage(
          scenarioSequence: [
            EthicsScenarioType.sesgos,
            EthicsScenarioType.decisiones,
            EthicsScenarioType.responsabilidad,
          ],
          onNext: _nextPage,
        );
      case 3:
        return Module5ConclusionPage(onFinish: _completeModule);
      default:
        return const SizedBox();
    }
  }
}