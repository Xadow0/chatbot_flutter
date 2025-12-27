import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/datasources/api_keys_manager.dart';

/// Página para gestionar las API keys desde Settings
class ApiKeysSettingsPage extends StatefulWidget {
  const ApiKeysSettingsPage({super.key});

  @override
  State<ApiKeysSettingsPage> createState() => _ApiKeysSettingsPageState();
}

class _ApiKeysSettingsPageState extends State<ApiKeysSettingsPage> {
  final _apiKeysManager = ApiKeysManager();
  
  // Estado de las keys
  bool _hasGeminiKey = false;
  bool _hasOpenAIKey = false;
  String? _geminiPreview;
  String? _openaiPreview;
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKeysStatus();
  }

  Future<void> _loadKeysStatus() async {
    setState(() => _isLoading = true);
    
    try {
      final status = await _apiKeysManager.getApiKeysStatus();
      _hasGeminiKey = status[ApiKeysManager.geminiApiKeyName] ?? false;
      _hasOpenAIKey = status[ApiKeysManager.openaiApiKeyName] ?? false;
      
      if (_hasGeminiKey) {
        _geminiPreview = await _apiKeysManager.getApiKeyPreview(
          ApiKeysManager.geminiApiKeyName,
        );
      }
      
      if (_hasOpenAIKey) {
        _openaiPreview = await _apiKeysManager.getApiKeyPreview(
          ApiKeysManager.openaiApiKeyName,
        );
      }
    } catch (e) {
      _showError('Error cargando el estado de las keys: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editApiKey(String keyName, String title) async {
    final controller = TextEditingController();
    
    // Cargar la key actual si existe
    final currentKey = await _apiKeysManager.getApiKey(keyName);
    if (currentKey != null) {
      controller.text = currentKey;
    }

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditKeyDialog(
        title: title,
        controller: controller,
        keyName: keyName,
        apiKeysManager: _apiKeysManager,
      ),
    );

    if (result != null) {
      await _loadKeysStatus();
      _showSuccess('✅ API key actualizada correctamente');
    }
  }

  Future<void> _deleteApiKey(String keyName, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar $title?'),
        content: const Text(
          'Esta acción eliminará la API key de forma permanente. '
          'Deberás configurarla nuevamente para usar este servicio.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _apiKeysManager.deleteApiKey(keyName);
        await _loadKeysStatus();
        _showSuccess('🗑️ API key eliminada correctamente');
      } catch (e) {
        _showError('Error eliminando la API key: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestión de API Keys')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de API Keys'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Información
          _buildInfoCard(),
          
          const SizedBox(height: 24),
          
          // Gemini API Key
          _buildKeyCard(
            title: 'Gemini API Key',
            subtitle: 'Google Gemini',
            keyName: ApiKeysManager.geminiApiKeyName,
            hasKey: _hasGeminiKey,
            preview: _geminiPreview,
            icon: Icons.auto_awesome,
            color: Colors.blue,
          ),
          
          const SizedBox(height: 16),
          
          // OpenAI API Key
          _buildKeyCard(
            title: 'OpenAI API Key',
            subtitle: 'ChatGPT (OpenAI)',
            keyName: ApiKeysManager.openaiApiKeyName,
            hasKey: _hasOpenAIKey,
            preview: _openaiPreview,
            icon: Icons.smart_toy,
            color: Colors.green,
          ),
          
          const SizedBox(height: 24),
          
          // Advertencia si no hay keys configuradas
          if (!_hasGeminiKey && !_hasOpenAIKey)
            _buildWarningCard(),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 138, 206, 255),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Almacenamiento Seguro',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tus claves API se almacenan de forma cifrada en tu dispositivo y nunca se comparten con terceros.',
                  style: TextStyle(fontSize: 13, color: Colors.blue[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 255, 207, 129),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sin API Keys Configuradas',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Necesitas configurar al menos una API key para usar la aplicación.',
                  style: TextStyle(fontSize: 13, color: Colors.orange[800]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyCard({
    required String title,
    required String subtitle,
    required String keyName,
    required bool hasKey,
    required String? preview,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          // CAMBIO: withOpacity -> withValues
          color: hasKey ? color.withValues(alpha: 0.3) : const Color.fromARGB(255, 87, 43, 43),
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icono y estado
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    // CAMBIO: withOpacity -> withValues
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                // Estado badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: hasKey ? Colors.green[100] : Colors.red[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasKey ? Icons.check_circle : Icons.cancel,
                        size: 16,
                        color: hasKey ? Colors.green[700] : Colors.red[700],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasKey ? 'Activa' : 'No configurada',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: hasKey ? Colors.green[700] : Colors.red[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (hasKey && preview != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 99, 77, 77),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        preview,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18),
                      tooltip: 'Copiar',
                      onPressed: () async {
                        final key = await _apiKeysManager.getApiKey(keyName);
                        if (key != null) {
                          await Clipboard.setData(ClipboardData(text: key));
                          _showSuccess('📋 API key copiada al portapapeles');
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Botones de acción
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _editApiKey(keyName, title),
                    icon: Icon(hasKey ? Icons.edit : Icons.add),
                    label: Text(hasKey ? 'Editar' : 'Configurar'),
                  ),
                ),
                if (hasKey) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _deleteApiKey(keyName, title),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Eliminar'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Diálogo para editar una API key
class _EditKeyDialog extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final String keyName;
  final ApiKeysManager apiKeysManager;

  const _EditKeyDialog({
    required this.title,
    required this.controller,
    required this.keyName,
    required this.apiKeysManager,
  });

  @override
  State<_EditKeyDialog> createState() => _EditKeyDialogState();
}

class _EditKeyDialogState extends State<_EditKeyDialog> {
  bool _obscured = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _save() async {
    final key = widget.controller.text.trim();
    
    if (key.isEmpty) {
      setState(() => _errorMessage = 'La API key no puede estar vacía');
      return;
    }

    if (!widget.apiKeysManager.validateApiKey(widget.keyName, key)) {
      setState(() => _errorMessage = 'Formato de API key inválido');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.apiKeysManager.saveApiKey(widget.keyName, key);
      if (!mounted) return;
      Navigator.pop(context, key);
    } catch (e) {
      setState(() => _errorMessage = 'Error guardando: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Editar ${widget.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            obscureText: _obscured,
            decoration: InputDecoration(
              labelText: 'API Key',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscured ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscured = !_obscured),
              ),
              errorText: _errorMessage,
            ),
            maxLines: _obscured ? 1 : 3,
          ),
          const SizedBox(height: 8),
          Text(
            'La clave se almacenará de forma cifrada',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}