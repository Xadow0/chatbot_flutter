import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/chat_provider.dart';
import '../../../../data/models/local_ollama_models.dart';
import '../../../../data/services/local_ollama_service.dart';

/// Página para gestionar los modelos de IA locales descargados.
/// 
/// Permite al usuario:
/// - Ver todos los modelos instalados con su tamaño
/// - Eliminar modelos que ya no necesita
/// - Ver qué modelo está activo actualmente
class LocalModelsManagementPage extends StatefulWidget {
  const LocalModelsManagementPage({super.key});

  @override
  State<LocalModelsManagementPage> createState() => _LocalModelsManagementPageState();
}

class _LocalModelsManagementPageState extends State<LocalModelsManagementPage> {
  List<InstalledModelInfo> _installedModels = [];
  bool _isLoading = true;
  String? _error;
  String? _deletingModel;

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);
      final localService = chatProvider.aiSelector.localOllamaService;

      if (!localService.isPlatformSupported) {
        setState(() {
          _error = 'Ollama Local no está disponible en esta plataforma';
          _isLoading = false;
        });
        return;
      }

      if (localService.status != LocalOllamaStatus.ready) {
        setState(() {
          _error = 'El servicio de Ollama Local no está activo.\n\n'
                   'Inicia Ollama Local desde el selector de IA para gestionar los modelos.';
          _isLoading = false;
        });
        return;
      }

      final models = await localService.getInstalledModelsInfo();
      
      // Ordenar por tamaño (más grandes primero)
      models.sort((a, b) => b.size.compareTo(a.size));

      setState(() {
        _installedModels = models;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error cargando modelos: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteModel(InstalledModelInfo model) async {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final localService = chatProvider.aiSelector.localOllamaService;
    final currentModel = localService.currentModel;

    // Verificar si es el modelo actual
    final isCurrentModel = currentModel == model.name || 
                          (currentModel != null && currentModel.startsWith('${model.displayName}:'));

    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteConfirmationDialog(
        modelName: model.displayName,
        modelSize: model.sizeFormatted,
        isCurrentModel: isCurrentModel,
        totalModels: _installedModels.length,
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _deletingModel = model.name;
    });

    try {
      final result = await localService.deleteModel(model.name);

      if (!mounted) return;

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${model.displayName} eliminado correctamente'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Recargar lista
        await _loadModels();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(result.error ?? 'Error eliminando modelo'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _deletingModel = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Modelos Locales'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _isLoading ? null : _loadModels,
          ),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando modelos...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _loadModels,
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (_installedModels.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open,
                size: 64,
                color: colorScheme.outline,
              ),
              const SizedBox(height: 16),
              const Text(
                'No hay modelos instalados',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Descarga un modelo desde el selector de IA',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // Header con resumen
        _buildSummaryHeader(colorScheme),
        
        // Lista de modelos
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: _installedModels.length,
            itemBuilder: (context, index) {
              final model = _installedModels[index];
              return _ModelListTile(
                model: model,
                isDeleting: _deletingModel == model.name,
                isOnlyModel: _installedModels.length == 1,
                onDelete: () => _deleteModel(model),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryHeader(ColorScheme colorScheme) {
    final totalSize = _installedModels.fold<int>(
      0,
      (sum, model) => sum + model.size,
    );

    final totalSizeFormatted = totalSize >= 1024 * 1024 * 1024
        ? '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB'
        : '${(totalSize / (1024 * 1024)).toStringAsFixed(0)} MB';

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.storage,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_installedModels.length} modelo${_installedModels.length != 1 ? 's' : ''} instalado${_installedModels.length != 1 ? 's' : ''}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Espacio utilizado: $totalSizeFormatted',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tile individual para cada modelo instalado
class _ModelListTile extends StatelessWidget {
  final InstalledModelInfo model;
  final bool isDeleting;
  final bool isOnlyModel;
  final VoidCallback onDelete;

  const _ModelListTile({
    required this.model,
    required this.isDeleting,
    required this.isOnlyModel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final chatProvider = Provider.of<ChatProvider>(context);
    final currentModel = chatProvider.aiSelector.localOllamaService.currentModel;
    
    final isCurrentModel = currentModel == model.name || 
                          (currentModel != null && currentModel.startsWith('${model.displayName}:'));

    // Buscar info adicional en los modelos recomendados
    final recommendedInfo = LocalOllamaModel.recommendedModels.firstWhere(
      (m) => model.name.startsWith(m.name),
      orElse: () => LocalOllamaModel(
        name: model.name,
        displayName: model.displayName,
        description: 'Modelo personalizado',
        isDownloaded: true,
        estimatedSize: model.sizeFormatted,
        parametersB: 0,
      ),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Icono del modelo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isCurrentModel 
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.smart_toy,
                color: isCurrentModel 
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            
            // Info del modelo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          recommendedInfo.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isCurrentModel ? colorScheme.primary : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrentModel) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'ACTIVO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recommendedInfo.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.storage,
                        size: 14,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        model.sizeFormatted,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.label_outline,
                        size: 14,
                        color: colorScheme.outline,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        model.tag,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Botón de eliminar
            if (isDeleting)
              const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isOnlyModel 
                      ? colorScheme.outline.withAlpha(100)
                      : colorScheme.error,
                ),
                tooltip: isOnlyModel 
                    ? 'No puedes eliminar el único modelo'
                    : 'Eliminar modelo',
                onPressed: isOnlyModel ? null : onDelete,
              ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo de confirmación para eliminar un modelo
class _DeleteConfirmationDialog extends StatelessWidget {
  final String modelName;
  final String modelSize;
  final bool isCurrentModel;
  final int totalModels;

  const _DeleteConfirmationDialog({
    required this.modelName,
    required this.modelSize,
    required this.isCurrentModel,
    required this.totalModels,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(
        Icons.delete_forever,
        color: colorScheme.error,
        size: 48,
      ),
      title: const Text('Eliminar modelo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Estás seguro de que quieres eliminar "$modelName"?',
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.storage,
                  size: 20,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Se liberarán $modelSize de espacio',
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          if (isCurrentModel) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withAlpha(100),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: colorScheme.error.withAlpha(100)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 20,
                    color: colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Este es el modelo activo. Se seleccionará otro automáticamente.',
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.error,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          const SizedBox(height: 16),
          Text(
            'Esta acción no se puede deshacer. Podrás volver a descargarlo si lo necesitas.',
            style: TextStyle(
              fontSize: 13,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
          ),
          child: const Text('Eliminar'),
        ),
      ],
    );
  }
}