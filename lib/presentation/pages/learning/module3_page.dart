import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'module3_intro_page.dart';
import 'module3_iteration_page.dart';

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
            // Header con botón de retroceso
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, size: 28),
                    onPressed: _previousPage,
                    tooltip: 'Volver',
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
        return Module3IterationPage(
          // run the full iteration sequence in one chat interface
          iterationSequence: [IterationType.reformular, IterationType.aclarar, IterationType.ejemplificar, IterationType.acotar],
          onNext: _completeModule,
        );
      case 2:
      case 3:
      case 4:
        // these pages are handled inside the single Module3IterationPage now
        return const SizedBox.shrink();
      default:
        return const SizedBox();
    }
  }
}