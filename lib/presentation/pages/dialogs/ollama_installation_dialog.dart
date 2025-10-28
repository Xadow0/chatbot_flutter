import 'package:flutter/material.dart';
import '../../../data/models/local_ollama_models.dart';

/// Diálogo que muestra el progreso de instalación de Ollama
class OllamaInstallationDialog extends StatefulWidget {
  final Stream<LocalOllamaInstallProgress> progressStream;
  final VoidCallback? onCompleted;
  final VoidCallback? onError;

  const OllamaInstallationDialog({
    super.key,
    required this.progressStream,
    this.onCompleted,
    this.onError,
  });

  @override
  State<OllamaInstallationDialog> createState() => _OllamaInstallationDialogState();
}

class _OllamaInstallationDialogState extends State<OllamaInstallationDialog> {
  LocalOllamaInstallProgress? _currentProgress;
  bool _completed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _listenToProgress();
  }

  void _listenToProgress() {
    widget.progressStream.listen(
      (progress) {
        if (!mounted) return;
        
        setState(() {
          _currentProgress = progress;
          
          if (progress.progress >= 1.0 && 
              progress.status != LocalOllamaStatus.error) {
            _completed = true;
            widget.onCompleted?.call();
          }
          
          if (progress.status == LocalOllamaStatus.error) {
            _errorMessage = progress.message;
            widget.onError?.call();
          }
        });
      },
      onError: (error) {
        if (!mounted) return;
        
        setState(() {
          _errorMessage = error.toString();
          widget.onError?.call();
        });
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: _completed || _errorMessage != null,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              _errorMessage != null 
                  ? Icons.error_outline
                  : _completed
                      ? Icons.check_circle_outline
                      : Icons.download_outlined,
              color: _errorMessage != null
                  ? colorScheme.error
                  : _completed
                      ? Colors.green
                      : colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage != null
                    ? 'Error en instalación'
                    : _completed
                        ? 'Instalación completada'
                        : 'Instalando Ollama',
                style: textTheme.titleLarge,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Text(
                  _errorMessage!,
                  style: TextStyle(color: colorScheme.error),
                ),
                const SizedBox(height: 24),
              ] else if (_completed) ...[
                Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '¡Ollama está listo para usar!',
                        style: textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ] else ...[
                // Progreso actual
                if (_currentProgress != null) ...[
                  Text(
                    _getStatusDescription(_currentProgress!.status),
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_currentProgress!.message != null)
                    Text(
                      _currentProgress!.message!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 16),
                  
                  // Barra de progreso
                  LinearProgressIndicator(
                    value: _currentProgress!.progress,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Porcentaje
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _currentProgress!.progressText,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        _currentProgress!.status.emoji,
                        style: const TextStyle(fontSize: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Pasos del proceso
                  _buildProgressSteps(_currentProgress!.status),
                ],
              ],
            ],
          ),
        ),
        actions: [
          if (_errorMessage != null || _completed)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(_errorMessage != null ? 'Cerrar' : 'Continuar'),
            ),
        ],
      ),
    );
  }

  String _getStatusDescription(LocalOllamaStatus status) {
    switch (status) {
      case LocalOllamaStatus.checkingInstallation:
        return 'Verificando instalación...';
      case LocalOllamaStatus.downloadingInstaller:
        return 'Descargando Ollama...';
      case LocalOllamaStatus.installing:
        return 'Instalando Ollama...';
      case LocalOllamaStatus.downloadingModel:
        return 'Descargando modelo de IA...';
      case LocalOllamaStatus.starting:
        return 'Iniciando servidor...';
      case LocalOllamaStatus.ready:
        return 'Listo';
      case LocalOllamaStatus.error:
        return 'Error';
      default:
        return 'Procesando...';
    }
  }

  Widget _buildProgressSteps(LocalOllamaStatus currentStatus) {
    final steps = [
      (LocalOllamaStatus.checkingInstallation, 'Verificar instalación'),
      (LocalOllamaStatus.downloadingInstaller, 'Descargar Ollama'),
      (LocalOllamaStatus.installing, 'Instalar'),
      (LocalOllamaStatus.downloadingModel, 'Descargar modelo'),
      (LocalOllamaStatus.starting, 'Iniciar servidor'),
      (LocalOllamaStatus.ready, 'Completado'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: steps.map((step) {
        final isComplete = _isStepComplete(currentStatus, step.$1);
        final isCurrent = currentStatus == step.$1;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Icon(
                isComplete
                    ? Icons.check_circle
                    : isCurrent
                        ? Icons.circle_outlined
                        : Icons.circle,
                size: 16,
                color: isComplete
                    ? Colors.green
                    : isCurrent
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
              ),
              const SizedBox(width: 8),
              Text(
                step.$2,
                style: TextStyle(
                  color: isComplete || isCurrent
                      ? Theme.of(context).colorScheme.onSurface
                      : Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(128),
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  bool _isStepComplete(LocalOllamaStatus current, LocalOllamaStatus step) {
    final order = {
      LocalOllamaStatus.notInitialized: 0,
      LocalOllamaStatus.checkingInstallation: 1,
      LocalOllamaStatus.downloadingInstaller: 2,
      LocalOllamaStatus.installing: 3,
      LocalOllamaStatus.downloadingModel: 4,
      LocalOllamaStatus.starting: 5,
      LocalOllamaStatus.ready: 6,
    };

    return (order[current] ?? 0) > (order[step] ?? 0);
  }
}