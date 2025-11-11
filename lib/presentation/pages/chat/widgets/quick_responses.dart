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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
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
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              'Lista de Comandos Rápidos',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: responses.map((response) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _QuickResponseChip(
                    response: response,
                    onTap: () => onResponseSelected(response.text),
                  ),
                );
              }).toList(),
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
    return ActionChip(
      label: Text(response.text),
      onPressed: onTap,
      avatar: const Icon(Icons.bolt, size: 18),
      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
      labelStyle: TextStyle(
        color: Theme.of(context).colorScheme.onSecondaryContainer,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}