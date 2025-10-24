import 'package:flutter/material.dart';
import '../../../data/services/model_download_service.dart';

/// Diálogo para mostrar el progreso de descarga del modelo
class ModelDownloadDialog extends StatefulWidget {
  final ModelDownloadService downloadService;

  const ModelDownloadDialog({
    super.key,
    required this.downloadService,
  });

  @override
  State<ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<ModelDownloadDialog> {
  double _progress = 0.0;
  String _status = 'Iniciando descarga...';
  bool _isDownloading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    // Configurar callbacks
    widget.downloadService.onProgress = (progress) {
      if (mounted) {
        setState(() {
          _progress = progress;
        });
      }
    };

    widget.downloadService.onStatusChange = (status) {
      if (mounted) {
        setState(() {
          _status = status;
        });
      }
    };

    // Iniciar descarga
    final result = await widget.downloadService.downloadModel();

    if (mounted) {
      setState(() {
        _isDownloading = false;
        if (!result.success) {
          _errorMessage = result.error;
        }
      });

      // Cerrar diálogo después de un momento si fue exitoso
      if (result.success) {
        await Future.delayed(const Duration(seconds: 1));
        if (mounted) {
          Navigator.of(context).pop(result);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !_isDownloading,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              _errorMessage != null
                  ? Icons.error_outline
                  : (_isDownloading ? Icons.download : Icons.check_circle),
              color: _errorMessage != null
                  ? Colors.red
                  : (_isDownloading ? Colors.blue : Colors.green),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage != null
                    ? 'Error en descarga'
                    : (_isDownloading ? 'Descargando modelo' : 'Descarga completa'),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_errorMessage != null) ...[
              // Mostrar error
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha((0.1 * 255).round()),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withAlpha((0.3 * 255).round())),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '❌ Error:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(_errorMessage!),
                    const SizedBox(height: 12),
                    const Text(
                      '💡 Soluciones:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Text('• Verifica tu conexión a internet'),
                    const Text('• Asegúrate de tener al menos 3GB libres'),
                    const Text('• Intenta de nuevo más tarde'),
                  ],
                ),
              ),
            ] else ...[
              // Mostrar progreso
              const SizedBox(height: 8),
              Text(
                _status,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              
              // Barra de progreso
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: _isDownloading ? _progress : 1.0,
                  minHeight: 12,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _isDownloading ? Colors.blue : Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              
              // Porcentaje
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(_progress * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (_isDownloading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
              
              if (_isDownloading) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Información:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text('• Tamaño: 2.4 GB', style: TextStyle(fontSize: 12)),
                      Text('• Tiempo estimado: 5-30 min', style: TextStyle(fontSize: 12)),
                      Text('• No cierres la aplicación', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ],
          ],
        ),
        actions: [
          // Mientras se está descargando, permitir cancelar
          if (_isDownloading) ...[
            TextButton(
              onPressed: () async {
                // Cancelar descarga y cerrar el diálogo devolviendo un resultado indicando cancelación
                try {
                  widget.downloadService.cancelDownload();
                } catch (_) {}

                if (mounted) {
                  Navigator.of(context).pop(ModelDownloadResult(
                    success: false,
                    message: 'Descarga cancelada por el usuario',
                    error: 'cancelled_by_user',
                  ));
                }
              },
              child: const Text('Cancelar Descarga'),
            ),
          ] else if (_errorMessage != null) ...[
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cerrar'),
            ),
          ] else ...[
            FilledButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Continuar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mostrar el diálogo de descarga
Future<ModelDownloadResult?> showModelDownloadDialog(
  BuildContext context,
  ModelDownloadService downloadService,
) async {
  return await showDialog<ModelDownloadResult>(
    context: context,
    barrierDismissible: false,
    builder: (context) => ModelDownloadDialog(
      downloadService: downloadService,
    ),
  );
}