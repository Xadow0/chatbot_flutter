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
  
  // Estado detallado de las keys
  ApiKeyStatus? _geminiStatus;
  ApiKeyStatus? _openaiStatus;
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
      final status = await _apiKeysManager.getApiKeysDetailedStatus();
      _geminiStatus = status[ApiKeysManager.geminiApiKeyName];
      _openaiStatus = status[ApiKeysManager.openaiApiKeyName];
      
      // Solo obtener preview si es key del usuario
      if (_geminiStatus?.isUserKey == true) {
        _geminiPreview = await _apiKeysManager.getUserApiKeyPreview(
          ApiKeysManager.geminiApiKeyName,
        );
      } else {
        _geminiPreview = null;
      }
      
      if (_openaiStatus?.isUserKey == true) {
        _openaiPreview = await _apiKeysManager.getUserApiKeyPreview(
          ApiKeysManager.openaiApiKeyName,
        );
      } else {
        _openaiPreview = null;
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
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _editApiKey(String keyName, String title, bool isUserKey) async {
    final controller = TextEditingController();
    
    // Solo cargar la key actual si es del usuario (nunca mostrar la por defecto)
    if (isUserKey) {
      final currentKey = await _apiKeysManager.getUserApiKey(keyName);
      if (currentKey != null) {
        controller.text = currentKey;
      }
    }

    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => _EditKeyDialog(
        title: title,
        controller: controller,
        keyName: keyName,
        apiKeysManager: _apiKeysManager,
        isEditing: isUserKey,
      ),
    );

    if (result != null) {
      await _loadKeysStatus();
      _showSuccess('✅ API key personalizada guardada');
    }
  }

  Future<void> _restoreDefaultKey(String keyName, String title) async {
    final hasDefault = _apiKeysManager.hasDefaultKey(keyName);
    
    if (!hasDefault) {
      _showError('No hay una API key por defecto disponible para este servicio');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Restaurar $title por defecto?'),
        content: const Text(
          'Tu API key personalizada será eliminada y se usará '
          'la configuración por defecto de la aplicación.\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await _apiKeysManager.restoreDefaultKey(keyName);
        if (success) {
          await _loadKeysStatus();
          _showSuccess('✅ Restaurada configuración por defecto');
        } else {
          _showError('No se pudo restaurar la configuración por defecto');
        }
      } catch (e) {
        _showError('Error restaurando: $e');
      }
    }
  }

  Future<void> _deleteUserApiKey(String keyName, String title, bool hasDefault) async {
    String message;
    if (hasDefault) {
      message = 'Tu API key personalizada será eliminada y se usará '
          'la configuración por defecto de la aplicación.';
    } else {
      message = 'Esta acción eliminará tu API key de forma permanente. '
          'No hay configuración por defecto disponible para este servicio, '
          'por lo que deberás configurar una nueva key para usarlo.';
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Eliminar $title personalizada?'),
        content: Text(message),
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
        await _apiKeysManager.deleteUserApiKey(keyName);
        await _loadKeysStatus();
        if (hasDefault) {
          _showSuccess('✅ Usando configuración por defecto');
        } else {
          _showSuccess('🗑️ API key eliminada');
        }
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
            status: _geminiStatus,
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
            status: _openaiStatus,
            preview: _openaiPreview,
            icon: Icons.smart_toy,
            color: Colors.green,
          ),
          
          const SizedBox(height: 24),
          
          // Advertencia si no hay keys configuradas
          if (_geminiStatus?.hasKey != true && _openaiStatus?.hasKey != true)
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
                  'Configuración de API Keys',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'La aplicación incluye acceso gratuito a Gemini. '
                  'Puedes usar tus propias API keys si lo prefieres.',
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
                  'Sin API Keys Disponibles',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'No hay ninguna API key configurada. '
                  'Necesitas al menos una para usar las funciones de IA.',
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
    required ApiKeyStatus? status,
    required String? preview,
    required IconData icon,
    required Color color,
  }) {
    final hasKey = status?.hasKey ?? false;
    final isUserKey = status?.isUserKey ?? false;
    final isUsingDefault = status?.isUsingDefault ?? false;
    final hasDefaultAvailable = status?.hasDefaultAvailable ?? false;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
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
                _buildStatusBadge(hasKey, isUserKey, isUsingDefault),
              ],
            ),
            
            // Mostrar preview solo si es key del usuario
            if (isUserKey && preview != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.key, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
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
                        final key = await _apiKeysManager.getUserApiKey(keyName);
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
            
            // Mostrar indicador si usa key por defecto
            if (isUsingDefault) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Usando configuración incluida con la app',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.green[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            // Botones de acción
            _buildActionButtons(
              keyName: keyName,
              title: title,
              hasKey: hasKey,
              isUserKey: isUserKey,
              isUsingDefault: isUsingDefault,
              hasDefaultAvailable: hasDefaultAvailable,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(bool hasKey, bool isUserKey, bool isUsingDefault) {
    Color bgColor;
    Color textColor;
    IconData iconData;
    String label;

    if (!hasKey) {
      bgColor = Colors.red[100]!;
      textColor = Colors.red[700]!;
      iconData = Icons.cancel;
      label = 'No disponible';
    } else if (isUserKey) {
      bgColor = Colors.purple[100]!;
      textColor = Colors.purple[700]!;
      iconData = Icons.person;
      label = 'Personalizada';
    } else if (isUsingDefault) {
      bgColor = Colors.green[100]!;
      textColor = Colors.green[700]!;
      iconData = Icons.check_circle;
      label = 'Por defecto';
    } else {
      bgColor = Colors.grey[100]!;
      textColor = Colors.grey[700]!;
      iconData = Icons.help;
      label = 'Desconocido';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: textColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required String keyName,
    required String title,
    required bool hasKey,
    required bool isUserKey,
    required bool isUsingDefault,
    required bool hasDefaultAvailable,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Botón para configurar/editar key personalizada
        OutlinedButton.icon(
          onPressed: () => _editApiKey(keyName, title, isUserKey),
          icon: Icon(isUserKey ? Icons.edit : Icons.add),
          label: Text(isUserKey ? 'Editar mi key' : 'Usar mi propia key'),
        ),
        
        // Botón para restaurar por defecto (solo si tiene key de usuario Y hay default disponible)
        if (isUserKey && hasDefaultAvailable)
          OutlinedButton.icon(
            onPressed: () => _restoreDefaultKey(keyName, title),
            icon: const Icon(Icons.restore),
            label: const Text('Usar por defecto'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange[700],
            ),
          ),
        
        // Botón para eliminar (solo si tiene key de usuario y NO hay default)
        if (isUserKey && !hasDefaultAvailable)
          OutlinedButton.icon(
            onPressed: () => _deleteUserApiKey(keyName, title, hasDefaultAvailable),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Eliminar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
            ),
          ),
      ],
    );
  }
}

/// Diálogo para editar/crear una API key personalizada
class _EditKeyDialog extends StatefulWidget {
  final String title;
  final TextEditingController controller;
  final String keyName;
  final ApiKeysManager apiKeysManager;
  final bool isEditing;

  const _EditKeyDialog({
    required this.title,
    required this.controller,
    required this.keyName,
    required this.apiKeysManager,
    required this.isEditing,
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
      title: Text(widget.isEditing ? 'Editar ${widget.title}' : 'Añadir ${widget.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Introduce tu API key personal:',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.lock, size: 16, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tu clave se almacenará de forma cifrada en tu dispositivo',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
              ],
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