import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class CompressControls extends StatefulWidget {
  const CompressControls({
    super.key,
    required this.quality,
    required this.onQualityChanged,
  });

  final int quality;
  final ValueChanged<int> onQualityChanged;

  @override
  State<CompressControls> createState() => _CompressControlsState();
}

class _CompressControlsState extends State<CompressControls> {
  static const double _cardPadding = 16;
  static const double _sectionSpacing = 16;
  static const double _itemSpacing = 10;
  static const int _minimumQuality = 10;
  static const int _maximumQuality = 100;
  static const int _qualityDivisions = 18;

  bool _advancedExpanded = false;

  CompressionChoice get _selectedChoice {
    if (widget.quality >= CompressionChoice.smallerLoss.quality) {
      return CompressionChoice.smallerLoss;
    }
    if (widget.quality >= CompressionChoice.recommended.quality) {
      return CompressionChoice.recommended;
    }
    return CompressionChoice.smallestSize;
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Compression level',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Choose how strongly images should be reduced.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: _sectionSpacing),
            for (final choice in CompressionChoice.values) ...[
              _CompressionChoiceTile(
                choice: choice,
                selected: _selectedChoice == choice,
                onPressed: () => widget.onQualityChanged(choice.quality),
              ),
              if (choice != CompressionChoice.values.last)
                const SizedBox(height: _itemSpacing),
            ],
            const SizedBox(height: _sectionSpacing),
            M3EExpandableCardList(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              initiallyExpanded: _advancedExpanded ? const {0} : const {},
              onExpansionChanged: (index, expanded) {
                setState(() {
                  _advancedExpanded = expanded;
                });
              },
              style: M3EExpandableStyle(
                headerAlignment: .center,
                margin: EdgeInsets.zero,
                titleSubtitleGap: 16,
                color: Theme.of(context).colorScheme.surfaceContainer,
                tapBodyToExpand: true,
                tapBodyToCollapse: true,
              ),
              data: [
                M3EExpandableData(
                  title: 'Advanced settings',
                  subtitle: '${widget.quality}% image quality',
                  bodyBuilder: (context) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: 'Image quality',
                          value: '${widget.quality} percent',
                          slider: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: widget.quality.toDouble(),
                                  min: _minimumQuality.toDouble(),
                                  max: _maximumQuality.toDouble(),
                                  divisions: _qualityDivisions,
                                  label: '${widget.quality}%',
                                  onChanged: (value) {
                                    widget.onQualityChanged(value.round());
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '${widget.quality}%',
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _qualityDescription(widget.quality),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _qualityDescription(int quality) {
    if (quality >= 85) {
      return 'Keeps more image detail and usually produces a larger PDF.';
    }
    if (quality >= 65) {
      return 'Balances visual quality and file size for most documents.';
    }
    return 'Prioritizes a smaller file and may reduce image clarity.';
  }
}

enum CompressionChoice {
  smallerLoss(
    quality: 90,
    title: 'Smaller loss',
    description: 'Best for documents where image detail matters.',
    icon: Icons.hd_outlined,
  ),
  recommended(
    quality: 75,
    title: 'Recommended',
    description: 'A balanced choice for sharing and storage.',
    icon: Icons.balance_outlined,
  ),
  smallestSize(
    quality: 50,
    title: 'Smallest size',
    description: 'Stronger compression for compact output files.',
    icon: Icons.compress,
  );

  const CompressionChoice({
    required this.quality,
    required this.title,
    required this.description,
    required this.icon,
  });

  final int quality;
  final String title;
  final String description;
  final IconData icon;
}

class _CompressionChoiceTile extends StatelessWidget {
  const _CompressionChoiceTile({
    required this.choice,
    required this.selected,
    required this.onPressed,
  });

  static const double _borderRadius = 16;
  static const double _padding = 12;
  static const double _iconExtent = 44;
  static const double _spacing = 12;

  final CompressionChoice choice;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: '${choice.title}, ${choice.description}',
      child: Material(
        color: selected
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Row(
              children: [
                Container(
                  width: _iconExtent,
                  height: _iconExtent,
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(choice.icon),
                ),
                const SizedBox(width: _spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        choice.description,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: _spacing),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
