import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/gemini_service.dart';

/// Tutorial interactivo para crear y usar comandos basados en meta-prompts
class Module4CommandsTutorialPage extends StatefulWidget {
  final VoidCallback onNext;

  const Module4CommandsTutorialPage({super.key, required this.onNext});

  @override
  State<Module4CommandsTutorialPage> createState() =>
      _Module4CommandsTutorialPageState();
}

class _Module4CommandsTutorialPageState
    extends State<Module4CommandsTutorialPage> {
  // Fases del tutorial
  int _currentPhase = 0;

  // Servicio de Gemini
  final GeminiService _geminiService = GeminiService();

  // Estado para la generación del meta-prompt
  bool _isGenerating = false;
  String _generatedPrompt = '';
  String _streamingText = '';
  StreamSubscription<String>? _streamSubscription;
  final TextEditingController _requestController = TextEditingController();

  // Estado para el formulario de comando simulado
  final TextEditingController _triggerController =
      TextEditingController(text: '/descripcion');
  final TextEditingController _titleController =
      TextEditingController(text: 'Descripción Producto');
  final TextEditingController _descriptionController =
      TextEditingController(text: 'Genera descripciones para productos electrónicos');
  final TextEditingController _promptController = TextEditingController();
  bool _isEditable = true;
  bool _commandSaved = false;

  // Prompt de ejemplo (Default)
  static const String _defaultMetaPromptRequest = '''
Genera un prompt reutilizable para crear descripciones de productos electrónicos. El prompt debe incluir:

1. Instrucciones claras para describir un producto
2. Secciones para:
   - Especificaciones técnicas clave
   - Descripción general del producto
   - Características principales (bullets)
   - Público objetivo
3. Ejemplo de formato de salida
4. Indicaciones de longitud (máximo 200 palabras)

El prompt debe tener marcadores como [NOMBRE_PRODUCTO], [CATEGORIA], [PRECIO] para que el usuario los reemplace.

Genera únicamente el prompt, sin explicaciones adicionales.
''';

  @override
  void dispose() {
    _streamSubscription?.cancel();
    _requestController.dispose();
    _triggerController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  void _nextPhase() {
    if (_currentPhase < 5) {
      setState(() {
        _currentPhase++;
      });
    } else {
      widget.onNext();
    }
  }

  void _previousPhase() {
    if (_currentPhase > 0) {
      setState(() {
        _currentPhase--;
      });
    }
  }

  Future<void> _generateMetaPrompt() async {
    if (_requestController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('⚠️ Por favor escribe una petición o usa el ejemplo.'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    setState(() {
      _isGenerating = true;
      _streamingText = '';
      _generatedPrompt = '';
    });

    try {
      final stream = _geminiService.generateContentStream(_requestController.text);

      _streamSubscription = stream.listen(
        (chunk) {
          setState(() {
            _streamingText += chunk;
          });
        },
        onDone: () {
          setState(() {
            _generatedPrompt = _streamingText;
            _isGenerating = false;
          });
        },
        onError: (error) {
          setState(() {
            _isGenerating = false;
            _generatedPrompt =
                'Error al generar el prompt. Por favor, verifica tu conexión y API key.';
          });
        },
      );
    } catch (e) {
      setState(() {
        _isGenerating = false;
        _generatedPrompt = 'Error: $e';
      });
    }
  }

  void _copyToClipboard(String text) {
    if (text.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: text));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Texto copiado al portapapeles'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _pasteExampleToInput() {
    setState(() {
      _requestController.text = _defaultMetaPromptRequest;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Ejemplo copiado al campo de texto'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _pastePromptToCommand() {
    final textToPaste =
        _generatedPrompt.isNotEmpty ? _generatedPrompt : _streamingText;
    if (textToPaste.isNotEmpty) {
      setState(() {
        _promptController.text = textToPaste;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Prompt pegado en el comando'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _saveCommand() {
    setState(() {
      _commandSaved = true;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 8),
            Text('¡Comando guardado correctamente!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título principal
          Text(
            '🚀 Tutorial: Crear tu Primer Comando',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aprende a guardar meta-prompts como comandos reutilizables',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 16),

          // Indicador de progreso
          _buildProgressIndicator(isDark),
          const SizedBox(height: 24),

          // Contenido de la fase actual
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _buildCurrentPhaseContent(isDark, textColor),
            ),
          ),

          // Navegación
          _buildNavigationButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final phases = [
      'Introducción',
      'Definir Prompt',
      'Copiar',
      'Crear Comando',
      'Configurar',
      'Usar Comando',
    ];

    return Column(
      children: [
        // Barra de progreso
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: (_currentPhase + 1) / phases.length,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 12),
        // Nombre de la fase
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: isDark ? 0.3 : 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Paso ${_currentPhase + 1}: ${phases[_currentPhase]}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.purple[200] : Colors.purple[700],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPhaseContent(bool isDark, Color textColor) {
    switch (_currentPhase) {
      case 0:
        return _buildPhase0Introduction(isDark, textColor);
      case 1:
        return _buildPhase1GeneratePrompt(isDark, textColor);
      case 2:
        return _buildPhase2CopyPrompt(isDark, textColor);
      case 3:
        return _buildPhase3CreateCommand(isDark, textColor);
      case 4:
        return _buildPhase4ConfigureCommand(isDark, textColor);
      case 5:
        return _buildPhase5UseCommand(isDark, textColor);
      default:
        return const SizedBox();
    }
  }

  // ==========================================================================
  // FASE 0: Introducción
  // ==========================================================================
  Widget _buildPhase0Introduction(bool isDark, Color textColor) {
    return SingleChildScrollView(
      key: const ValueKey(0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            isDark: isDark,
            icon: Icons.lightbulb_outline,
            color: Colors.amber,
            title: '¿Qué son los Comandos?',
            content: 'Los comandos son prompts guardados que puedes reutilizar '
                'con un solo toque. En lugar de escribir el mismo prompt cada vez, '
                'lo guardas como comando y lo usas cuando lo necesites.',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            isDark: isDark,
            icon: Icons.auto_awesome,
            color: Colors.purple,
            title: 'El Flujo de Trabajo',
            content: 'En este tutorial:\n\n'
                '1️⃣ Pedirás a la IA un meta-prompt (o usarás nuestro ejemplo)\n\n'
                '2️⃣ Copiarás el prompt generado\n\n'
                '3️⃣ Lo guardarás como comando personalizado\n\n'
                '4️⃣ Aprenderás a usarlo desde el chat',
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            isDark: isDark,
            icon: Icons.rocket_launch,
            color: Colors.blue,
            title: 'Beneficio',
            content:
                'Una vez guardado, podrás generar contenido profesional '
                'para tus necesidades recurrentes con solo seleccionar el comando.',
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FASE 1: Generar el Meta-Prompt
  // ==========================================================================
  Widget _buildPhase1GeneratePrompt(bool isDark, Color textColor) {
    return SingleChildScrollView(
      key: const ValueKey(1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            isDark: isDark,
            icon: Icons.psychology,
            color: Colors.purple,
            title: 'Paso 1: Define tu Meta-Prompt',
            content:
                'Ahora vamos a pedirle a la IA que cree una plantilla (prompt) por nosotros. '
                'Puedes escribir tu propia petición para una tarea que necesites, o usar el siguiente ejemplo:',
          ),
          const SizedBox(height: 16),

          // EJEMPLO VISIBLE (No colapsado)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[850] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote, color: Colors.grey[500], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Ejemplo de Petición:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _defaultMetaPromptRequest,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    fontFamily: 'monospace',
                    color: isDark ? Colors.grey[400] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Botón para usar el ejemplo
          Center(
            child: TextButton.icon(
              onPressed: _pasteExampleToInput,
              icon: const Icon(Icons.arrow_downward, size: 16),
              label: const Text('Usar este ejemplo abajo'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue,
              ),
            ),
          ),

          const SizedBox(height: 8),

          // Campo de entrada del usuario
          TextField(
            controller: _requestController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'Tu petición a la IA',
              hintText: 'Escribe aquí qué tipo de prompt necesitas, o usa el botón de arriba...',
              alignLabelWithHint: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? Colors.grey[900] : Colors.white,
            ),
          ),

          const SizedBox(height: 20),

          // Botón para generar
          if (!_isGenerating && _generatedPrompt.isEmpty)
            Center(
              child: ElevatedButton.icon(
                onPressed: _generateMetaPrompt,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Generar Meta-Prompt'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

          // Indicador de carga y streaming
          if (_isGenerating || _streamingText.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.green.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (_isGenerating)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                          ),
                        )
                      else
                        const Icon(Icons.check_circle, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        _isGenerating ? 'Generando...' : '¡Prompt generado!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 200),
                    child: SingleChildScrollView(
                      child: Text(
                        _streamingText,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // FASE 2: Copiar el Prompt
  // ==========================================================================
  Widget _buildPhase2CopyPrompt(bool isDark, Color textColor) {
    final hasPrompt = _generatedPrompt.isNotEmpty || _streamingText.isNotEmpty;
    final promptText =
        _generatedPrompt.isNotEmpty ? _generatedPrompt : _streamingText;

    return SingleChildScrollView(
      key: const ValueKey(2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            isDark: isDark,
            icon: Icons.content_copy,
            color: Colors.blue,
            title: 'Paso 2: Copiar el Meta-Prompt',
            content: hasPrompt
                ? 'Ahora copia el prompt generado. Lo usarás en el siguiente paso para crear tu comando.'
                : '⚠️ Primero debes generar el prompt en el paso anterior.',
          ),
          const SizedBox(height: 16),

          if (hasPrompt) ...[
            // Mostrar el prompt con botón de copiar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.description,
                            size: 18,
                            color: isDark ? Colors.green[300] : Colors.green[700],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Tu Meta-Prompt:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.green[300] : Colors.green[700],
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _copyToClipboard(promptText),
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copiar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 250),
                    child: SingleChildScrollView(
                      child: Text(
                        promptText,
                        style: TextStyle(
                          fontSize: 13,
                          fontFamily: 'monospace',
                          color: isDark ? Colors.grey[300] : Colors.grey[800],
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildTipCard(
              isDark: isDark,
              text: 'En la app real, también podrías usar el botón de copiar que aparece '
                  'en cada mensaje del chat para copiar respuestas de la IA.',
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 64,
                    color: Colors.orange[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Vuelve al paso anterior para generar el prompt',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ==========================================================================
  // FASE 3: Crear el Comando
  // ==========================================================================
  Widget _buildPhase3CreateCommand(bool isDark, Color textColor) {
    return SingleChildScrollView(
      key: const ValueKey(3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            isDark: isDark,
            icon: Icons.add_circle_outline,
            color: Colors.purple,
            title: 'Paso 3: Crear un Nuevo Comando',
            content: 'Ahora vamos a simular la creación del comando. '
                'En la app real, irías a "Mis Comandos" y pulsarías "Nuevo Comando".',
          ),
          const SizedBox(height: 16),

          // Simulación del diálogo de creación
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header del diálogo
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.purple.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.bolt, color: Colors.purple),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Nuevo Comando',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 32),

                // Campo Trigger
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _triggerController,
                        decoration: InputDecoration(
                          labelText: 'Comando',
                          hintText: '/micomando',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.tag),
                          filled: true,
                          fillColor:
                              isDark ? Colors.grey[850] : Colors.grey[50],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Descripción del comando',
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor:
                              isDark ? Colors.grey[850] : Colors.grey[50],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Descripción
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: 'Descripción (opcional)',
                    hintText: 'Breve explicación...',
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: isDark ? Colors.grey[850] : Colors.grey[50],
                  ),
                ),
                const SizedBox(height: 16),

                // Prompt con botón de pegar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _promptController,
                        maxLines: 5,
                        decoration: InputDecoration(
                          labelText: 'Prompt (Template)',
                          hintText: 'Pega aquí el meta-prompt generado...',
                          alignLabelWithHint: true,
                          border: const OutlineInputBorder(),
                          filled: true,
                          fillColor:
                              isDark ? Colors.grey[850] : Colors.grey[50],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: _pastePromptToCommand,
                    icon: const Icon(Icons.paste, size: 16),
                    label: const Text('Pegar Prompt'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildTipCard(
            isDark: isDark,
            text: '💡 El comando debe empezar con "/" (ej: /descripcion). '
                'El nombre es lo que verás en la lista de comandos rápidos.',
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FASE 4: Configurar como Editable vs Auto
  // ==========================================================================
  Widget _buildPhase4ConfigureCommand(bool isDark, Color textColor) {
    return SingleChildScrollView(
      key: const ValueKey(4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            isDark: isDark,
            icon: Icons.settings,
            color: Colors.green,
            title: 'Paso 4: Configurar el Modo del Comando',
            content: 'Los comandos pueden ser "Editables" o "Automáticos".',
          ),
          const SizedBox(height: 16),

          // Explicación de los modos
          Row(
            children: [
              Expanded(
                child: _buildModeCard(
                  isDark: isDark,
                  title: 'Modo Editable',
                  icon: Icons.edit_note,
                  color: Colors.green,
                  description:
                      'La plantilla se pega en el chat. Ideal para rellenar [HUECOS].',
                  isSelected: _isEditable,
                  onTap: () => setState(() => _isEditable = true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModeCard(
                  isDark: isDark,
                  title: 'Modo Auto',
                  icon: Icons.bolt,
                  color: Colors.blue,
                  description:
                      'Se ejecuta directamente reemplazando {{content}}.',
                  isSelected: !_isEditable,
                  onTap: () => setState(() => _isEditable = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Switch visual
          Container(
            decoration: BoxDecoration(
              color: _isEditable
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isEditable
                    ? Colors.green.withValues(alpha: 0.3)
                    : Colors.blue.withValues(alpha: 0.3),
              ),
            ),
            child: SwitchListTile(
              title: Text(
                _isEditable ? 'Modo: Editable' : 'Modo: Automático',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _isEditable ? Colors.green[700] : Colors.blue[700],
                ),
              ),
              subtitle: Text(
                _isEditable
                    ? 'Podrás modificar el prompt antes de enviarlo. Útil para plantillas complejas.'
                    : 'Usa el marcador {{content}} en tu prompt. Al escribir "/comando texto", el "texto" reemplazará a {{content}} y se enviará.',
                style: const TextStyle(fontSize: 12),
              ),
              value: _isEditable,
              onChanged: (value) => setState(() => _isEditable = value),
              activeThumbColor: Colors.green,
            ),
          ),
          const SizedBox(height: 20),

          // Botón Guardar
          Center(
            child: ElevatedButton.icon(
              onPressed: _commandSaved ? null : _saveCommand,
              icon: Icon(_commandSaved ? Icons.check : Icons.save),
              label: Text(
                  _commandSaved ? '¡Comando Guardado!' : 'Guardar Comando'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _commandSaved ? Colors.grey : Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _buildTipCard(
            isDark: isDark,
            text: !_isEditable
                ? '💡 En Modo Auto, si necesitas editar la instrucción puntualmente, podrás hacerlo con Click Derecho > Editar Prompt en el menú de comandos.'
                : '✨ El modo Editable es el más seguro para empezar, ya que ves exactamente qué le enviarás a la IA.',
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FASE 5: Usar el Comando
  // ==========================================================================
  Widget _buildPhase5UseCommand(bool isDark, Color textColor) {
    return SingleChildScrollView(
      key: const ValueKey(5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            isDark: isDark,
            icon: Icons.touch_app,
            color: Colors.purple,
            title: 'Paso 5: Usar tu Comando',
            content:
                '¡Tu comando está listo! Ahora aprende cómo usarlo desde el chat.',
          ),
          const SizedBox(height: 16),

          // Simulación de Quick Responses
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[900] : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comandos Rápidos',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickResponseChip(
                        isDark: isDark,
                        label: '/descripcion',
                        icon: Icons.edit_note,
                        isEditable: true,
                        isHighlighted: true,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickResponseChip(
                        isDark: isDark,
                        label: '/resumir',
                        icon: Icons.bolt,
                        isEditable: false,
                        isHighlighted: false,
                      ),
                      const SizedBox(width: 8),
                      _buildQuickResponseChip(
                        isDark: isDark,
                        label: '/traducir',
                        icon: Icons.bolt,
                        isEditable: false,
                        isHighlighted: false,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Pasos para usar
          _buildUsageStep(
            isDark: isDark,
            number: '1',
            title: 'Selecciona el comando',
            description:
                'Toca "/descripcion" en los comandos rápidos del chat.',
            icon: Icons.touch_app,
          ),
          const SizedBox(height: 12),
          _buildUsageStep(
            isDark: isDark,
            number: '2',
            title: _isEditable ? 'Edita los parámetros' : 'Introduce el texto',
            description: _isEditable
                ? 'El prompt se insertará completo. Reemplaza [NOMBRE_PRODUCTO], etc.'
                : 'Escribe el texto que quieres procesar junto al comando.',
            icon: Icons.edit,
          ),
          const SizedBox(height: 12),
          _buildUsageStep(
            isDark: isDark,
            number: '3',
            title: 'Envía el mensaje',
            description:
                'Pulsa enviar y la IA generará la respuesta personalizada.',
            icon: Icons.send,
          ),
          const SizedBox(height: 20),

          // Ejemplo de resultado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: isDark ? 0.2 : 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.purple.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.auto_awesome,
                        color: Colors.purple[400], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Resultado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[400],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Con tu comando guardado, podrás generar respuestas profesionales '
                  'consistentemente. Si alguna vez necesitas ajustar un comando '
                  'automático (no editable), simplemente haz click derecho sobre él '
                  'y selecciona "Editar prompt".',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // WIDGETS AUXILIARES
  // ==========================================================================

  Widget _buildInfoCard({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? color.withValues(alpha: 0.9) : color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipCard({required bool isDark, required String text}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.tips_and_updates, color: Colors.amber[700], size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.amber[200] : Colors.amber[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required bool isDark,
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: isDark ? 0.3 : 0.15)
              : (isDark ? Colors.grey[850] : Colors.grey[100]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? color
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? color
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isSelected
                    ? color
                    : (isDark ? Colors.grey[300] : Colors.grey[700]),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickResponseChip({
    required bool isDark,
    required String label,
    required IconData icon,
    required bool isEditable,
    required bool isHighlighted,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted
            ? Colors.purple.withValues(alpha: 0.2)
            : (isDark ? Colors.grey[800] : Colors.grey[200]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isHighlighted
              ? Colors.purple
              : (isEditable
                  ? Colors.green.withValues(alpha: 0.3)
                  : Colors.transparent),
          width: isHighlighted ? 2 : 1,
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.purple.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 14,
            color: isHighlighted
                ? Colors.purple
                : (isEditable ? Colors.green[700] : Colors.grey[600]),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w500,
              color: isHighlighted
                  ? Colors.purple
                  : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
          if (isEditable && isHighlighted) ...[
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildUsageStep({
    required bool isDark,
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.purple,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Icon(
            icon,
            color: isDark ? Colors.grey[400] : Colors.grey[500],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButtons(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Botón Anterior
          TextButton.icon(
            onPressed: _currentPhase > 0 ? _previousPhase : null,
            icon: const Icon(Icons.arrow_back),
            label: const Text('Anterior'),
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.grey[400] : Colors.grey[700],
            ),
          ),
          // Botón Siguiente / Finalizar
          ElevatedButton.icon(
            onPressed: _canProceed() ? _nextPhase : null,
            icon: Icon(
                _currentPhase == 5 ? Icons.check_circle : Icons.arrow_forward),
            label:
                Text(_currentPhase == 5 ? 'Finalizar Tutorial' : 'Siguiente'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  isDark ? Colors.grey[800] : Colors.grey[300],
            ),
          ),
        ],
      ),
    );
  }

  bool _canProceed() {
    switch (_currentPhase) {
      case 1:
        // Debe haber generado el prompt
        return _generatedPrompt.isNotEmpty ||
            (!_isGenerating && _streamingText.isNotEmpty);
      case 4:
        // Debe haber guardado el comando
        return _commandSaved;
      default:
        return true;
    }
  }
}