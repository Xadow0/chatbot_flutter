import 'package:flutter/material.dart';
import '../../data/datasources/api_keys_manager.dart';
import '../../../../config/routes.dart';

/// Página de onboarding para configurar API keys la primera vez
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

  final _apiKeysManager = ApiKeysManager();

  @override
  void dispose() {
    _geminiController.dispose();
    _openaiController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    if (!_formKey.currentState!.validate()) return;

    // Verificar que al menos una key esté configurada
    if (_geminiController.text.trim().isEmpty && 
        _openaiController.text.trim().isEmpty) {
      _showError('Debes configurar al menos una API key para continuar');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Guardar las keys que no estén vacías
      if (_geminiController.text.trim().isNotEmpty) {
        await _apiKeysManager.saveApiKey(
          ApiKeysManager.geminiApiKeyName,
          _geminiController.text.trim(),
        );
      }

      if (_openaiController.text.trim().isNotEmpty) {
        await _apiKeysManager.saveApiKey(
          ApiKeysManager.openaiApiKeyName,
          _openaiController.text.trim(),
        );
      }

      if (!mounted) return;

      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ API keys guardadas correctamente'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Navegar al menú principal
      Navigator.of(context).pushReplacementNamed(AppRoutes.startMenu);
      
    } catch (e) {
      _showError('Error al guardar las API keys: $e');
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración Inicial'),
        automaticallyImplyLeading: false, // No permitir volver atrás
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
                        'Configura tus claves API para comenzar',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),

                // Información importante
                _buildInfoCard(
                  icon: Icons.info_outline,
                  title: 'Importante',
                  description: 'Necesitas al menos una API key para usar la aplicación. '
                      'Tus claves se almacenan de forma segura y cifrada en tu dispositivo.',
                ),

                const SizedBox(height: 24),

                // Gemini API Key
                _buildApiKeySection(
                  title: 'Gemini API Key',
                  subtitle: 'API de Google Gemini',
                  controller: _geminiController,
                  obscured: _geminiObscured,
                  onVisibilityToggle: () {
                    setState(() => _geminiObscured = !_geminiObscured);
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null; // Opcional
                    }
                    if (!_apiKeysManager.validateGeminiKey(value.trim())) {
                      return 'Formato de clave Gemini inválido';
                    }
                    return null;
                  },
                  helpUrl: 'https://aistudio.google.com/app/apikey',
                ),

                const SizedBox(height: 24),

                // OpenAI API Key
                _buildApiKeySection(
                  title: 'OpenAI API Key',
                  subtitle: 'API de ChatGPT (OpenAI)',
                  controller: _openaiController,
                  obscured: _openaiObscured,
                  onVisibilityToggle: () {
                    setState(() => _openaiObscured = !_openaiObscured);
                  },
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return null; // Opcional
                    }
                    if (!_apiKeysManager.validateOpenAIKey(value.trim())) {
                      return 'Formato de clave OpenAI inválido (debe empezar con sk-)';
                    }
                    return null;
                  },
                  helpUrl: 'https://platform.openai.com/api-keys',
                ),

                const SizedBox(height: 32),

                // Botón de guardar
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
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar y Continuar'),
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
                    '🔒 Tus claves se almacenan de forma segura\ny nunca se comparten con terceros',
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

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.blue[700], size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeySection({
    required String title,
    required String subtitle,
    required TextEditingController controller,
    required bool obscured,
    required VoidCallback onVisibilityToggle,
    required String? Function(String?) validator,
    required String helpUrl,
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
            hintText: 'Introduce tu API key (opcional)',
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