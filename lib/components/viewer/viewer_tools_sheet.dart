import 'package:flutter/material.dart';

import 'viewer_setting_rows.dart';

enum ReadingDirection {
  vertical('Vertical'),
  horizontalLtr('Left to right'),
  horizontalRtl('Right to left');

  const ReadingDirection(this.label);
  final String label;
}

enum BackgroundTheme {
  light('White'),
  dark('Black'),
  sepia('Sepia');

  const BackgroundTheme(this.label);
  final String label;
}

enum ScaleType {
  fitScreen('Fit screen'),
  fitWidth('Fit width'),
  fitHeight('Fit height'),
  original('Original size');

  const ScaleType(this.label);
  final String label;
}

class ViewerToolsSheet extends StatefulWidget {
  const ViewerToolsSheet({
    super.key,
    required this.readingDirection,
    required this.backgroundTheme,
    required this.scaleType,
    required this.grayscale,
    required this.brightness,
    required this.onReadingDirectionChanged,
    required this.onBackgroundThemeChanged,
    required this.onScaleTypeChanged,
    required this.onGrayscaleToggled,
    required this.onBrightnessChanged,
  });

  final ReadingDirection readingDirection;
  final BackgroundTheme backgroundTheme;
  final ScaleType scaleType;
  final bool grayscale;
  final double brightness;
  final ValueChanged<ReadingDirection> onReadingDirectionChanged;
  final ValueChanged<BackgroundTheme> onBackgroundThemeChanged;
  final ValueChanged<ScaleType> onScaleTypeChanged;
  final VoidCallback onGrayscaleToggled;
  final ValueChanged<double> onBrightnessChanged;

  @override
  State<ViewerToolsSheet> createState() => _ViewerToolsSheetState();
}

class _ViewerToolsSheetState extends State<ViewerToolsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late ReadingDirection _readingDirection;
  late BackgroundTheme _backgroundTheme;
  late ScaleType _scaleType;
  late bool _grayscale;
  late double _brightness;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _readingDirection = widget.readingDirection;
    _backgroundTheme = widget.backgroundTheme;
    _scaleType = widget.scaleType;
    _grayscale = widget.grayscale;
    _brightness = widget.brightness;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onReadingDirectionChanged(ReadingDirection d) {
    setState(() => _readingDirection = d);
    widget.onReadingDirectionChanged(d);
  }

  void _onBackgroundThemeChanged(BackgroundTheme t) {
    setState(() => _backgroundTheme = t);
    widget.onBackgroundThemeChanged(t);
  }

  void _onScaleTypeChanged(ScaleType t) {
    setState(() => _scaleType = t);
    widget.onScaleTypeChanged(t);
  }

  void _onGrayscaleToggled() {
    setState(() => _grayscale = !_grayscale);
    widget.onGrayscaleToggled();
  }

  void _onBrightnessChanged(double b) {
    setState(() => _brightness = b);
    widget.onBrightnessChanged(b);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        spacing: 12,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withAlpha(60),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor: Theme.of(
              context,
            ).colorScheme.onSurfaceVariant,
            indicatorColor: Theme.of(context).colorScheme.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(text: 'General'),
              Tab(text: 'Paged'),
              Tab(text: 'Filter'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    const ViewerSectionHeader(title: 'Reading'),
                    ViewerEnumSelect<ReadingDirection>(
                      label: 'Reading direction',
                      values: ReadingDirection.values,
                      selected: _readingDirection,
                      labelOf: (d) => d.label,
                      onChanged: _onReadingDirectionChanged,
                    ),
                    ViewerEnumSelect<BackgroundTheme>(
                      label: 'Background color',
                      values: BackgroundTheme.values,
                      selected: _backgroundTheme,
                      labelOf: (t) => t.label,
                      onChanged: _onBackgroundThemeChanged,
                    ),
                  ],
                ),
                ListView(
                  padding: const EdgeInsets.only(bottom: 32),
                  children: [
                    const ViewerSectionHeader(title: 'Scale'),
                    ViewerEnumSelect<ScaleType>(
                      label: 'Scale type',
                      values: ScaleType.values,
                      selected: _scaleType,
                      labelOf: (t) => t.label,
                      onChanged: _onScaleTypeChanged,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const ViewerSectionHeader(title: 'Color'),
                      ViewerToggleRow(
                        label: 'Grayscale',
                        value: _grayscale,
                        onChanged: (_) => _onGrayscaleToggled(),
                      ),
                      ViewerSliderRow(
                        label: 'Brightness',
                        value: _brightness,
                        min: -1.0,
                        max: 1.0,
                        onChanged: _onBrightnessChanged,
                        icon: Icons.brightness_6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
