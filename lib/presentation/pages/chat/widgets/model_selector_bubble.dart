import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../../data/models/ollama_models.dart';
import '../../../../data/services/ai_service_selector.dart';

class ModelSelectorBubble extends StatelessWidget {
  const ModelSelectorBubble({Key? key}) : super(key: key);

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
            // Indicador de estado de conexión (solo para Ollama)
            if (chatProvider.currentProvider == AIProvider.ollama)
              _buildConnectionIndicator(chatProvider.connectionInfo),
            if (chatProvider.currentProvider == AIProvider.ollama)
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

  IconData _getProviderIcon(AIProvider provider) {
    switch (provider) {
      case AIProvider.gemini:
        return Icons.auto_awesome;
      case AIProvider.ollama:
        return Icons.computer;
      case AIProvider.openai:
        return Icons.bolt;
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
      // Usar el método del provider que guarda la preferencia
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