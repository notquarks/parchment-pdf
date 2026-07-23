import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:pdf_tools/features/compression/data/models/compression_options.dart';

class CompressControls extends StatefulWidget {
  const CompressControls({
    super.key,
    required this.selectedPreset,
    required this.onPresetChanged,
    required this.advancedQuality,
    required this.onAdvancedQualityChanged,
    required this.advancedDpiTarget,
    required this.onAdvancedDpiTargetChanged,
    this.advancedGrayscale = false,
    this.onAdvancedGrayscaleChanged,
    this.advancedStripMetadata = false,
    this.onAdvancedStripMetadataChanged,
  });

  final CompressionPreset selectedPreset;
  final ValueChanged<CompressionPreset> onPresetChanged;
  final int advancedQuality;
  final ValueChanged<int> onAdvancedQualityChanged;
  final int advancedDpiTarget;
  final ValueChanged<int> onAdvancedDpiTargetChanged;
  final bool advancedGrayscale;
  final ValueChanged<bool>? onAdvancedGrayscaleChanged;
  final bool advancedStripMetadata;
  final ValueChanged<bool>? onAdvancedStripMetadataChanged;

  @override
  State<CompressControls> createState() => _CompressControlsState();
}

class _CompressControlsState extends State<CompressControls> {
  bool _advancedExpanded = false;

  static const double _cardPadding = 16;
  static const double _sectionSpacing = 16;

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
              'Choose how strongly the PDF should be reduced.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: _sectionSpacing),
            for (final preset in CompressionPreset.values) ...[
              _PresetTile(
                preset: preset,
                selected: widget.selectedPreset == preset,
                onPressed: () => widget.onPresetChanged(preset),
              ),
              if (preset != CompressionPreset.values.last)
                const SizedBox(height: 10),
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
                  subtitle: '${widget.advancedQuality}% quality, ${widget.advancedDpiTarget} DPI',
                  bodyBuilder: (context) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Image quality',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Semantics(
                          label: 'Image quality',
                          value: '${widget.advancedQuality} percent',
                          slider: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: widget.advancedQuality.toDouble(),
                                  min: 10,
                                  max: 100,
                                  divisions: 18,
                                  label: '${widget.advancedQuality}%',
                                  onChanged: (value) {
                                    widget.onAdvancedQualityChanged(value.round());
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 56,
                                child: Text(
                                  '${widget.advancedQuality}%',
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Target DPI',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Semantics(
                          label: 'Target DPI',
                          value: '${widget.advancedDpiTarget} DPI',
                          slider: true,
                          child: Row(
                            children: [
                              Expanded(
                                child: Slider(
                                  value: widget.advancedDpiTarget.toDouble(),
                                  min: 72,
                                  max: 300,
                                  divisions: 23,
                                  label: '${widget.advancedDpiTarget} DPI',
                                  onChanged: (value) {
                                    widget.onAdvancedDpiTargetChanged(value.round());
                                  },
                                ),
                              ),
                              SizedBox(
                                width: 72,
                                child: Text(
                                  '${widget.advancedDpiTarget} DPI',
                                  textAlign: TextAlign.end,
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          title: const Text('Convert to grayscale'),
                          value: widget.advancedGrayscale,
                          onChanged: widget.onAdvancedGrayscaleChanged,
                          contentPadding: EdgeInsets.zero,
                        ),
                        SwitchListTile(
                          title: const Text('Remove metadata'),
                          value: widget.advancedStripMetadata,
                          onChanged: widget.onAdvancedStripMetadataChanged,
                          contentPadding: EdgeInsets.zero,
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
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({
    required this.preset,
    required this.selected,
    required this.onPressed,
  });

  static const double _borderRadius = 16;
  static const double _padding = 12;
  static const double _iconExtent = 44;
  static const double _spacing = 12;

  final CompressionPreset preset;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDestructive = preset.mode == PdfCompressionMode.extremeRaster;

    return Semantics(
      button: true,
      selected: selected,
      label: '${preset.title}, ${preset.description}',
      child: Material(
        color: selected
            ? (isDestructive
                ? colorScheme.errorContainer
                : colorScheme.secondaryContainer)
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          side: BorderSide(
            color: selected
                ? (isDestructive ? colorScheme.error : colorScheme.primary)
                : colorScheme.outlineVariant,
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
                        ? (isDestructive
                            ? colorScheme.errorContainer
                            : colorScheme.primaryContainer)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    preset.icon,
                    color: isDestructive && selected
                        ? colorScheme.onErrorContainer
                        : null,
                  ),
                ),
                const SizedBox(width: _spacing),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.title,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        preset.description,
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
                      ? (isDestructive ? colorScheme.error : colorScheme.primary)
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
