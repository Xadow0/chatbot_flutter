import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  late AnimationController _animController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  
  // Para validación de contraseña
  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _passwordsMatch = false;

  @override
  void initState() {
    super.initState();
    
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeIn,
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    ));

    _animController.forward();
    
    // Listeners para validación en tiempo real
    _passwordController.addListener(_validatePassword);
    _confirmPasswordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    
    setState(() {
      _hasMinLength = password.length >= 6;
      _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
      _hasLowerCase = password.contains(RegExp(r'[a-z]'));
      _hasNumber = password.contains(RegExp(r'[0-9]'));
      _passwordsMatch = password.isNotEmpty && password == confirmPassword;
    });
  }

  double _getPasswordStrength() {
    int strength = 0;
    if (_hasMinLength) strength++;
    if (_hasUpperCase) strength++;
    if (_hasLowerCase) strength++;
    if (_hasNumber) strength++;
    return strength / 4;
  }

  Color _getPasswordStrengthColor() {
    final strength = _getPasswordStrength();
    if (strength < 0.5) return Colors.red;
    if (strength < 0.75) return Colors.orange;
    return Colors.green;
  }

  String _getPasswordStrengthText() {
    final strength = _getPasswordStrength();
    if (strength < 0.5) return 'Débil';
    if (strength < 0.75) return 'Media';
    return 'Fuerte';
  }

  void _showConfirmationDialog() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            const SizedBox(width: 10),
            const Text('Confirmar registro'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Por favor, verifica tus datos antes de continuar:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            _buildSummaryRow(Icons.email_outlined, 'Correo', email),
            const SizedBox(height: 12),
            _buildSummaryRow(
              Icons.lock_outline, 
              'Contraseña', 
              '•' * password.length,
              subtitle: 'Fortaleza: ${_getPasswordStrengthText()}',
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber[700], size: 20),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Recuerda guardar tus credenciales en un lugar seguro.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _confirmSubmit();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Confirmar y crear cuenta'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String label, String value, {String? subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getPasswordStrengthColor(),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Si es registro, mostrar diálogo de confirmación
    if (!_isLogin) {
      _showConfirmationDialog();
    } else {
      await _confirmSubmit();
    }
  }

  Future<void> _confirmSubmit() async {
    final authProvider = context.read<AuthProvider>();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    FocusScope.of(context).unfocus();

    if (_isLogin) {
      await authProvider.signIn(email, password);
    } else {
      await authProvider.signUp(email, password);
    }

    if (mounted && authProvider.errorMessage == null) {
      Navigator.pop(context);
    } else if (mounted && authProvider.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage!),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final primaryColor = _isLogin ? Colors.blue : Colors.green;
    final subtitleColor = isDark ? Colors.grey[400] : Colors.grey[600];
    final inputFillColor = isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.05);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? Colors.white10 : Colors.black12,
                        ),
                        child: Icon(
                          _isLogin ? Icons.lock_open_rounded : Icons.person_add_alt_1_rounded,
                          size: 60,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 30),

                      Text(
                        _isLogin ? 'Bienvenido de nuevo' : 'Crear una cuenta',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isLogin 
                          ? 'Introduce tus credenciales para acceder' 
                          : 'Rellena el formulario para registrarte',
                        style: TextStyle(
                          fontSize: 16,
                          color: subtitleColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),

                      // ---- INPUT: EMAIL ----
                      _buildTextField(
                        controller: _emailController,
                        label: 'Correo Electrónico',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        primaryColor: primaryColor,
                        fillColor: inputFillColor,
                        textColor: theme.colorScheme.onSurface,
                        textInputAction: TextInputAction.next,
                        validator: (value) {
                          final trimmed = value?.trim() ?? '';
                          if (trimmed.isEmpty) {
                            return 'El correo no puede estar vacío';
                          }
                          if (!trimmed.contains('@') || !trimmed.contains('.')) {
                            return 'Formato de correo inválido';
                          }
                          if (trimmed.length < 5) {
                            return 'El correo es demasiado corto';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // ---- INPUT: PASSWORD ----
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        primaryColor: primaryColor,
                        fillColor: inputFillColor,
                        textColor: theme.colorScheme.onSurface,
                        textInputAction: _isLogin ? TextInputAction.done : TextInputAction.next,
                        onSubmitted: _isLogin ? (_) => _submit() : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword ? Icons.visibility_off : Icons.visibility,
                            color: primaryColor.withValues(alpha: 0.7),
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'La contraseña no puede estar vacía';
                          }
                          if (value.length < 6) {
                            return 'Mínimo 6 caracteres';
                          }
                          return null;
                        },
                      ),
                      
                      // Indicador de fortaleza de contraseña (solo en registro)
                      if (!_isLogin && _passwordController.text.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        _buildPasswordStrengthIndicator(primaryColor),
                      ],
                      
                      // ---- INPUT: CONFIRM PASSWORD (solo en registro) ----
                      if (!_isLogin) ...[
                        const SizedBox(height: 20),
                        _buildTextField(
                          controller: _confirmPasswordController,
                          label: 'Confirmar Contraseña',
                          icon: Icons.lock_outline,
                          obscureText: _obscureConfirmPassword,
                          primaryColor: primaryColor,
                          fillColor: inputFillColor,
                          textColor: theme.colorScheme.onSurface,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off : Icons.visibility,
                              color: primaryColor.withValues(alpha: 0.7),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Confirma tu contraseña';
                            }
                            if (value != _passwordController.text) {
                              return 'Las contraseñas no coinciden';
                            }
                            return null;
                          },
                        ),
                      ],
                      
                      const SizedBox(height: 40),

                      if (authProvider.isLoading)
                        const CircularProgressIndicator()
                      else
                        _buildGradientButton(
                          text: _isLogin ? 'ENTRAR' : 'REGISTRARSE',
                          color: primaryColor,
                          onPressed: _submit,
                        ),
                      
                      const SizedBox(height: 24),

                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isLogin = !_isLogin;
                            authProvider.clearError();
                            _formKey.currentState?.reset();
                            _emailController.clear();
                            _passwordController.clear();
                            _confirmPasswordController.clear();
                            _obscurePassword = true;
                            _obscureConfirmPassword = true;
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(color: subtitleColor, fontSize: 15),
                            children: [
                              TextSpan(text: _isLogin ? '¿No tienes cuenta? ' : '¿Ya tienes cuenta? '),
                              TextSpan(
                                text: _isLogin ? 'Regístrate' : 'Inicia sesión',
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordStrengthIndicator(Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: LinearProgressIndicator(
                value: _getPasswordStrength(),
                backgroundColor: Colors.grey.withValues(alpha: 0.2),
                color: _getPasswordStrengthColor(),
                minHeight: 4,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _getPasswordStrengthText(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _getPasswordStrengthColor(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            _buildPasswordRequirement('6+ caracteres', _hasMinLength),
            _buildPasswordRequirement('Mayúscula', _hasUpperCase),
            _buildPasswordRequirement('Minúscula', _hasLowerCase),
            _buildPasswordRequirement('Número', _hasNumber),
          ],
        ),
      ],
    );
  }

  Widget _buildPasswordRequirement(String text, bool met) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: met ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: met ? Colors.green.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            met ? Icons.check_circle : Icons.circle_outlined,
            size: 14,
            color: met ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              color: met ? Colors.green : Colors.grey,
              fontWeight: met ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color fillColor,
    required Color textColor,
    Color primaryColor = Colors.blue,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    void Function(String)? onSubmitted,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onSubmitted,
      style: TextStyle(fontSize: 16, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: textColor.withValues(alpha: 0.7)),
        prefixIcon: Icon(icon, color: primaryColor.withValues(alpha: 0.8)),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fillColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: primaryColor, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: Colors.red, width: 1),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildGradientButton({
    required String text,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: double.infinity,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color,
            color.withValues(alpha: 0.7),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onPressed,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}