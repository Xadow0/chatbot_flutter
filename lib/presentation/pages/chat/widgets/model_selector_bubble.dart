import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../../data/models/ollama_models.dart';
import '../../../../data/models/ollama_local_models.dart'; // CAMBIADO: nuevo import para Ollama Local
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
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
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
              const SizedBox(width: 8),
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

  // Sección de OpenAI con selector de modelos
  Widget _buildOpenAISection(BuildContext context, ChatProvider chatProvider) {
    final isSelected = chatProvider.currentProvider == AIProvider.openai;
    final isAvailable = chatProvider.openaiAvailable;

    return Column(
      children: [
        InkWell(
          onTap: isAvailable 
            ? () => _selectProvider(context, chatProvider, AIProvider.openai)
            : null,
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
                    Icons.chat_bubble,
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
                            const Expanded(
                              child: Text(
                                'ChatGPT (OpenAI)',
                                style: TextStyle(fontWeight: FontWeight.w500),
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
                                  'API Key requerida',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAvailable 
                            ? 'IA de pago - Mayor calidad'
                            : 'Configura OPENAI_API_KEY en .env',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
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

        // Selector de modelos de OpenAI (solo si está seleccionado)
        if (isSelected && isAvailable) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(76),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modelo GPT',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...chatProvider.availableOpenAIModels.map((model) {
                  final isModelSelected = chatProvider.currentOpenAIModel == model;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () => _selectOpenAIModel(context, chatProvider, model),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isModelSelected 
                            ? Theme.of(context).colorScheme.primary.withAlpha(51)
                            : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isModelSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              size: 16,
                              color: isModelSelected 
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getOpenAIModelDisplayName(model),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isModelSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isModelSelected 
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                    ),
                                  ),
                                  Text(
                                    _getOpenAIModelDescription(model),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Sección de Ollama (servidor remoto)
  Widget _buildOllamaSection(BuildContext context, ChatProvider chatProvider) {
    final isSelected = chatProvider.currentProvider == AIProvider.ollama;
    final isAvailable = chatProvider.ollamaAvailable;
    final connectionInfo = chatProvider.connectionInfo;

    return Column(
      children: [
        InkWell(
          onTap: isAvailable 
            ? () => _selectProvider(context, chatProvider, AIProvider.ollama)
            : null,
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
                            const Expanded(
                              child: Text(
                                'Ollama (Servidor Remoto)',
                                style: TextStyle(fontWeight: FontWeight.w500),
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
                                  'No conectado',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onErrorContainer,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isAvailable 
                            ? 'Servidor Ubuntu - Phi3 y Mistral'
                            : 'Servidor no accesible',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (isAvailable && connectionInfo.isHealthy) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _buildConnectionIndicator(connectionInfo),
                              const SizedBox(width: 8),
                              Text(
                                connectionInfo.url.replaceAll('http://', ''),
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isAvailable)
                    IconButton(
                      onPressed: () => _refreshOllama(context, chatProvider),
                      icon: const Icon(Icons.refresh, size: 20),
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

        // Selector de modelos de Ollama (solo si está seleccionado y disponible)
        if (isSelected && isAvailable && chatProvider.availableModels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(76),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modelos Disponibles',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ...chatProvider.availableModels.map((model) {
                  final isModelSelected = chatProvider.currentModel == model.name;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: InkWell(
                      onTap: () => _selectModel(context, chatProvider, model.name),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isModelSelected 
                            ? Theme.of(context).colorScheme.primary.withAlpha(51)
                            : null,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isModelSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              size: 16,
                              color: isModelSelected 
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    model.displayName,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isModelSelected ? FontWeight.w600 : FontWeight.w500,
                                      color: isModelSelected 
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
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // MODIFICADO: Sección de Ollama Local (sin descarga de modelos)
  Widget _buildLocalLLMSection(BuildContext context, ChatProvider chatProvider) {
    final isSelected = chatProvider.currentProvider == AIProvider.localLLM;
    final status = chatProvider.localLLMStatus;
    final isAvailable = status == OllamaLocalStatus.ready;
    final isConnecting = status == OllamaLocalStatus.connecting;
    final hasError = status == OllamaLocalStatus.error;

    return Column(
      children: [
        InkWell(
          onTap: isAvailable 
            ? () => _selectProvider(context, chatProvider, AIProvider.localLLM)
            : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                ? Theme.of(context).colorScheme.primary.withAlpha(25)
                : (isConnecting 
                    ? Theme.of(context).colorScheme.secondary.withAlpha(13)
                    : null),
              borderRadius: BorderRadius.circular(12),
              border: isSelected 
                ? Border.all(color: Theme.of(context).colorScheme.primary)
                : Border.all(color: Theme.of(context).colorScheme.outline.withAlpha(51)),
            ),
            child: Column(
              children: [
                Row(
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
                              const Expanded(
                                child: Text(
                                  'Ollama Local',
                                  style: TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ),
                              // Badge de estado
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(status, context),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.displayText,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
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
                    const SizedBox(width: 8),
                    
                    // Botones de acción según el estado
                    if (isConnecting)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else if (hasError)
                      IconButton(
                        onPressed: () => _showLocalLLMError(context, chatProvider),
                        icon: const Icon(Icons.info_outline, size: 20),
                        tooltip: 'Ver detalles del error',
                      )
                    else if (!isAvailable)
                      IconButton(
                        onPressed: () => _startLocalLLM(context, chatProvider),
                        icon: const Icon(Icons.play_arrow, size: 20),
                        tooltip: 'Iniciar Ollama Local',
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          const SizedBox(width: 4),
                          IconButton(
                            onPressed: () => _stopLocalLLM(context, chatProvider),
                            icon: const Icon(Icons.stop, size: 20),
                            tooltip: 'Detener modelo',
                          ),
                        ],
                      ),
                  ],
                ),
                
                // Información adicional cuando está listo
                if (isAvailable && chatProvider.localLLMService.availableModels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Modelo activo: ${chatProvider.localLLMService.currentModel}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (chatProvider.localLLMService.availableModels.length > 1)
                        Text(
                          '${chatProvider.localLLMService.availableModels.length} modelos',
                          style: TextStyle(
                            fontSize: 10,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        
        // NUEVO: Información sobre cómo configurar Ollama Local
        if (status == OllamaLocalStatus.stopped) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(76),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline,
                      size: 16,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Requisitos',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '1. Instala Ollama: https://ollama.com',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '2. Ejecuta: ollama serve',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '3. Descarga modelo: ollama pull phi3',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  // Indicador de conexión para Ollama remoto
  Widget _buildConnectionIndicator(ConnectionInfo info) {
    Color color;
    switch (info.status) {
      case ConnectionStatus.connected:
        color = Colors.green;
        break;
      case ConnectionStatus.connecting:
        color = Colors.orange;
        break;
      case ConnectionStatus.error:
      case ConnectionStatus.disconnected:
        color = Colors.red;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // NUEVO: Indicador de estado para Ollama Local
  Widget _buildLocalLLMIndicator(BuildContext context, OllamaLocalStatus status) {
    Color color;
    switch (status) {
      case OllamaLocalStatus.ready:
        color = Colors.green;
        break;
      case OllamaLocalStatus.connecting:
        color = Colors.orange;
        break;
      case OllamaLocalStatus.error:
        color = Colors.red;
        break;
      case OllamaLocalStatus.stopped:
        color = Colors.grey;
        break;
    }

    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }

  // Helper para obtener color según estado
  Color _getStatusColor(OllamaLocalStatus status, BuildContext context) {
    switch (status) {
      case OllamaLocalStatus.stopped:
        return Colors.grey;
      case OllamaLocalStatus.connecting:
        return Colors.orange;
      case OllamaLocalStatus.ready:
        return Colors.green;
      case OllamaLocalStatus.error:
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
      case AIProvider.localLLM:
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
      case AIProvider.localLLM:
        return 'Ollama Local';
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
        // Mostrar el modelo actual de Ollama Local
        return chatProvider.localLLMService.currentModel;
    }
  }

  // Obtener subtítulo según estado de Ollama Local
  String _getLocalLLMSubtitle(OllamaLocalStatus status) {
    switch (status) {
      case OllamaLocalStatus.stopped:
        return 'Ejecuta Ollama en tu PC - Completamente privado';
      case OllamaLocalStatus.connecting:
        return 'Conectando con Ollama...';
      case OllamaLocalStatus.ready:
        return 'Listo - 100% privado y sin internet';
      case OllamaLocalStatus.error:
        return 'Error al conectar - Toca para ver detalles';
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

  // MODIFICADO: Iniciar Ollama Local (sin descarga de modelos)
  Future<void> _startLocalLLM(BuildContext context, ChatProvider chatProvider) async {
    bool loadingShown = false;
    try {
      // Mostrar diálogo de carga mientras se conecta
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
              Text('Conectando con Ollama Local...'),
              SizedBox(height: 8),
              Text(
                'Verificando servidor y modelos',
                style: TextStyle(fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );

      final result = await chatProvider.initializeLocalLLM();

      // Cerrar diálogo de carga
      if (loadingShown && context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (result.success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${result.modelName} listo'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } else {
        _showError(context, result.error ?? 'Error al conectar');
      }
    } catch (e) {
      if (loadingShown && context.mounted && Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }
      _showError(context, 'Error iniciando Ollama Local: $e');
    }
  }

  Future<void> _stopLocalLLM(BuildContext context, ChatProvider chatProvider) async {
    try {
      await chatProvider.stopLocalLLM();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ollama Local detenido'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showError(context, 'Error deteniendo: $e');
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
            Text('Error de Ollama Local'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(error),
              const SizedBox(height: 16),
              const Text(
                '💡 Soluciones:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('• Verifica que Ollama esté ejecutándose (ollama serve)'),
              const Text('• Comprueba que el modelo esté descargado (ollama list)'),
              const Text('• Reinicia Ollama y prueba de nuevo'),
            ],
          ),
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