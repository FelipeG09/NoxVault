import 'package:flutter/material.dart';

import '../utils/password_security.dart';

/// Linha com força da senha e aviso de reutilização.
class PasswordHintRow extends StatelessWidget {
  const PasswordHintRow({
    super.key,
    required this.analysis,
  });

  final PasswordAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    late final Color strengthColor;
    late final String strengthText;
    switch (analysis.strength) {
      case PasswordStrengthLabel.none:
        return const SizedBox.shrink();
      case PasswordStrengthLabel.weak:
        strengthColor = Colors.redAccent;
        strengthText = 'Fraca';
        break;
      case PasswordStrengthLabel.medium:
        strengthColor = Colors.orangeAccent;
        strengthText = 'Média';
        break;
      case PasswordStrengthLabel.strong:
        strengthColor = Colors.lightGreenAccent;
        strengthText = 'Forte';
        break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              visualDensity: VisualDensity.compact,
              label: Text(
                'Força: $strengthText',
                style: TextStyle(color: strengthColor, fontSize: 12),
              ),
              side: BorderSide(color: strengthColor.withValues(alpha: 0.5)),
              backgroundColor: strengthColor.withValues(alpha: 0.12),
            ),
            if (analysis.isReused)
              Chip(
                visualDensity: VisualDensity.compact,
                avatar: const Icon(Icons.copy_all_outlined, size: 16),
                label: const Text(
                  'Reutilizada em outro item',
                  style: TextStyle(fontSize: 12),
                ),
                side: const BorderSide(color: Colors.amberAccent),
                backgroundColor: Colors.amber.withValues(alpha: 0.12),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          analysis.isReused
              ? '${analysis.message} Esta senha já aparece em outra entrada do cofre — o ideal é uma senha única por serviço.'
              : analysis.message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white60,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
