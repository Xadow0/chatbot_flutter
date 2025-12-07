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

  void _goHome() {
    Navigator.pop(context);
  }

  // LÓGICA CLAVE: Guarda el estado y luego cierra la pantalla
  Future<void> _completeModule() async {
    final prefs = await SharedPreferences.getInstance();
    // Marcamos la clave específica que 'learning_page.dart' está esperando
    await prefs.setBool('module_5_completed', true);
    
    if (mounted) {
      // Al hacer pop, learning_page detectará el cierre y recargará el estado
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
        // Aquí pasamos la función _completeModule al botón de finalizar
        return Module5ConclusionPage(onFinish: _completeModule);
      default:
        return const SizedBox();
    }
  }
}