import 'package:flutter/material.dart';
import 'package:pdf_tools/features/viewer/data/models/viewer_settings.dart';

import 'viewer_setting_rows.dart';

class ViewerToolsSheet extends StatefulWidget {
  const ViewerToolsSheet({
    super.key,
    required this.readingDirection,
    required this.backgroundTheme,
    required this.scaleType,
    required this.contentFilter,
    required this.tapZoneMode,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.pageSpacing,
    required this.showPageIndicator,
    required this.autoHideControls,
    required this.onReadingDirectionChanged,
    required this.onBackgroundThemeChanged,
    required this.onScaleTypeChanged,
    required this.onContentFilterChanged,
    required this.onTapZoneModeChanged,
    required this.onBrightnessChanged,
    required this.onContrastChanged,
    required this.onSaturationChanged,
    required this.onPageSpacingChanged,
    required this.onShowPageIndicatorChanged,
    required this.onAutoHideControlsChanged,
    required this.onResetAppearance,
    this.isPanel = false,
  });

  final ReadingDirection readingDirection;
  final BackgroundTheme backgroundTheme;
  final ScaleType scaleType;
  final ViewerContentFilter contentFilter;
  final TapZoneMode tapZoneMode;
  final double brightness;
  final double contrast;
  final double saturation;
  final double pageSpacing;
  final bool showPageIndicator;
  final bool autoHideControls;
  final ValueChanged<ReadingDirection> onReadingDirectionChanged;
  final ValueChanged<BackgroundTheme> onBackgroundThemeChanged;
  final ValueChanged<ScaleType> onScaleTypeChanged;
  final ValueChanged<ViewerContentFilter> onContentFilterChanged;
  final ValueChanged<TapZoneMode> onTapZoneModeChanged;
  final ValueChanged<double> onBrightnessChanged;
  final ValueChanged<double> onContrastChanged;
  final ValueChanged<double> onSaturationChanged;
  final ValueChanged<double> onPageSpacingChanged;
  final ValueChanged<bool> onShowPageIndicatorChanged;
  final ValueChanged<bool> onAutoHideControlsChanged;
  final VoidCallback onResetAppearance;
  final bool isPanel;

  @override
  State<ViewerToolsSheet> createState() => _ViewerToolsSheetState();
}

class _ViewerToolsSheetState extends State<ViewerToolsSheet>
    with SingleTickerProviderStateMixin {
  static const int _tabCount = 3;
  static const double _compactHeightFactor = 0.72;
  static const double _panelWidth = 420;
  static const double _panelVerticalInset = 24;
  static const double _panelRadius = 20;
  static const double _sheetRadius = 24;
  static const double _dragHandleWidth = 40;
  static const double _dragHandleHeight = 4;
  static const double _dragHandleTop = 12;
  static const double _dragHandleBottom = 6;
  static const double _contentBottomPadding = 32;
  static const double _brightnessMin = -0.5;
  static const double _brightnessMax = 0.5;
  static const double _contrastMin = 0.5;
  static const double _contrastMax = 1.5;
  static const double _saturationMin = 0;
  static const double _saturationMax = 2;
  static const double _pageSpacingMin = 0;
  static const double _pageSpacingMax = 28;
  static const int _pageSpacingDivisions = 14;
  static const int _dragHandleAlpha = 70;
  static const double _defaultBrightness = 0;
  static const double _defaultContrast = 1;
  static const double _defaultSaturation = 1;
  static const double _percentageFactor = 100;

  late final TabController _tabController;
  late ReadingDirection _readingDirection;
  late BackgroundTheme _backgroundTheme;
  late ScaleType _scaleType;
  late ViewerContentFilter _contentFilter;
  late TapZoneMode _tapZoneMode;
  late double _brightness;
  late double _contrast;
  late double _saturation;
  late double _pageSpacing;
  late bool _showPageIndicator;
  late bool _autoHideControls;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabCount, vsync: this);
    _readingDirection = widget.readingDirection;
    _backgroundTheme = widget.backgroundTheme;
    _scaleType = widget.scaleType;
    _contentFilter = widget.contentFilter;
    _tapZoneMode = widget.tapZoneMode;
    _brightness = widget.brightness;
    _contrast = widget.contrast;
    _saturation = widget.saturation;
    _pageSpacing = widget.pageSpacing;
    _showPageIndicator = widget.showPageIndicator;
    _autoHideControls = widget.autoHideControls;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final height = widget.isPanel
        ? size.height - _panelVerticalInset
        : size.height * _compactHeightFactor;
    final borderRadius = widget.isPanel
        ? const BorderRadius.all(Radius.circular(_panelRadius))
        : const BorderRadius.vertical(top: Radius.circular(_sheetRadius));

    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: widget.isPanel ? _panelWidth : double.infinity,
        height: height,
        child: SafeArea(
          top: widget.isPanel,
          child: Column(
            children: [
              if (!widget.isPanel)
                Padding(
                  padding: const EdgeInsets.only(
                    top: _dragHandleTop,
                    bottom: _dragHandleBottom,
                  ),
                  child: Container(
                    width: _dragHandleWidth,
                    height: _dragHandleHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withAlpha(_dragHandleAlpha),
                      borderRadius: BorderRadius.circular(_dragHandleHeight),
                    ),
                  ),
                ),
              if (widget.isPanel)
                ListTile(
                  title: Text(
                    'Reader settings',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  trailing: IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ),
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Reading'),
                  Tab(text: 'Controls'),
                  Tab(text: 'Appearance'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReadingTab(),
                    _buildControlsTab(),
                    _buildAppearanceTab(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReadingTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: _contentBottomPadding),
      children: [
        const ViewerSectionHeader(title: 'Layout'),
        ViewerEnumSelect<ReadingDirection>(
          label: 'Reading mode',
          leading: Icons.chrome_reader_mode_outlined,
          values: ReadingDirection.values,
          selected: _readingDirection,
          labelOf: (value) => value.label,
          onChanged: (value) {
            setState(() => _readingDirection = value);
            widget.onReadingDirectionChanged(value);
          },
        ),
        ViewerEnumSelect<ScaleType>(
          label: 'Page scale',
          leading: Icons.fit_screen_outlined,
          values: ScaleType.values,
          selected: _scaleType,
          labelOf: (value) => value.label,
          onChanged: (value) {
            setState(() => _scaleType = value);
            widget.onScaleTypeChanged(value);
          },
        ),
        ViewerSliderRow(
          label: 'Page spacing',
          leading: Icons.space_bar,
          value: _pageSpacing,
          min: _pageSpacingMin,
          max: _pageSpacingMax,
          divisions: _pageSpacingDivisions,
          valueLabel: '${_pageSpacing.round()} px',
          onChanged: (value) {
            setState(() => _pageSpacing = value);
          },
          onChangeEnd: widget.onPageSpacingChanged,
        ),
      ],
    );
  }

  Widget _buildControlsTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: _contentBottomPadding),
      children: [
        const ViewerSectionHeader(title: 'Interaction'),
        ViewerEnumSelect<TapZoneMode>(
          label: 'Tap zones',
          leading: Icons.touch_app_outlined,
          values: TapZoneMode.values,
          selected: _tapZoneMode,
          labelOf: (value) => value.label,
          onChanged: (value) {
            setState(() => _tapZoneMode = value);
            widget.onTapZoneModeChanged(value);
          },
        ),
        ViewerToggleRow(
          label: 'Auto-hide controls',
          subtitle: 'Hide reader controls after inactivity',
          leading: Icons.visibility_off_outlined,
          value: _autoHideControls,
          onChanged: (value) {
            setState(() => _autoHideControls = value);
            widget.onAutoHideControlsChanged(value);
          },
        ),
        ViewerToggleRow(
          label: 'Page indicator',
          subtitle: 'Keep the current page visible while reading',
          leading: Icons.numbers_outlined,
          value: _showPageIndicator,
          onChanged: (value) {
            setState(() => _showPageIndicator = value);
            widget.onShowPageIndicatorChanged(value);
          },
        ),
      ],
    );
  }

  Widget _buildAppearanceTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: _contentBottomPadding),
      children: [
        const ViewerSectionHeader(title: 'Canvas'),
        ViewerEnumSelect<BackgroundTheme>(
          label: 'Background',
          leading: Icons.format_color_fill_outlined,
          values: BackgroundTheme.values,
          selected: _backgroundTheme,
          labelOf: (value) => value.label,
          onChanged: (value) {
            setState(() => _backgroundTheme = value);
            widget.onBackgroundThemeChanged(value);
          },
        ),
        const ViewerSectionHeader(title: 'Document'),
        ViewerEnumSelect<ViewerContentFilter>(
          label: 'Content filter',
          leading: Icons.filter_b_and_w_outlined,
          values: ViewerContentFilter.values,
          selected: _contentFilter,
          labelOf: _contentFilterLabel,
          onChanged: (value) {
            setState(() => _contentFilter = value);
            widget.onContentFilterChanged(value);
          },
        ),
        ViewerSliderRow(
          label: 'Brightness',
          leading: Icons.brightness_6_outlined,
          value: _brightness,
          min: _brightnessMin,
          max: _brightnessMax,
          valueLabel: _signedValue(_brightness),
          onChanged: (value) {
            setState(() => _brightness = value);
            widget.onBrightnessChanged(value);
          },
        ),
        ViewerSliderRow(
          label: 'Contrast',
          leading: Icons.contrast_outlined,
          value: _contrast,
          min: _contrastMin,
          max: _contrastMax,
          valueLabel: '${(_contrast * _percentageFactor).round()}%',
          onChanged: (value) {
            setState(() => _contrast = value);
            widget.onContrastChanged(value);
          },
        ),
        ViewerSliderRow(
          label: 'Saturation',
          leading: Icons.palette_outlined,
          value: _saturation,
          min: _saturationMin,
          max: _saturationMax,
          valueLabel: '${(_saturation * _percentageFactor).round()}%',
          onChanged: (value) {
            setState(() => _saturation = value);
            widget.onSaturationChanged(value);
          },
        ),
        ViewerActionRow(
          label: 'Reset appearance',
          leading: Icons.restart_alt,
          onPressed: () {
            setState(() {
              _backgroundTheme = BackgroundTheme.dark;
              _contentFilter = ViewerContentFilter.original;
              _brightness = _defaultBrightness;
              _contrast = _defaultContrast;
              _saturation = _defaultSaturation;
            });
            widget.onResetAppearance();
          },
        ),
      ],
    );
  }

  String _contentFilterLabel(ViewerContentFilter filter) {
    return switch (filter) {
      ViewerContentFilter.original => 'Original',
      ViewerContentFilter.grayscale => 'Grayscale',
      ViewerContentFilter.sepia => 'Sepia',
      ViewerContentFilter.invert => 'Invert',
    };
  }

  String _signedValue(double value) {
    final percentage = (value * _percentageFactor).round();
    return percentage > 0 ? '+$percentage%' : '$percentage%';
  }
}
