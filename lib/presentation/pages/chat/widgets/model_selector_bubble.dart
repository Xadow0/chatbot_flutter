import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../providers/chat_provider.dart';
import '../../../../data/models/remote_ollama_models.dart';
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

  Widget _buildOpenAISection(BuildContext context, ChatProvider chatProvider) {
    final isAvailable = chatProvider.openaiAvailable;
    final isSelected = chatProvider.currentProvider == AIProvider.openai;

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
                            const Text(
                              'ChatGPT (OpenAI)',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
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
                        const SizedBox(height: 2),
                        Text(
                          'Requiere API Key (de pago)',
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
        ),
        
        // Lista de modelos OpenAI (solo si está seleccionado y disponible)
        if (isSelected && isAvailable) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Modelo OpenAI',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...chatProvider.availableOpenAIModels.map((modelName) {
                  final isCurrentModel = modelName == chatProvider.currentOpenAIModel;
                  return InkWell(
                    onTap: () => _selectOpenAIModel(context, chatProvider, modelName),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCurrentModel 
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
                                  _getOpenAIModelDisplayName(modelName),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isCurrentModel ? FontWeight.w600 : FontWeight.w500,
                                    color: isCurrentModel 
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
                          if (isCurrentModel)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                        ],
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

  Widget _buildOllamaSection(BuildContext context, ChatProvider chatProvider) {
    final isAvailable = chatProvider.ollamaAvailable;
    final isSelected = chatProvider.currentProvider == AIProvider.ollama;
    final isRetrying = chatProvider.isRetryingOllama;

    return Column(
      children: [
        InkWell(
          // Lógica de Tap:
          // - Si se está reintentando, no hacer nada (null).
          // - Si está disponible, no hacer nada (dejar que los modelos de
          //   abajo manejen el tap)
          // - Si NO está disponible, reintentar la conexión.
          onTap: isRetrying
              ? null
              : !isAvailable
                  ? () => _retryOllamaConnection(context, chatProvider)
                  : null, // Si está disponible, la tarjeta no hace nada al pulsar
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            // Opacidad completa si está disponible o reintentando
            // Opacidad reducida solo si está desconectado y en reposo
            opacity: (isAvailable || isRetrying) ? 1.0 : 0.5,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary.withAlpha(25)
                    : null,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : Border.all(
                        color: Theme.of(context).colorScheme.outline.withAlpha(51)),
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
                              _buildConnectionIndicator(chatProvider.connectionInfo),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          // Texto dinámico según el estado
                          isRetrying
                              ? 'Conectando con servidor...'
                              : isAvailable
                                  ? 'Servidor privado conectado'
                                  : 'Servidor no disponible (Toca para reintentar)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icono dinámico según el estado
                  if (isRetrying)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (isAvailable)
                    // Botón de refrescar (ahora también reintenta)
                    IconButton(
                      icon: const Icon(Icons.refresh, size: 20),
                      onPressed: () => _retryOllamaConnection(context, chatProvider),
                      constraints: const BoxConstraints(),
                      padding: const EdgeInsets.all(8),
                    )
                  else if (isSelected)
                    // Mostrar check si está seleccionado (incluso si no está disponible)
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

        // La lista de modelos solo se muestra si el servidor está disponible
        if (isAvailable && chatProvider.availableModels.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Modelos disponibles (toca para seleccionar)',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                ...chatProvider.availableModels.map((model) {
                  final isCurrentModel =
                      isSelected && model.name == chatProvider.currentModel;
                  return InkWell(
                    // Tocar un modelo selecciona el proveedor Y el modelo
                    onTap: () {
                      debugPrint('🔘 Tocado modelo: ${model.name}');
                      // Asegura que el proveedor Ollama esté activo
                      _selectProvider(context, chatProvider, AIProvider.ollama);
                      // Selecciona el modelo específico
                      _selectModel(context, chatProvider, model.name);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isCurrentModel
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
                                    fontWeight: isCurrentModel
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isCurrentModel
                                        ? Theme.of(context).colorScheme.primary
                                        : null,
                                  ),
                                ),
                                Text(
                                  model.sizeFormatted,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isCurrentModel)
                            Icon(
                              Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary,
                              size: 16,
                            ),
                        ],
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

  Widget _buildLocalLLMSection(BuildContext context, ChatProvider chatProvider) {
    final status = chatProvider.localOllamaStatus;
    final isAvailable = chatProvider.localOllamaAvailable;
    final isSelected = chatProvider.currentProvider == AIProvider.localOllama;
    final isLoading = chatProvider.localOllamaLoading;
    
    // VERIFICAR SOPORTE DE PLATAFORMA
    // Usamos el getter que creamos en el paso 2
    final isPlatformSupported = chatProvider.aiSelector.isLocalOllamaSupported;

    return Column(
      children: [
        InkWell(
          // Si no es soportado, onTap es null (deshabilita el clic)
          onTap: !isPlatformSupported 
            ? null 
            : () {
              if (status == LocalOllamaStatus.notInitialized) {
                _startLocalLLM(context, chatProvider);
              } else if (status == LocalOllamaStatus.error) {
                _retryLocalLLM(context, chatProvider);
              } else if (isAvailable) {
                _selectProvider(context, chatProvider, AIProvider.localOllama);
              }
            },
          borderRadius: BorderRadius.circular(12),
          child: Opacity(
            // Reducimos opacidad si no es soportado o está cargando
            opacity: (!isPlatformSupported || isLoading) ? 0.6 : 1.0,
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
                        // Si no es soportado, icono gris
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
                              'Ollama Local (Embebido)',
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                // Texto tachado o gris si no es soportado (opcional)
                                color: !isPlatformSupported 
                                  ? Theme.of(context).disabledColor 
                                  : null,
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Solo mostramos el indicador de estado si es soportado
                            if (isPlatformSupported)
                              _buildLocalLLMIndicator(context, status),
                          ],
                        ),
                        const SizedBox(height: 2),
                        // LÓGICA DEL SUBTÍTULO
                        if (!isPlatformSupported)
                           Container(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              'NO DISPONIBLE EN ESTE DISPOSITIVO',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.error, // Color rojo/error
                              ),
                            ),
                          )
                        else
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
                  if (isLoading)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    )
                  else if (!isPlatformSupported)
                    // Icono de bloqueo o prohibido para móviles
                    Icon(
                      Icons.block,
                      color: Theme.of(context).disabledColor,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionIndicator(ConnectionInfo info) {
    Color color;
    switch (info.status) {
      case ConnectionStatus.connected:
        color = Colors.green;
        break;
      case ConnectionStatus.connecting:
        color = Colors.orange;
        break;
      case ConnectionStatus.disconnected:
      case ConnectionStatus.error:
        color = Colors.red;
        break;
    }

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
          Icon(
            Icons.circle,
            size: 6,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            info.status == ConnectionStatus.connected ? 'Conectado' : 'Error',
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

  Widget _buildLocalLLMIndicator(BuildContext context, LocalOllamaStatus status) {
    final color = _getStatusColor(status, context);

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
      case LocalOllamaStatus.loading: 
        return 'Cargando modelo en memoria...';
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
      case LocalOllamaStatus.loading:
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
        final currentModel = chatProvider.aiSelector.localOllamaService.currentModel;
        if (currentModel == null) return 'No seleccionado';
        
        // Busca en los modelos recomendados un nombre que coincida
        final modelDef = LocalOllamaModel.recommendedModels.firstWhere(
          (m) => currentModel.startsWith(m.name),
          orElse: () => LocalOllamaModel(
            name: currentModel, 
            displayName: currentModel.split(':').first, // fallback
            description: '', 
            isDownloaded: true, 
            estimatedSize: '', 
            parametersB: 0
          ),
        );
        return modelDef.displayName;
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

  /// Llama al método de reintento en el provider y muestra SnackBars
  Future<void> _retryOllamaConnection(BuildContext context, ChatProvider chatProvider) async {
    if (chatProvider.isRetryingOllama) return; // Evitar clics múltiples
    
    try {
      final success = await chatProvider.retryOllamaConnection();
      
      // Solo mostrar SnackBar si el widget sigue montado
      if (!context.mounted) return;
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Conexión con Ollama (remoto) establecida'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo conectar con el servidor Ollama'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showError(context, 'Error refrescando: $e');
      }
    }
  }

  Future<void> _selectProvider(BuildContext context, ChatProvider chatProvider, AIProvider provider) async {
    try {
      await chatProvider.selectProvider(provider);
    } catch (e) {
      _showError(context, 'Error cambiando proveedor: $e');
    }
  }

  Future<void> _selectModel(BuildContext context, ChatProvider chatProvider, String modelName) async {
    try {
      await chatProvider.selectModel(modelName);
    } catch (e) {
      _showError(context, 'Error cambiando modelo: $e');
    }
  }

  Future<void> _selectOpenAIModel(BuildContext context, ChatProvider chatProvider, String modelName) async {
    try {
      await chatProvider.selectOpenAIModel(modelName);
    } catch (e) {
      _showError(context, 'Error cambiando modelo OpenAI: $e');
    }
  }

  Future<void> _selectLocalOllamaModel(BuildContext context, ChatProvider chatProvider, String modelName) async {
    if (chatProvider.localOllamaLoading) {
      _showError(context, 'Espera a que termine el proceso actual...');
      return;
    }
    try {
      // NOTA: Este método no existe en el provider actual
      // Si necesitas cambiar modelos de Ollama local, deberás agregarlo al provider
      // Por ahora, lo dejamos comentado
      // await chatProvider.selectLocalOllamaModel(modelName);
      _showError(context, 'Función no implementada aún');
    } catch (e) {
      _showError(context, 'Error cambiando modelo local: $e');
    }
  }

  Future<void> _refreshOllama(BuildContext context, ChatProvider chatProvider) async {
    try {
      await chatProvider.refreshConnection();
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

      if (result == true) {
        // Opcional: Verificar que el estado sea 'ready' para mayor seguridad
        if (chatProvider.localOllamaStatus == LocalOllamaStatus.ready) {
           await _selectProvider(context, chatProvider, AIProvider.localOllama);
           
           // Feedback visual opcional
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(
                 content: Text('IA Local lista y seleccionada'),
                 backgroundColor: Colors.green,
                 duration: Duration(seconds: 2),
               ),
             );
           }
        }
      }

    } catch (e) {
      _showError(context, 'Error iniciando Ollama Local: $e');
    }
  }

  Future<void> _retryLocalLLM(BuildContext context, ChatProvider chatProvider) async {
    if (chatProvider.localOllamaLoading) return; 
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