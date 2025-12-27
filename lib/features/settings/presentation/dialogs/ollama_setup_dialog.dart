import 'package:flutter/material.dart';
import '../../../chat/data/models/local_ollama_models.dart';
import '../../../chat/data/datasources/local/local_ollama_source.dart';

/// Diálogo para configurar e inicializar Ollama Local
/// 
/// Puede recibir un [initialModelName] para pre-seleccionar un modelo específico,
/// útil cuando el usuario quiere instalar un modelo que no tiene descargado.
class OllamaSetupDialog extends StatefulWidget {
  final OllamaManagedService localOllamaService;
  
  /// Modelo inicial a pre-seleccionar (opcional).
  /// Si se proporciona, el diálogo iniciará con este modelo seleccionado.
  final String? initialModelName;

  const OllamaSetupDialog({
    super.key,
    required this.localOllamaService,
    this.initialModelName,
  });

  @override
  State<OllamaSetupDialog> createState() => _OllamaSetupDialogState();
}

class _OllamaSetupDialogState extends State<OllamaSetupDialog> {
  bool _isInitializing = false;
  LocalOllamaStatus _currentStatus = LocalOllamaStatus.notInitialized;
  String? _errorMessage;
  LocalOllamaInstallProgress? _currentProgress;
  late String _selectedModelName;
  
  /// Indica si el diálogo se abrió para instalar un modelo específico
  bool get _isDirectModelInstall => widget.initialModelName != null;

  @override
  void initState() {
    super.initState();
    
    // Usa el modelo inicial si se proporcionó, sino usa el modelo por defecto
    _selectedModelName = widget.initialModelName ?? LocalOllamaModel.defaultModel;
    
    widget.localOllamaService.addStatusListener(_onStatusChanged);
    widget.localOllamaService.addInstallProgressListener(_onProgressChanged);
    
    // Si se proporcionó un modelo inicial, iniciar instalación automáticamente
    if (_isDirectModelInstall) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _startInitialization();
      });
    }
  }

  @override
  void dispose() {
    widget.localOllamaService.removeStatusListener(_onStatusChanged);
    widget.localOllamaService.removeInstallProgressListener(_onProgressChanged);
    super.dispose();
  }

  void _onStatusChanged(LocalOllamaStatus status) {
    if (!mounted) return;
    
    setState(() {
      _currentStatus = status;
    });
    
    if (status == LocalOllamaStatus.ready) {
      // El proceso terminó exitosamente
    } else if (status == LocalOllamaStatus.error) {
      setState(() {
        _isInitializing = false;
        _errorMessage = widget.localOllamaService.errorMessage;
      });
    }
  }

  void _onProgressChanged(LocalOllamaInstallProgress progress) {
    if (!mounted) return;
    
    setState(() {
      _currentProgress = progress;
      // Actualiza el estado si el progreso lo indica
      if (progress.status != _currentStatus) {
        _currentStatus = progress.status;
      }
    });
  }

  Future<void> _startInitialization() async {
    setState(() {
      _isInitializing = true;
      _errorMessage = null;
    });

    try {
      // Pasa el modelo seleccionado al servicio
      final result = await widget.localOllamaService.initialize(
        modelName: _selectedModelName,
      );

      if (!mounted) return;

      if (result.success) {
        // Muestra el diálogo de éxito
        await _showSuccessDialog(result);
        if (mounted) {
          // Cierra el diálogo principal
          Navigator.of(context).pop(true);
        }
      } else {
        setState(() {
          _errorMessage = result.error;
          _isInitializing = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Error inesperado: $e';
        _isInitializing = false;
      });
    }
  }

  Future<void> _showSuccessDialog(LocalOllamaInitResult result) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('¡Ollama Local Listo!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '✅ Ollama se ha inicializado correctamente',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              
              _buildInfoRow(
                icon: '🤖',
                label: 'Modelo activo',
                value: result.modelName ?? 'Desconocido',
              ),
              
              if (result.availableModels != null && result.availableModels!.isNotEmpty)
                _buildInfoRow(
                  icon: '📋',
                  label: 'Modelos disponibles',
                  value: '${result.availableModels!.length}',
                ),
              
              if (result.initTime != null)
                _buildInfoRow(
                  icon: '⏱️',
                  label: 'Tiempo de carga',
                  value: '${result.initTime!.inSeconds}s',
                ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(128)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ollama gestiona GPU automáticamente para mejor rendimiento',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
              
              if (result.wasNewInstallation) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withAlpha(128)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.new_releases_outlined, color: Colors.green),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Nueva instalación completada',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Comenzar a usar'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required String icon,
    required String label,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return PopScope(
      canPop: !_isInitializing,
      child: AlertDialog(
        title: Row(
          children: [
            Icon(
              _isDirectModelInstall ? Icons.download_outlined : Icons.smart_toy_outlined,
              color: colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _isDirectModelInstall 
                    ? 'Instalar $_selectedModelName'
                    : 'Configurar Ollama Local',
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Descripción
                Text(
                  '🔒 IA 100% local y privada',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isDirectModelInstall
                      ? 'Se descargará e instalará el modelo seleccionado en tu computadora.'
                      : 'Ejecuta modelos de IA directamente en tu computadora sin enviar datos a internet.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),

                // Selector de modelo (solo si no es instalación directa)
                if (!_isDirectModelInstall) ...[
                  Text(
                    'Selecciona un modelo para instalar:',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withAlpha(50),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: RadioGroup<String>(
                      groupValue: _selectedModelName,
                      onChanged: (value) {
                        if (_isInitializing || value == null) return;
                        setState(() {
                          _selectedModelName = value;
                        });
                      },
                      child: Column(
                        children: LocalOllamaModel.recommendedModels.map((model) {
                          return RadioListTile<String>(
                            title: Text(model.displayName),
                            subtitle: Text(
                              '${model.description} (Tamaño: ${model.estimatedSize})',
                              style: textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            value: model.name,
                            activeColor: colorScheme.primary,
                            enabled: !_isInitializing,
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ] else ...[
                  // Info del modelo específico a instalar
                  _buildSelectedModelInfo(colorScheme, textTheme),
                  const SizedBox(height: 24),
                ],

                // Características (solo si no es instalación directa o no está inicializando)
                if (!_isDirectModelInstall || !_isInitializing) ...[
                  _buildFeature(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacidad total',
                    description: 'Tus conversaciones nunca salen de tu dispositivo',
                  ),
                  _buildFeature(
                    icon: Icons.offline_bolt_outlined,
                    title: 'Sin internet',
                    description: 'Funciona completamente offline',
                  ),
                  _buildFeature(
                    icon: Icons.speed_outlined,
                    title: 'GPU optimizada',
                    description: 'Ollama usa automáticamente tu GPU para mejor rendimiento',
                  ),
                  _buildFeature(
                    icon: Icons.download_outlined,
                    title: 'Instalación automática',
                    description: 'Se instala y configura todo automáticamente',
                  ),
                  const SizedBox(height: 24),
                ],

                // Estado de progreso
                if (_isInitializing) ...[
                  _buildProgressSection(colorScheme, textTheme),
                  const SizedBox(height: 16),
                ],

                // Error
                if (_errorMessage != null) ...[
                  _buildErrorSection(colorScheme),
                  const SizedBox(height: 16),
                ],

                // Requisitos (solo si no está inicializando)
                if (!_isInitializing) ...[
                  Text(
                    'Requisitos mínimos:',
                    style: textTheme.titleSmall,
                  ),
                  const SizedBox(height: 8),
                  _buildRequirement('💾 ~2-4 GB de espacio en disco'),
                  _buildRequirement('🧠 8 GB de RAM recomendado'),
                  _buildRequirement('⚡ Conexión inicial para descargar'),
                ],
              ],
            ),
          ),
        ),
        actions: _buildActions(colorScheme),
      ),
    );
  }

  /// Muestra información del modelo específico que se va a instalar
  Widget _buildSelectedModelInfo(ColorScheme colorScheme, TextTheme textTheme) {
    // Buscar el modelo en la lista de recomendados
    final modelInfo = LocalOllamaModel.recommendedModels.firstWhere(
      (m) => m.name == _selectedModelName,
      orElse: () => LocalOllamaModel(
        name: _selectedModelName,
        displayName: _selectedModelName,
        description: 'Modelo de IA',
        isDownloaded: false,
        estimatedSize: 'Desconocido',
        parametersB: 0,
      ),
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.primary.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.smart_toy,
            color: colorScheme.primary,
            size: 40,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  modelInfo.displayName,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  modelInfo.description,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.storage,
                      size: 14,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Tamaño: ${modelInfo.estimatedSize}',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sección de progreso de instalación
  Widget _buildProgressSection(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _getProgressMessage(),
                  style: textTheme.bodyMedium,
                ),
              ),
              Text(_currentStatus.emoji, style: const TextStyle(fontSize: 20)),
            ],
          ),
          
          if (_currentProgress != null) ...[
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: _currentProgress!.progress,
              backgroundColor: colorScheme.surfaceContainerHighest,
            ),
            const SizedBox(height: 4),
            Text(
              _currentProgress!.progressText,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Obtiene el mensaje de progreso según el estado actual
  String _getProgressMessage() {
    switch (_currentStatus) {
      case LocalOllamaStatus.checkingInstallation:
        return 'Verificando instalación de Ollama...';
      case LocalOllamaStatus.downloadingInstaller:
        return 'Descargando instalador de Ollama...';
      case LocalOllamaStatus.installing:
        return 'Instalando Ollama...';
      case LocalOllamaStatus.downloadingModel:
        return 'Descargando $_selectedModelName...';
      case LocalOllamaStatus.starting:
        return 'Iniciando servidor Ollama...';
      case LocalOllamaStatus.loading:
        return 'Cargando...';
      default:
        return _currentStatus.displayText;
    }
  }

  /// Sección de error
  Widget _buildErrorSection(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withAlpha(128),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withAlpha(128)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: TextStyle(color: colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }

  /// Construye los botones de acción según el estado
  List<Widget> _buildActions(ColorScheme colorScheme) {
    if (_isInitializing) {
      return [
        TextButton(
          onPressed: () {
            widget.localOllamaService.cancelModelDownload();
          },
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.error,
          ),
          child: const Text('Cancelar Descarga'),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: const Text('Cancelar'),
      ),
      FilledButton.icon(
        onPressed: _startInitialization,
        icon: const Icon(Icons.download_outlined),
        label: Text(_getActionButtonText()),
      ),
    ];
  }

  /// Obtiene el texto del botón de acción
  String _getActionButtonText() {
    if (_errorMessage != null) {
      return 'Reintentar Instalación';
    }
    if (_isDirectModelInstall) {
      return 'Instalar Modelo';
    }
    return 'Instalar y Configurar';
  }

  Widget _buildFeature({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequirement(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 16),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}