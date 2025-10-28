import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../../data/models/ollama_models.dart';
import '../../../../data/models/local_ollama_models.dart';
import '../../../../data/services/ai_service_selector.dart';
import '../../dialogs/ollama_setup_dialog.dart';

class ModelSelectorBubble extends StatelessWidget {
  const ModelSelectorBubble({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, chatProvider, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: chatProvider.showModelSelector ? null : 56,
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
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
            ),
            child: chatProvider.showModelSelector
                ? _buildExpandedSelector(context, chatProvider)
                : _buildCollapsedButton(context, chatProvider),
          ),
        );
      },
    );
  }

  Widget _buildCollapsedButton(BuildContext context, ChatProvider chatProvider) {
    return InkWell(
      onTap: () => chatProvider.toggleModelSelector(),
      borderRadius: BorderRadius.circular(28),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Indicador de estado de conexión (solo para Ollama remoto)
            if (chatProvider.currentProvider == AIProvider.ollama)
              _buildConnectionIndicator(chatProvider.connectionInfo),
            if (chatProvider.currentProvider == AIProvider.ollama)
              const SizedBox(width: 8),
            
            // Indicador de estado para Ollama Local
            if (chatProvider.currentProvider == AIProvider.localOllama)
              _buildLocalLLMIndicator(context, chatProvider.localOllamaStatus),
            if (chatProvider.currentProvider == AIProvider.localOllama)
              const SizedBox(width: 8),
            
            // Icono del proveedor actual
            Icon(
              _getProviderIcon(chatProvider.currentProvider),
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            
            // Texto del modelo actual
            Flexible(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getProviderDisplayName(chatProvider.currentProvider),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _getCurrentModelDisplayName(chatProvider),
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

  Widget _buildExpandedSelector(BuildContext context, ChatProvider chatProvider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con botón de cerrar
          Row(
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
                onPressed: () => chatProvider.hideModelSelector(),
                icon: const Icon(Icons.close),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.zero,
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Opción Gemini
          _buildProviderOption(
            context: context,
            chatProvider: chatProvider,
            provider: AIProvider.gemini,
            title: 'Gemini (Google)',
            subtitle: 'IA en la nube - Gratis con límites',
            icon: Icons.auto_awesome,
            isSelected: chatProvider.currentProvider == AIProvider.gemini,
            isAvailable: true,
            onTap: () => _selectProvider(context, chatProvider, AIProvider.gemini),
          ),
          
          const SizedBox(height: 8),
          
          // Opción OpenAI
          _buildOpenAISection(context, chatProvider),
          
          const SizedBox(height: 8),
          
          // Sección Ollama (servidor remoto)
          _buildOllamaSection(context, chatProvider),
          
          const SizedBox(height: 8),
          
          // Sección Ollama Local
          _buildLocalLLMSection(context, chatProvider),
        ],
      ),
    );
  }

  Widget _buildProviderOption({
    required BuildContext context,
    required ChatProvider chatProvider,
    required AIProvider provider,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required bool isAvailable,
    required VoidCallback onTap,
  }) {
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
            border: isSelected 
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(51)),
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
                        if (!isAvailable)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'No disponible',
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
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
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOpenAISection(BuildContext context, ChatProvider chatProvider) {
    final isSelected = chatProvider.currentProvider == AIProvider.openai;
    final isAvailable = chatProvider.openaiAvailable;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botón principal de OpenAI
        _buildProviderOption(
          context: context,
          chatProvider: chatProvider,
          provider: AIProvider.openai,
          title: 'ChatGPT (OpenAI)',
          subtitle: isAvailable 
              ? 'IA en la nube - Requiere API key'
              : 'Requiere API key en .env',
          icon: Icons.chat_bubble,
          isSelected: isSelected,
          isAvailable: isAvailable,
          onTap: () => _selectProvider(context, chatProvider, AIProvider.openai),
        ),

        // Modelos de OpenAI (solo si está seleccionado y disponible)
        if (isSelected && isAvailable) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modelo:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                ...chatProvider.availableOpenAIModels.map(
                  (model) => _buildOpenAIModelOption(
                    context: context,
                    chatProvider: chatProvider,
                    modelName: model,
                    isSelected: chatProvider.currentOpenAIModel == model,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOpenAIModelOption({
    required BuildContext context,
    required ChatProvider chatProvider,
    required String modelName,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _selectOpenAIModel(context, chatProvider, modelName),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withAlpha(13)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary.withAlpha(77),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _getOpenAIModelDisplayName(modelName),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  Text(
                    _getOpenAIModelDescription(modelName),
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOllamaSection(BuildContext context, ChatProvider chatProvider) {
    final isSelected = chatProvider.currentProvider == AIProvider.ollama;
    final isAvailable = chatProvider.ollamaAvailable;
    final connectionInfo = chatProvider.connectionInfo;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botón principal de Ollama
        InkWell(
          onTap: isAvailable ? () => _selectProvider(context, chatProvider, AIProvider.ollama) : null,
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
                border: isSelected 
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(51)),
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
                            Expanded(
                              child: Text(
                                'Ollama (Servidor Remoto)',
                                style: TextStyle(
                                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  color: isSelected 
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                ),
                              ),
                            ),
                            if (!isAvailable)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Desconectado',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              )
                            else
                              _buildConnectionIndicator(connectionInfo),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAvailable 
                              ? 'Conectado a ${connectionInfo.url}'
                              : 'Servidor en red local - No conectado',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isAvailable)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 18),
                      onPressed: () => _refreshOllama(context, chatProvider),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                      tooltip: 'Actualizar conexión',
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
        ),

        // Modelos de Ollama (solo si está seleccionado y disponible)
        if (isSelected && isAvailable && chatProvider.availableModels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modelo:',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                ...chatProvider.availableModels.map(
                  (model) => _buildModelOption(
                    context: context,
                    chatProvider: chatProvider,
                    model: model,
                    isSelected: chatProvider.currentModel == model.name,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildModelOption({
    required BuildContext context,
    required ChatProvider chatProvider,
    required OllamaModel model,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _selectModel(context, chatProvider, model.name),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected 
              ? Theme.of(context).colorScheme.primary.withAlpha(13)
              : null,
          borderRadius: BorderRadius.circular(8),
          border: isSelected 
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary.withAlpha(77),
                )
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name.replaceAll(':latest', ''),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected 
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
                  ),
                  Text(
                    model.sizeFormatted,
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check,
                color: Theme.of(context).colorScheme.primary,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocalLLMSection(BuildContext context, ChatProvider chatProvider) {
    final isSelected = chatProvider.currentProvider == AIProvider.localOllama;
    final status = chatProvider.localOllamaStatus;
    final isAvailable = status == LocalOllamaStatus.ready;
    final isLoading = chatProvider.localOllamaLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Botón principal de Ollama Local
        InkWell(
          onTap: () {
            if (isAvailable) {
              _selectProvider(context, chatProvider, AIProvider.localOllama);
            } else if (status == LocalOllamaStatus.notInitialized) {
              _startLocalLLM(context, chatProvider);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primary.withAlpha(25)
                  : null,
              borderRadius: BorderRadius.circular(12),
              border: isSelected 
                  ? Border.all(color: Theme.of(context).colorScheme.primary)
                  : Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(51)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.computer,
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
                              'Ollama Local (Embebido)',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isSelected 
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                              ),
                            ),
                          ),
                          _buildLocalLLMIndicator(context, status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getLocalLLMSubtitle(status),
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (status == LocalOllamaStatus.notInitialized)
                  Icon(
                    Icons.play_circle_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 24,
                  )
                else if (status == LocalOllamaStatus.error)
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 20),
                    onPressed: () => _retryLocalLLM(context, chatProvider),
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.all(4),
                    tooltip: 'Reintentar',
                  )
                else if (isSelected)
                  Icon(
                    Icons.check_circle,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
              ],
            ),
          ),
        ),

        // Información adicional cuando está seleccionado
        if (isSelected && isAvailable) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(128),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ollama ejecutándose localmente',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '🔒 100% privado - Sin enviar datos a la nube',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '💻 Modelo: ${chatProvider.aiSelector.localOllamaService.currentModel}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectionIndicator(ConnectionInfo info) {
    Color color;
    IconData icon;

    switch (info.status) {
      case ConnectionStatus.connected:
        color = Colors.green;
        icon = Icons.circle;
        break;
      case ConnectionStatus.disconnected:
        color = Colors.red;
        icon = Icons.circle;
        break;
      case ConnectionStatus.connecting:
        color = Colors.orange;
        icon = Icons.circle;
        break;
      case ConnectionStatus.error:
        color = Colors.red;
        icon = Icons.error;
        break;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 8, color: color),
        const SizedBox(width: 4),
        Text(
          info.statusText,
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLocalLLMIndicator(BuildContext context, LocalOllamaStatus status) {
    Color color = _getStatusColor(status, context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(77)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            status.displayText,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _getLocalLLMSubtitle(LocalOllamaStatus status) {
    switch (status) {
      case LocalOllamaStatus.notInitialized:
        return '100% privado - Toca para iniciar';
      case LocalOllamaStatus.checkingInstallation:
        return 'Verificando instalación...';
      case LocalOllamaStatus.downloadingInstaller:
        return 'Descargando Ollama...';
      case LocalOllamaStatus.installing:
        return 'Instalando Ollama...';
      case LocalOllamaStatus.downloadingModel:
        return 'Descargando modelo de IA...';
      case LocalOllamaStatus.starting:
        return 'Iniciando servidor local...';
      case LocalOllamaStatus.ready:
        return '100% privado - Listo para usar';
      case LocalOllamaStatus.error:
        return 'Error - Toca para reintentar';
    }
  }

  // Helper para obtener color según estado
  Color _getStatusColor(LocalOllamaStatus status, BuildContext context) {
    switch (status) {
      case LocalOllamaStatus.notInitialized:
        return Colors.grey;
      case LocalOllamaStatus.checkingInstallation:
      case LocalOllamaStatus.downloadingInstaller:
      case LocalOllamaStatus.installing:
      case LocalOllamaStatus.downloadingModel:
      case LocalOllamaStatus.starting:
        return Colors.orange;
      case LocalOllamaStatus.ready:
        return Colors.green;
      case LocalOllamaStatus.error:
        return Colors.red;
    }
  }

  IconData _getProviderIcon(AIProvider provider) {
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

  String _getProviderDisplayName(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Gemini';
      case AIProvider.ollama:
        return 'Ollama (Remoto)';
      case AIProvider.openai:
        return 'ChatGPT';
      case AIProvider.localOllama:
        return 'Ollama Local Embebido';
    }
  }

  String _getCurrentModelDisplayName(ChatProvider chatProvider) {
    switch (chatProvider.currentProvider) {
      case AIProvider.gemini:
        return 'gemini-2.5-flash';
      case AIProvider.ollama:
        return chatProvider.currentModel.replaceAll(':latest', '');
      case AIProvider.openai:
        return chatProvider.currentOpenAIModel;
      case AIProvider.localOllama:
        // Mostrar el modelo actual de Ollama Local
        return chatProvider.aiSelector.localOllamaService.currentModel ?? 'phi3';
    }
  }


  String _getOpenAIModelDisplayName(String modelName) {
    return modelName.toUpperCase();
  }

  String _getOpenAIModelDescription(String modelName) {
    switch (modelName) {
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

  Future<void> _selectProvider(BuildContext context, ChatProvider chatProvider, AIProvider provider) async {
    try {
      await chatProvider.changeProvider(provider);
    } catch (e) {
      _showError(context, 'Error cambiando proveedor: $e');
    }
  }

  Future<void> _selectModel(BuildContext context, ChatProvider chatProvider, String modelName) async {
    try {
      await chatProvider.changeModel(modelName);
    } catch (e) {
      _showError(context, 'Error cambiando modelo: $e');
    }
  }

  Future<void> _selectOpenAIModel(BuildContext context, ChatProvider chatProvider, String modelName) async {
    try {
      await chatProvider.changeOpenAIModel(modelName);
    } catch (e) {
      _showError(context, 'Error cambiando modelo OpenAI: $e');
    }
  }

  Future<void> _refreshOllama(BuildContext context, ChatProvider chatProvider) async {
    try {
      await chatProvider.refreshModels();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Conexión actualizada'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showError(context, 'Error refrescando: $e');
    }
  }

  // Iniciar Ollama Local con diálogo
  Future<void> _startLocalLLM(BuildContext context, ChatProvider chatProvider) async {
    try {
      // Mostrar diálogo de configuración
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => OllamaSetupDialog(
          localOllamaService: chatProvider.aiSelector.localOllamaService,
        ),
      );

      if (result == null || !result) {
        // Usuario canceló
        debugPrint('   ℹ️ Usuario canceló la configuración');
        return;
      }

    } catch (e) {
      _showError(context, 'Error iniciando Ollama Local: $e');
    }
  }

  Future<void> _retryLocalLLM(BuildContext context, ChatProvider chatProvider) async {
    await _startLocalLLM(context, chatProvider);
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}