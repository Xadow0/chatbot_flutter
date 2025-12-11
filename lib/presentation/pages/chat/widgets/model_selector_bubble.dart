import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../../data/models/remote_ollama_models.dart';
import '../../../../data/models/local_ollama_models.dart';
import '../../../../data/services/ai_service_selector.dart';
import '../../dialogs/ollama_setup_dialog.dart';

/// Widget selector de modelos de IA con soporte para múltiples proveedores.
/// 
/// Características:
/// - Selector colapsable con animación suave
/// - Scroll interno cuando hay muchos modelos
/// - Feedback visual durante operaciones
/// - Manejo de instalación de modelos locales
class ModelSelectorBubble extends StatefulWidget {
  const ModelSelectorBubble({super.key});

  @override
  State<ModelSelectorBubble> createState() => _ModelSelectorBubbleState();
}

class _ModelSelectorBubbleState extends State<ModelSelectorBubble> 
    with SingleTickerProviderStateMixin {
  
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;
  
  // Altura máxima del selector expandido (ajustable según necesidad)
  static const double _maxExpandedHeight = 450.0;
  static const double _collapsedHeight = 56.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        // Sincronizar animación con el estado del provider
        if (chatProvider.showModelSelector) {
          _animationController.forward();
        } else {
          _animationController.reverse();
        }

        return AnimatedBuilder(
          animation: _expandAnimation,
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.all(8),
              constraints: BoxConstraints(
                maxHeight: _collapsedHeight + 
                    (_maxExpandedHeight - _collapsedHeight) * _expandAnimation.value,
              ),
              decoration: _buildContainerDecoration(context),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: chatProvider.showModelSelector
                    ? _ExpandedSelector(
                        chatProvider: chatProvider,
                        onClose: () => chatProvider.hideModelSelector(),
                      )
                    : _CollapsedButton(
                        chatProvider: chatProvider,
                        onTap: () => chatProvider.toggleModelSelector(),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  BoxDecoration _buildContainerDecoration(BuildContext context) {
    return BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withAlpha(25),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withAlpha(51),
      ),
    );
  }
}

// =============================================================================
// BOTÓN COLAPSADO
// =============================================================================

class _CollapsedButton extends StatelessWidget {
  final ChatProvider chatProvider;
  final VoidCallback onTap;

  const _CollapsedButton({
    required this.chatProvider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicadores de estado según el proveedor
            _buildStatusIndicator(context),
            
            // Icono del proveedor
            Icon(
              _ProviderUtils.getIcon(chatProvider.currentProvider),
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            
            // Info del modelo actual
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _ProviderUtils.getDisplayName(chatProvider.currentProvider),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _ProviderUtils.getCurrentModelName(chatProvider),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 4),
            Icon(
              Icons.expand_more,
              size: 16,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    final provider = chatProvider.currentProvider;
    
    if (provider == AIProvider.ollama) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _ConnectionIndicatorBadge(info: chatProvider.connectionInfo),
      );
    }
    
    if (provider == AIProvider.localOllama) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: _LocalStatusBadge(status: chatProvider.localOllamaStatus),
      );
    }
    
    return const SizedBox.shrink();
  }
}

// =============================================================================
// SELECTOR EXPANDIDO
// =============================================================================

class _ExpandedSelector extends StatelessWidget {
  final ChatProvider chatProvider;
  final VoidCallback onClose;

  const _ExpandedSelector({
    required this.chatProvider,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header fijo
        _buildHeader(context),
        
        // Contenido scrolleable
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gemini
                _GeminiOption(chatProvider: chatProvider),
                const SizedBox(height: 8),
                
                // OpenAI / ChatGPT
                _OpenAISection(chatProvider: chatProvider),
                const SizedBox(height: 8),
                
                // Ollama Remoto
                _OllamaRemoteSection(chatProvider: chatProvider),
                const SizedBox(height: 8),
                
                // Ollama Local
                _LocalOllamaSection(chatProvider: chatProvider),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 12),
      child: Row(
        children: [
          const Text(
            'Seleccionar IA',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 20),
            constraints: const BoxConstraints(),
            padding: const EdgeInsets.all(8),
            tooltip: 'Cerrar',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// OPCIÓN GEMINI
// =============================================================================

class _GeminiOption extends StatelessWidget {
  final ChatProvider chatProvider;

  const _GeminiOption({required this.chatProvider});

  @override
  Widget build(BuildContext context) {
    final isSelected = chatProvider.currentProvider == AIProvider.gemini;
    
    return _ProviderOptionCard(
      icon: Icons.auto_awesome,
      title: 'Gemini (Google)',
      subtitle: 'IA en la nube - Gratis con límites',
      isSelected: isSelected,
      isAvailable: true,
      onTap: () => _selectProvider(context, AIProvider.gemini),
    );
  }

  Future<void> _selectProvider(BuildContext context, AIProvider provider) async {
    try {
      await chatProvider.selectProvider(provider);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Error cambiando proveedor: $e');
    }
  }
}

// =============================================================================
// SECCIÓN OPENAI
// =============================================================================

class _OpenAISection extends StatelessWidget {
  final ChatProvider chatProvider;

  const _OpenAISection({required this.chatProvider});

  @override
  Widget build(BuildContext context) {
    final isAvailable = chatProvider.openaiAvailable;
    final isSelected = chatProvider.currentProvider == AIProvider.openai;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ProviderOptionCard(
          icon: Icons.chat_bubble,
          title: 'ChatGPT (OpenAI)',
          subtitle: 'Requiere API Key (de pago)',
          isSelected: isSelected,
          isAvailable: isAvailable,
          statusBadge: !isAvailable ? 'API Key requerida' : null,
          onTap: isAvailable 
              ? () => _selectProvider(context, AIProvider.openai)
              : null,
        ),
        
        // Lista de modelos si está seleccionado y disponible
        if (isSelected && isAvailable)
          _ModelListContainer(
            title: 'Modelo OpenAI',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: chatProvider.availableOpenAIModels.map((modelName) {
                return _OpenAIModelTile(
                  modelName: modelName,
                  isSelected: modelName == chatProvider.currentOpenAIModel,
                  onTap: () => _selectOpenAIModel(context, modelName),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _selectProvider(BuildContext context, AIProvider provider) async {
    try {
      await chatProvider.selectProvider(provider);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Error cambiando proveedor: $e');
    }
  }

  Future<void> _selectOpenAIModel(BuildContext context, String modelName) async {
    try {
      await chatProvider.selectOpenAIModel(modelName);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Error cambiando modelo: $e');
    }
  }
}

class _OpenAIModelTile extends StatelessWidget {
  final String modelName;
  final bool isSelected;
  final VoidCallback onTap;

  const _OpenAIModelTile({
    required this.modelName,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withAlpha(51)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    modelName.toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  Text(
                    _getModelDescription(modelName),
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  String _getModelDescription(String model) {
    switch (model) {
      case 'gpt-4o':
        return 'Más potente - Mayor costo';
      case 'gpt-4o-mini':
        return 'Recomendado - Balance ideal';
      case 'gpt-4-turbo':
        return 'GPT-4 optimizado';
      case 'gpt-3.5-turbo':
        return 'Más económico';
      default:
        return 'Modelo GPT';
    }
  }
}

// =============================================================================
// SECCIÓN OLLAMA REMOTO
// =============================================================================

class _OllamaRemoteSection extends StatelessWidget {
  final ChatProvider chatProvider;

  const _OllamaRemoteSection({required this.chatProvider});

  @override
  Widget build(BuildContext context) {
    final isAvailable = chatProvider.ollamaAvailable;
    final isSelected = chatProvider.currentProvider == AIProvider.ollama;
    final isRetrying = chatProvider.isRetryingOllama;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMainCard(context, isAvailable, isSelected, isRetrying),
        
        // Lista de modelos si está disponible
        if (isAvailable && chatProvider.availableModels.isNotEmpty)
          _ModelListContainer(
            title: 'Modelos disponibles',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: chatProvider.availableModels.map((model) {
                final isCurrentModel = isSelected && model.name == chatProvider.currentModel;
                return _RemoteOllamaModelTile(
                  model: model,
                  isSelected: isCurrentModel,
                  onTap: () => _selectModel(context, model.name),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    bool isAvailable,
    bool isSelected,
    bool isRetrying,
  ) {
    return InkWell(
      onTap: isRetrying
          ? null
          : !isAvailable
              ? () => _retryConnection(context)
              : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: (isAvailable || isRetrying) ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withAlpha(25)
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withAlpha(51),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.dns,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isAvailable
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'Ollama (Servidor Remoto)',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 4),
                        if (isAvailable && !isRetrying)
                          _ConnectionIndicatorBadge(info: chatProvider.connectionInfo),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _getSubtitle(isRetrying, isAvailable),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _buildTrailingWidget(context, isRetrying, isAvailable, isSelected),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrailingWidget(
    BuildContext context,
    bool isRetrying,
    bool isAvailable,
    bool isSelected,
  ) {
    if (isRetrying) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    if (isAvailable) {
      return IconButton(
        icon: const Icon(Icons.refresh, size: 20),
        onPressed: () => _retryConnection(context),
        constraints: const BoxConstraints(),
        padding: const EdgeInsets.all(8),
        tooltip: 'Actualizar conexión',
      );
    }
    
    if (isSelected) {
      return Icon(
        Icons.check_circle,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      );
    }
    
    return const SizedBox.shrink();
  }

  String _getSubtitle(bool isRetrying, bool isAvailable) {
    if (isRetrying) return 'Conectando con servidor...';
    if (isAvailable) return 'Servidor privado conectado';
    return 'Servidor no disponible (Toca para reintentar)';
  }

  Future<void> _retryConnection(BuildContext context) async {
    if (chatProvider.isRetryingOllama) return;
    
    try {
      final success = await chatProvider.retryOllamaConnection();
      if (!context.mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success 
                ? 'Conexión con Ollama establecida'
                : 'No se pudo conectar con el servidor',
          ),
          backgroundColor: success ? Colors.green : Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Error de conexión: $e');
      }
    }
  }

  Future<void> _selectModel(BuildContext context, String modelName) async {
    try {
      await chatProvider.selectProvider(AIProvider.ollama);
      await chatProvider.selectModel(modelName);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Error seleccionando modelo: $e');
    }
  }
}

class _RemoteOllamaModelTile extends StatelessWidget {
  final OllamaModel model;
  final bool isSelected;
  final VoidCallback onTap;

  const _RemoteOllamaModelTile({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withAlpha(51)
              : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.displayName,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  Text(
                    model.sizeFormatted,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// SECCIÓN OLLAMA LOCAL
// =============================================================================

class _LocalOllamaSection extends StatelessWidget {
  final ChatProvider chatProvider;

  const _LocalOllamaSection({required this.chatProvider});

  @override
  Widget build(BuildContext context) {
    final status = chatProvider.localOllamaStatus;
    final isAvailable = chatProvider.localOllamaAvailable;
    final isSelected = chatProvider.currentProvider == AIProvider.localOllama;
    final isLoading = chatProvider.localOllamaLoading;
    final isPlatformSupported = chatProvider.aiSelector.isLocalOllamaSupported;
    final localService = chatProvider.aiSelector.localOllamaService;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMainCard(context, status, isAvailable, isSelected, isLoading, isPlatformSupported),
        
        // Lista de modelos si está listo y seleccionado
        if (status == LocalOllamaStatus.ready && isSelected)
          _ModelListContainer(
            title: 'Modelos Locales',
            trailing: Text(
              'Tamaño est.',
              style: TextStyle(
                fontSize: 10,
                color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: LocalOllamaModel.recommendedModels.map((model) {
                final isInstalled = localService.availableModels.any(
                  (m) => m == model.name || m.startsWith('${model.name}:'),
                );
                final isCurrent = localService.currentModel != null &&
                    (localService.currentModel == model.name ||
                        localService.currentModel!.startsWith('${model.name}:'));

                return _LocalModelTile(
                  model: model,
                  isInstalled: isInstalled,
                  isCurrent: isCurrent,
                  isLoading: isLoading,
                  onTap: () => _handleModelSelection(
                    context,
                    model,
                    isInstalled,
                    isCurrent,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  Widget _buildMainCard(
    BuildContext context,
    LocalOllamaStatus status,
    bool isAvailable,
    bool isSelected,
    bool isLoading,
    bool isPlatformSupported,
  ) {
    // Determinar si hay un proceso en curso
    final isProcessing = _isProcessingStatus(status) || isLoading;
    
    return InkWell(
      onTap: !isPlatformSupported || isProcessing
          ? null
          : () => _handleMainCardTap(context, status, isAvailable),
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: (!isPlatformSupported || isProcessing) ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withAlpha(25)
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withAlpha(51),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.computer,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (!isPlatformSupported
                        ? Theme.of(context).disabledColor
                        : Theme.of(context).colorScheme.onSurfaceVariant),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Ollama Local (Privado)',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            color: !isPlatformSupported
                                ? Theme.of(context).disabledColor
                                : null,
                          ),
                        ),
                        const SizedBox(width: 4),
                        if (isPlatformSupported)
                          _LocalStatusBadge(status: status),
                      ],
                    ),
                    const SizedBox(height: 2),
                    _buildSubtitle(context, isPlatformSupported, status),
                  ],
                ),
              ),
              _buildTrailingWidget(context, isProcessing, isSelected, isPlatformSupported),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context, bool isPlatformSupported, LocalOllamaStatus status) {
    if (!isPlatformSupported) {
      return Text(
        'NO DISPONIBLE EN MÓVIL',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.error,
        ),
      );
    }
    
    return Text(
      _getStatusSubtitle(status),
      style: TextStyle(
        fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildTrailingWidget(
    BuildContext context,
    bool isProcessing,
    bool isSelected,
    bool isPlatformSupported,
  ) {
    if (isProcessing) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    if (isSelected) {
      return Icon(
        Icons.expand_more,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      );
    }
    
    if (!isPlatformSupported) {
      return Icon(
        Icons.block,
        color: Theme.of(context).disabledColor,
        size: 18,
      );
    }
    
    return const SizedBox.shrink();
  }

  String _getStatusSubtitle(LocalOllamaStatus status) {
    switch (status) {
      case LocalOllamaStatus.notInitialized:
        return 'Toca para configurar';
      case LocalOllamaStatus.checkingInstallation:
        return 'Verificando instalación...';
      case LocalOllamaStatus.downloadingInstaller:
        return 'Descargando Ollama...';
      case LocalOllamaStatus.installing:
        return 'Instalando Ollama...';
      case LocalOllamaStatus.downloadingModel:
        return 'Descargando modelo IA...';
      case LocalOllamaStatus.starting:
        return 'Iniciando servidor...';
      case LocalOllamaStatus.loading:
        return 'Cargando...';
      case LocalOllamaStatus.ready:
        return 'Listo para usar';
      case LocalOllamaStatus.error:
        return 'Error - Toca para reintentar';
    }
  }

  void _handleMainCardTap(
    BuildContext context,
    LocalOllamaStatus status,
    bool isAvailable,
  ) {
    // Si está en proceso, no hacer nada
    if (_isProcessingStatus(status)) return;
    
    if (status == LocalOllamaStatus.notInitialized ||
        status == LocalOllamaStatus.error) {
      _showSetupDialog(context);
    } else if (isAvailable) {
      _selectProvider(context, AIProvider.localOllama);
    }
  }

  /// Verifica si el estado indica un proceso en curso
  bool _isProcessingStatus(LocalOllamaStatus status) {
    return status == LocalOllamaStatus.checkingInstallation ||
           status == LocalOllamaStatus.downloadingInstaller ||
           status == LocalOllamaStatus.installing ||
           status == LocalOllamaStatus.downloadingModel ||
           status == LocalOllamaStatus.starting ||
           status == LocalOllamaStatus.loading;
  }

  Future<void> _handleModelSelection(
    BuildContext context,
    LocalOllamaModel model,
    bool isInstalled,
    bool isCurrent,
  ) async {
    if (isCurrent) return;
    
    // Si NO está instalado, mostrar diálogo de configuración/instalación
    if (!isInstalled) {
      await _showModelInstallDialog(context, model);
      return;
    }
    
    // Si está instalado, cambiar modelo directamente
    try {
      _showFeedback(context, 'Cambiando a ${model.displayName}...', isLoading: true);
      
      await chatProvider.aiSelector.localOllamaService.initialize(modelName: model.name);
      
      if (chatProvider.currentProvider != AIProvider.localOllama) {
        await chatProvider.selectProvider(AIProvider.localOllama);
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showFeedback(context, '${model.displayName} activado', isSuccess: true);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        _showError(context, 'Error cambiando modelo: $e');
      }
    }
  }

  /// Muestra el diálogo de instalación para modelos no instalados
  Future<void> _showModelInstallDialog(BuildContext context, LocalOllamaModel model) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => OllamaSetupDialog(
        localOllamaService: chatProvider.aiSelector.localOllamaService,
        initialModelName: model.name, // Pasar el modelo específico a instalar
      ),
    );

    if (result == true && context.mounted) {
      // Instalación completada exitosamente
      if (chatProvider.localOllamaStatus == LocalOllamaStatus.ready) {
        await _selectProvider(context, AIProvider.localOllama);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${model.displayName} instalado y listo'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  /// Muestra el diálogo de configuración inicial
  Future<void> _showSetupDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => OllamaSetupDialog(
        localOllamaService: chatProvider.aiSelector.localOllamaService,
      ),
    );

    if (result == true && context.mounted) {
      if (chatProvider.localOllamaStatus == LocalOllamaStatus.ready) {
        await _selectProvider(context, AIProvider.localOllama);
        
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('IA Local configurada y lista'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<void> _selectProvider(BuildContext context, AIProvider provider) async {
    try {
      await chatProvider.selectProvider(provider);
    } catch (e) {
      if (!context.mounted) return;
      _showError(context, 'Error seleccionando proveedor: $e');
    }
  }

  void _showFeedback(BuildContext context, String message, {bool isSuccess = false, bool isLoading = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isLoading) ...[
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isSuccess ? Colors.green : null,
        duration: isLoading ? const Duration(seconds: 30) : const Duration(seconds: 2),
      ),
    );
  }
}

class _LocalModelTile extends StatelessWidget {
  final LocalOllamaModel model;
  final bool isInstalled;
  final bool isCurrent;
  final bool isLoading;
  final VoidCallback onTap;

  const _LocalModelTile({
    required this.model,
    required this.isInstalled,
    required this.isCurrent,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isCurrent ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isCurrent
              ? Theme.of(context).colorScheme.primary.withAlpha(40)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isCurrent
              ? Border.all(color: Theme.of(context).colorScheme.primary.withAlpha(100))
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        model.displayName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                          color: isCurrent
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                      if (model.isRecommended) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'TOP',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onTertiaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusIcon(context),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIcon(BuildContext context) {
    if (isLoading && !isInstalled) {
      return const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    
    if (isCurrent) {
      return Icon(
        Icons.radio_button_checked,
        color: Theme.of(context).colorScheme.primary,
        size: 20,
      );
    }
    
    if (isInstalled) {
      return Icon(
        Icons.radio_button_unchecked,
        color: Theme.of(context).colorScheme.outline,
        size: 20,
      );
    }
    
    // No instalado - Botón de descarga
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            model.estimatedSize,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
          ),
          const SizedBox(width: 4),
          Icon(
            Icons.download_rounded,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// WIDGETS COMPARTIDOS
// =============================================================================

/// Tarjeta base para opciones de proveedor
class _ProviderOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final bool isAvailable;
  final String? statusBadge;
  final VoidCallback? onTap;

  const _ProviderOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.isAvailable,
    this.statusBadge,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isAvailable ? onTap : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isAvailable ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withAlpha(25)
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outline.withAlpha(51),
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : (isAvailable
                        ? Theme.of(context).colorScheme.onSurfaceVariant
                        : Theme.of(context).colorScheme.outline),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                        ),
                        if (statusBadge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              statusBadge!,
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Contenedor para listas de modelos
class _ModelListContainer extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final Widget child;

  const _ModelListContainer({
    required this.title,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// Badge indicador de conexión remota
class _ConnectionIndicatorBadge extends StatelessWidget {
  final ConnectionInfo info;

  const _ConnectionIndicatorBadge({required this.info});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 6, color: color),
          const SizedBox(width: 4),
          Text(
            _getStatusText(),
            style: TextStyle(fontSize: 10, color: color),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (info.status) {
      case ConnectionStatus.connected:
        return Colors.green;
      case ConnectionStatus.connecting:
        return Colors.orange;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText() {
    switch (info.status) {
      case ConnectionStatus.connected:
        return 'Conectado';
      case ConnectionStatus.connecting:
        return 'Conectando...';
      case ConnectionStatus.disconnected:
        return 'Desconectado';
      case ConnectionStatus.error:
        return 'Error';
    }
  }
}

/// Badge indicador de estado local
class _LocalStatusBadge extends StatelessWidget {
  final LocalOllamaStatus status;

  const _LocalStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor();
    
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(100),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (status) {
      case LocalOllamaStatus.notInitialized:
        return Colors.grey;
      case LocalOllamaStatus.checkingInstallation:
      case LocalOllamaStatus.downloadingInstaller:
      case LocalOllamaStatus.installing:
      case LocalOllamaStatus.downloadingModel:
      case LocalOllamaStatus.starting:
      case LocalOllamaStatus.loading:
        return Colors.orange;
      case LocalOllamaStatus.ready:
        return Colors.green;
      case LocalOllamaStatus.error:
        return Colors.red;
    }
  }
}

// =============================================================================
// UTILIDADES
// =============================================================================

class _ProviderUtils {
  static IconData getIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return Icons.auto_awesome;
      case AIProvider.ollama:
        return Icons.dns;
      case AIProvider.openai:
        return Icons.chat_bubble;
      case AIProvider.localOllama:
        return Icons.computer;
    }
  }

  static String getDisplayName(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Gemini';
      case AIProvider.ollama:
        return 'Ollama (Remoto)';
      case AIProvider.openai:
        return 'ChatGPT';
      case AIProvider.localOllama:
        return 'Ollama Local';
    }
  }

  static String getCurrentModelName(ChatProvider chatProvider) {
    switch (chatProvider.currentProvider) {
      case AIProvider.gemini:
        return 'gemini-2.5-flash';
      case AIProvider.ollama:
        return chatProvider.currentModel.replaceAll(':latest', '');
      case AIProvider.openai:
        return chatProvider.currentOpenAIModel;
      case AIProvider.localOllama:
        final currentModel = chatProvider.aiSelector.localOllamaService.currentModel;
        if (currentModel == null) return 'No seleccionado';
        
        final modelDef = LocalOllamaModel.recommendedModels.firstWhere(
          (m) => currentModel.startsWith(m.name),
          orElse: () => LocalOllamaModel(
            name: currentModel,
            displayName: currentModel.split(':').first,
            description: '',
            isDownloaded: true,
            estimatedSize: '',
            parametersB: 0,
          ),
        );
        return modelDef.displayName;
    }
  }
}

/// Muestra un mensaje de error
void _showError(BuildContext context, String message) {
  if (!context.mounted) return;
  
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
      duration: const Duration(seconds: 3),
      action: SnackBarAction(
        label: 'OK',
        textColor: Colors.white,
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}