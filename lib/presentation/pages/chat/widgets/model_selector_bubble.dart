import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../widgets/model_download_dialog.dart';
import '../../../../data/models/ollama_models.dart';
import '../../../../data/models/local_llm_models.dart';
import '../../../../data/services/ai_service_selector.dart';

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
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
            // Indicador de estado de conexión (solo para Ollama y LLM Local)
            if (chatProvider.currentProvider == AIProvider.ollama)
              _buildConnectionIndicator(chatProvider.connectionInfo),
            if (chatProvider.currentProvider == AIProvider.ollama)
              const SizedBox(width: 8),
            
            // NUEVO: Indicador de estado para LLM Local
            if (chatProvider.currentProvider == AIProvider.localLLM)
              _buildLocalLLMIndicator(context, chatProvider.localLLMStatus),
            if (chatProvider.currentProvider == AIProvider.localLLM)
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
          
          // Sección Ollama
          _buildOllamaSection(context, chatProvider),
          
          const SizedBox(height: 8),
          
          // NUEVA: Sección LLM Local
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
              ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
              : null,
            borderRadius: BorderRadius.circular(12),
            border: isSelected 
              ? Border.all(color: Theme.of(context).colorScheme.primary)
              : Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
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
                              'No configurado',
                              style: TextStyle(
                                fontSize: 9,
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
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

  Widget _buildOpenAISection(BuildContext context, ChatProvider chatProvider) {
    final isOpenAISelected = chatProvider.currentProvider == AIProvider.openai;
    final isAvailable = chatProvider.openaiAvailable;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de OpenAI
        InkWell(
          onTap: isAvailable ? () => _selectProvider(context, chatProvider, AIProvider.openai) : null,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: isAvailable ? 1.0 : 0.5,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOpenAISelected 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : null,
                borderRadius: BorderRadius.circular(12),
                border: isOpenAISelected 
                  ? Border.all(color: Theme.of(context).colorScheme.primary)
                  : Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.bolt,
                    color: isOpenAISelected 
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
                            Text(
                              'OpenAI (ChatGPT)',
                              style: TextStyle(
                                fontWeight: isOpenAISelected ? FontWeight.w600 : FontWeight.w500,
                                color: isOpenAISelected 
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!isAvailable)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'API Key requerida',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Text(
                          isAvailable 
                            ? 'GPT-4o, GPT-4o-mini - De pago' 
                            : 'Configura OPENAI_API_KEY en .env',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isOpenAISelected)
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
        
        // Lista de modelos OpenAI (si está disponible y seleccionado)
        if (isAvailable && isOpenAISelected && chatProvider.availableOpenAIModels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(left: 44),
            child: Column(
              children: chatProvider.availableOpenAIModels.map((modelName) {
                final isSelected = chatProvider.currentOpenAIModel == modelName;
                return _buildOpenAIModelOption(
                  context: context,
                  modelName: modelName,
                  isSelected: isSelected,
                  onTap: () => _selectOpenAIModel(context, chatProvider, modelName),
                );
              }).toList(),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOpenAIModelOption({
    required BuildContext context,
    required String modelName,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
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
                    _getOpenAIModelDisplayName(modelName),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected 
                        ? Theme.of(context).colorScheme.primary
                        : null,
                    ),
                  ),
                  Text(
                    _getOpenAIModelDescription(modelName),
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

  Widget _buildOllamaSection(BuildContext context, ChatProvider chatProvider) {
    final isOllamaSelected = chatProvider.currentProvider == AIProvider.ollama;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de Ollama con estado
        InkWell(
          onTap: chatProvider.ollamaAvailable 
            ? () => _selectProvider(context, chatProvider, AIProvider.ollama)
            : null,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: chatProvider.ollamaAvailable ? 1.0 : 0.5,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOllamaSelected 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : null,
                borderRadius: BorderRadius.circular(12),
                border: isOllamaSelected 
                  ? Border.all(color: Theme.of(context).colorScheme.primary)
                  : Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.computer,
                    color: chatProvider.ollamaAvailable
                      ? (isOllamaSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)
                      : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Ollama (Local)',
                              style: TextStyle(
                                fontWeight: isOllamaSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isOllamaSelected 
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildConnectionIndicator(chatProvider.connectionInfo),
                          ],
                        ),
                        Text(
                          chatProvider.ollamaAvailable 
                            ? 'IA en tu servidor - Gratis y privado' 
                            : 'No disponible - Verificar Tailscale',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Botón de refrescar
                  IconButton(
                    onPressed: () => _refreshOllama(context, chatProvider),
                    icon: const Icon(Icons.refresh),
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                    tooltip: 'Refrescar conexión',
                  ),
                  if (isOllamaSelected)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: Icon(
                        Icons.check_circle,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        
        // Lista de modelos (si Ollama está disponible)
        if (chatProvider.ollamaAvailable && chatProvider.availableModels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(left: 44),
            child: Column(
              children: chatProvider.availableModels.map((model) {
                final isSelected = isOllamaSelected && 
                                 chatProvider.currentModel == model.name;
                return _buildModelOption(
                  context: context,
                  model: model,
                  isSelected: isSelected,
                  onTap: () => _selectModel(context, chatProvider, model.name),
                );
              }).toList(),
            ),
          ),
        ] else if (chatProvider.ollamaAvailable) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(left: 44),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'No hay modelos disponibles.\nDescarga modelos: ollama pull phi3',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.error,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // NUEVA SECCIÓN: LLM Local
  Widget _buildLocalLLMSection(BuildContext context, ChatProvider chatProvider) {
    final isLocalLLMSelected = chatProvider.currentProvider == AIProvider.localLLM;
    final status = chatProvider.localLLMStatus;
    final isAvailable = status == LocalLLMStatus.ready;
    final isLoading = status == LocalLLMStatus.loading;
    final isStopped = status == LocalLLMStatus.stopped;
    final isError = status == LocalLLMStatus.error;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header del LLM Local
        InkWell(
          onTap: isAvailable ? () => _selectProvider(context, chatProvider, AIProvider.localLLM) : null,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            opacity: isAvailable ? 1.0 : 0.6,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isLocalLLMSelected 
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                  : null,
                borderRadius: BorderRadius.circular(12),
                border: isLocalLLMSelected 
                  ? Border.all(color: Theme.of(context).colorScheme.primary)
                  : Border.all(color: Theme.of(context).colorScheme.outline.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.phone_android,
                    color: isAvailable
                      ? (isLocalLLMSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurfaceVariant)
                      : Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'LLM en Dispositivo',
                              style: TextStyle(
                                fontWeight: isLocalLLMSelected ? FontWeight.w600 : FontWeight.w500,
                                color: isLocalLLMSelected 
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _buildLocalLLMIndicator(context, status),
                          ],
                        ),
                        Text(
                          _getLocalLLMSubtitle(status),
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Botones de acción según el estado
                  if (isStopped) ...[
                    TextButton.icon(
                      onPressed: () => _startLocalLLM(context, chatProvider),
                      icon: const Icon(Icons.play_arrow, size: 16),
                      label: const Text('Iniciar', style: TextStyle(fontSize: 12)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ] else if (isLoading) ...[
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ] else if (isError) ...[
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => _showLocalLLMError(context, chatProvider),
                          icon: const Icon(Icons.info_outline, size: 16),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                          tooltip: 'Ver error',
                        ),
                        const SizedBox(width: 4),
                        TextButton.icon(
                          onPressed: () => _retryLocalLLM(context, chatProvider),
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Reintentar', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ],
                    ),
                  ] else if (isAvailable) ...[
                    Row(
                      children: [
                        if (!isLocalLLMSelected)
                          IconButton(
                            onPressed: () => _stopLocalLLM(context, chatProvider),
                            icon: const Icon(Icons.stop, size: 16),
                            constraints: const BoxConstraints(),
                            padding: EdgeInsets.zero,
                            tooltip: 'Detener modelo',
                          ),
                        if (isLocalLLMSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        
        // Info adicional cuando está listo
        if (isAvailable && !isLocalLLMSelected) ...[
          const SizedBox(height: 8),
          Container(
            margin: const EdgeInsets.only(left: 44),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  size: 14,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Modelo Phi-3 cargado y listo para usar',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
    required OllamaModel model,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isSelected 
            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
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
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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

  Widget _buildConnectionIndicator(ConnectionInfo info) {
    Color color;
    IconData icon;
    
    switch (info.status) {
      case ConnectionStatus.connected:
        color = Colors.green;
        icon = Icons.circle;
        break;
      case ConnectionStatus.connecting:
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case ConnectionStatus.disconnected:
        color = Colors.grey;
        icon = Icons.circle_outlined;
        break;
      case ConnectionStatus.error:
        color = Colors.red;
        icon = Icons.error;
        break;
    }
    
    return Icon(icon, color: color, size: 12);
  }

  // NUEVO: Indicador de estado para LLM Local
  Widget _buildLocalLLMIndicator(BuildContext context, LocalLLMStatus status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case LocalLLMStatus.stopped:
        color = Colors.grey;
        icon = Icons.circle_outlined;
        break;
      case LocalLLMStatus.loading:
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case LocalLLMStatus.ready:
        color = Colors.green;
        icon = Icons.circle;
        break;
      case LocalLLMStatus.error:
        color = Colors.red;
        icon = Icons.error;
        break;
    }
    
    return Icon(icon, color: color, size: 12);
  }

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return Icons.auto_awesome;
      case AIProvider.ollama:
        return Icons.computer;
      case AIProvider.openai:
        return Icons.bolt;
      case AIProvider.localLLM:
        return Icons.phone_android;
    }
  }

  String _getProviderDisplayName(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return 'Gemini';
      case AIProvider.ollama:
        return 'Ollama';
      case AIProvider.openai:
        return 'ChatGPT';
      case AIProvider.localLLM:
        return 'LLM Local';
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
      case AIProvider.localLLM:
        return 'Phi-3 Mini';
    }
  }

  // NUEVO: Obtener subtítulo según estado del LLM local
  String _getLocalLLMSubtitle(LocalLLMStatus status) {
    switch (status) {
      case LocalLLMStatus.stopped:
        return 'Modelo detenido - No consume recursos';
      case LocalLLMStatus.loading:
        return 'Cargando modelo en memoria...';
      case LocalLLMStatus.ready:
        return 'Modelo Phi-3 - Privado y sin internet';
      case LocalLLMStatus.error:
        return 'Error al cargar el modelo';
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

  // NUEVOS MÉTODOS: Gestión del LLM Local
  Future<void> _startLocalLLM(BuildContext context, ChatProvider chatProvider) async {
    bool loadingShown = false;
    try {
      final localService = chatProvider.aiSelector.localLLMService;

      // Si el modelo no está descargado, mostrar diálogo de descarga
      if (!await localService.isModelDownloaded()) {
        final downloadResult = await showModelDownloadDialog(context, localService.downloadService);

        if (downloadResult == null || !downloadResult.success) {
          // Si el usuario canceló la descarga, volver a la pantalla de Chat Libre
          if (downloadResult != null && downloadResult.error == 'cancelled_by_user') {
            Navigator.pushNamed(context, '/chat', arguments: {'mode': 'free'});
            return;
          }

          // Mostrar error al usuario
          _showError(context, 'No se pudo descargar el modelo: ${downloadResult?.error ?? 'cancelado'}');
          return;
        }
      }

      // Mostrar diálogo de carga mientras se inicializa el modelo
      loadingShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Cargando modelo local...'),
              SizedBox(height: 8),
              Text(
                'Esto puede tardar unos segundos',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
      );

      final result = await chatProvider.initializeLocalLLM();

      // Cerrar diálogo de carga
      if (loadingShown && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${result.modelName} cargado correctamente'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        _showError(context, 'No se pudo cargar el modelo: ${result.error}');
      }
    } catch (e) {
      if (loadingShown && Navigator.canPop(context)) Navigator.of(context).pop();
      _showError(context, 'Error iniciando LLM local: $e');
    }
  }

  Future<void> _stopLocalLLM(BuildContext context, ChatProvider chatProvider) async {
    try {
      await chatProvider.stopLocalLLM();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modelo local detenido'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showError(context, 'Error deteniendo modelo: $e');
    }
  }

  Future<void> _retryLocalLLM(BuildContext context, ChatProvider chatProvider) async {
    await _startLocalLLM(context, chatProvider);
  }

  void _showLocalLLMError(BuildContext context, ChatProvider chatProvider) {
    final error = chatProvider.localLLMError ?? 'Error desconocido';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text('Error del Modelo Local'),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(error),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              _retryLocalLLM(context, chatProvider);
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
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