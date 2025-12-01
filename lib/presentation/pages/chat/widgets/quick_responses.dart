import 'package:flutter/material.dart';
import '../../../../data/models/quick_response_model.dart';

class QuickResponsesWidget extends StatelessWidget {
  final List<QuickResponse> responses;
  final Function(String) onResponseSelected;

  const QuickResponsesWidget({
    super.key,
    required this.responses,
    required this.onResponseSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (responses.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha((0.5 * 255).round()),
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Text(
              'Comandos Rápidos',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                const SizedBox(width: 12),
                ...responses.map((response) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _QuickResponseChip(
                      response: response,
                      onTap: () {
                        // Asegurar que el comando tenga un espacio al final
                        String commandText = response.text;
                        if (!commandText.endsWith(' ')) {
                          commandText += ' ';
                        }
                        onResponseSelected(commandText);
                      },
                    ),
                  );
                }),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickResponseChip extends StatelessWidget {
  final QuickResponse response;
  final VoidCallback onTap;

  const _QuickResponseChip({
    required this.response,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Intentamos obtener una descripción si el modelo la tuviera, si no, mostramos una genérica.
    // Nota: Si tu modelo 'QuickResponse' tiene un campo 'description', úsalo aquí:
    // final String tooltipText = response.description ?? "Ejecutar ${response.text}";
    final String tooltipText = "Ejecutar comando: ${response.text}";

    return ActionChip(
      // TOOLTIP: Muestra el texto al dejar el ratón encima
      tooltip: tooltipText,
      
      visualDensity: VisualDensity.compact,
      
      // PADDING: Control estricto del espacio interno del botón
      padding: EdgeInsets.zero,
      labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bolt, 
            size: 14, 
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4), 
          Text(
            response.text,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context).colorScheme.onSecondaryContainer,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      onPressed: onTap,
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    );
  }
}