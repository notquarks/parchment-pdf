import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class QualityPresetButton extends StatelessWidget {
  const QualityPresetButton({
    super.key,
    required this.quality,
    required this.label,
    required this.isSelected,
    required this.onPressed,
  });

  final int quality;
  final String label;
  final bool isSelected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: isSelected
          ? M3EFilledButton(
              onPressed: onPressed,
              child: Text(label),
            )
          : M3EFilledButton.tonal(
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }
}
