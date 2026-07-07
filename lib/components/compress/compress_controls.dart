import 'package:flutter/material.dart';
import 'package:pdf_tools/components/compress/quality_preset_button.dart';

class CompressControls extends StatelessWidget {
  const CompressControls({
    super.key,
    required this.quality,
    required this.onQualityChanged,
  });

  final int quality;
  final ValueChanged<int> onQualityChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          children: [
            Expanded(
              child: Slider(
                value: quality.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                onChanged: (v) => onQualityChanged(v.round()),
              ),
            ),
            FilterChip(
              onSelected: null,
              showCheckmark: false,
              selected: true,
              shape: const StadiumBorder(),
              label: Text('$quality'),
            ),
          ],
        ),
        Text('Preset', style: Theme.of(context).textTheme.titleMedium),
        Row(
          mainAxisSize: .max,
          spacing: 8,
          children: [
            QualityPresetButton(
              quality: 90,
              label: 'Minimal',
              isSelected: quality == 90,
              onPressed: () => onQualityChanged(90),
            ),
            QualityPresetButton(
              quality: 75,
              label: 'Medium',
              isSelected: quality == 75,
              onPressed: () => onQualityChanged(75),
            ),
            QualityPresetButton(
              quality: 50,
              label: 'Full',
              isSelected: quality == 50,
              onPressed: () => onQualityChanged(50),
            ),
          ],
        ),
      ],
    );
  }
}
