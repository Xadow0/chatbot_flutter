import 'package:flutter/material.dart';
import '../../data/datasources/api_keys_manager.dart';
import '../../../../config/routes.dart';

/// Página de onboarding para configurar API keys la primera vez
/// Si ya hay keys por defecto disponibles, permite continuar sin configurar nada
class ApiKeysOnboardingPage extends StatefulWidget {
  const ApiKeysOnboardingPage({super.key});

  @override
  State<ApiKeysOnboardingPage> createState() => _ApiKeysOnboardingPageState();
}

class _ApiKeysOnboardingPageState extends State<ApiKeysOnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _geminiController = TextEditingController();
  final _openaiController = TextEditingController();
  
  bool _geminiObscured = true;
  bool _openaiObscured = true;
  bool _isLoading = false;
  bool _checkingDefaults = true;
  
  // Estado de las keys por defecto
  bool _hasDefaultGemini = false;
  bool _hasDefaultOpenAI = false;

  final _apiKeysManager = ApiKeysManager();

  @override
  void initState() {
    super.initState();
    _checkDefaultKeys();
  }

  Future<void> _checkDefaultKeys() async {
    setState(() => _checkingDefaults = true);
    
    try {
      _hasDefaultGemini = _apiKeysManager.hasDefaultKey(ApiKeysManager.geminiApiKeyName);
      _hasDefaultOpenAI = _apiKeysManager.hasDefaultKey(ApiKeysManager.openaiApiKeyName);
    } catch (e) {
      debugPrint('Error verificando keys por defecto: $e');
    } finally {
      if (mounted) {
        setState(() => _checkingDefaults = false);
      }
    }
  }

  @override
  void dispose() {
    _geminiController.dispose();
    _openaiController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    final hasGeminiInput = _geminiController.text.trim().isNotEmpty;
    final hasOpenAIInput = _openaiController.text.trim().isNotEmpty;
    
    // Si no hay keys por defecto Y el usuario no introduce ninguna, mostrar error
    if (!_hasDefaultGemini && !_hasDefaultOpenAI && !hasGeminiInput && !hasOpenAIInput) {
      _showError('Debes configurar al menos una API key para continuar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Guardar solo las keys que el usuario haya introducido
      if (hasGeminiInput) {
        await _apiKeysManager.saveApiKey(
          ApiKeysManager.geminiApiKeyName,
          _geminiController.text.trim(),
        );
      }

      if (hasOpenAIInput) {
        await _apiKeysManager.saveApiKey(
          ApiKeysManager.openaiApiKeyName,
          _openaiController.text.trim(),
        );
      }

      if (!mounted) return;

      // Mostrar confirmación apropiada
      String message;
      if (hasGeminiInput || hasOpenAIInput) {
        message = '✅ Configuración guardada correctamente';
      } else {
        message = '✅ Usando configuración por defecto';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Navegar al menú principal
      Navigator.of(context).pushReplacementNamed(AppRoutes.startMenu);
      
    } catch (e) {
      _showError('Error al guardar la configuración: $e');
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_checkingDefaults) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Verificando configuración...',
                style: theme.textTheme.bodyLarge,
              ),
            ],
          ),
        ),
      );
    }

    final hasAnyDefault = _hasDefaultGemini || _hasDefaultOpenAI;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Inicial'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono y título
                Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.vpn_key_rounded,
                        size: 80,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '¡Bienvenido!',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        hasAnyDefault 
                            ? 'La app está lista para usar'
                            : 'Configura tus claves API para comenzar',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),

                // Información sobre keys incluidas
                if (hasAnyDefault)
                  _buildDefaultKeysInfo(),
                
                if (!hasAnyDefault)
                  _buildNoDefaultKeysWarning(),

                const SizedBox(height: 24),

                // Sección opcional para keys personalizadas
                _buildOptionalKeysSection(theme),

                const SizedBox(height: 32),

                // Botón de continuar
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveAndContinue,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.arrow_forward),
                    label: Text(_isLoading 
                        ? 'Guardando...' 
                        : hasAnyDefault && _geminiController.text.isEmpty && _openaiController.text.isEmpty
                            ? 'Continuar con configuración por defecto'
                            : 'Guardar y Continuar'),
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Nota sobre privacidad
                Center(
                  child: Text(
                    '🔒 Tus claves personales se almacenan de forma segura\ny nunca se comparten con terceros',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultKeysInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700], size: 24),
              const SizedBox(width: 12),
              Text(
                'Servicios incluidos',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green[900],
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_hasDefaultGemini)
            _buildIncludedService(
              'Google Gemini',
              'IA conversacional incluida gratuitamente',
              Icons.auto_awesome,
            ),
          if (_hasDefaultOpenAI)
            _buildIncludedService(
              'OpenAI ChatGPT',
              'Acceso incluido',
              Icons.smart_toy,
            ),
          const SizedBox(height: 8),
          Text(
            'Puedes empezar a usar la app inmediatamente o configurar tus propias claves API si lo prefieres.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.green[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncludedService(String name, String description, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.green[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.green[900],
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDefaultKeysWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: Colors.orange[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configuración requerida',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Necesitas configurar al menos una API key para usar las funciones de IA.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.orange[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionalKeysSection(ThemeData theme) {
    final hasAnyDefault = _hasDefaultGemini || _hasDefaultOpenAI;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título de la sección
        Row(
          children: [
            Icon(
              hasAnyDefault ? Icons.settings : Icons.vpn_key,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              hasAnyDefault ? 'Usar mis propias claves (opcional)' : 'Configura tus claves API',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        
        if (hasAnyDefault)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            child: Text(
              'Si prefieres usar tus propias API keys, puedes configurarlas aquí:',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ),
        
        const SizedBox(height: 16),

        // Gemini API Key
        _buildApiKeyInput(
          title: 'Gemini API Key',
          subtitle: 'API de Google Gemini',
          controller: _geminiController,
          obscured: _geminiObscured,
          onVisibilityToggle: () {
            setState(() => _geminiObscured = !_geminiObscured);
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null; // Opcional si hay default
            }
            if (!_apiKeysManager.validateGeminiKey(value.trim())) {
              return 'Formato de clave Gemini inválido';
            }
            return null;
          },
          helpUrl: 'https://aistudio.google.com/app/apikey',
          hasDefault: _hasDefaultGemini,
        ),

        const SizedBox(height: 20),

        // OpenAI API Key
        _buildApiKeyInput(
          title: 'OpenAI API Key',
          subtitle: 'API de ChatGPT (OpenAI)',
          controller: _openaiController,
          obscured: _openaiObscured,
          onVisibilityToggle: () {
            setState(() => _openaiObscured = !_openaiObscured);
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return null; // Opcional si hay default
            }
            if (!_apiKeysManager.validateOpenAIKey(value.trim())) {
              return 'Formato de clave OpenAI inválido (debe empezar con sk-)';
            }
            return null;
          },
          helpUrl: 'https://platform.openai.com/api-keys',
          hasDefault: _hasDefaultOpenAI,
        ),
      ],
    );
  }

  Widget _buildApiKeyInput({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required bool obscured,
    required VoidCallback onVisibilityToggle,
    required String? Function(String?) validator,
    required String helpUrl,
    required bool hasDefault,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (hasDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'Incluido',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
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
            TextButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Obtén tu clave en: $helpUrl'),
                    action: SnackBarAction(
                      label: 'OK',
                      onPressed: () {},
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('¿Dónde?'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscured,
          decoration: InputDecoration(
            hintText: hasDefault 
                ? 'Dejar vacío para usar la incluida' 
                : 'Introduce tu API key',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscured ? Icons.visibility : Icons.visibility_off,
              ),
              onPressed: onVisibilityToggle,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }
}