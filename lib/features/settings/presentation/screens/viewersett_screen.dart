import 'dart:async';

import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';
import 'package:pdf_tools/features/viewer/data/models/viewer_settings.dart';

class ViewerSettingsScreen extends StatefulWidget {
  const ViewerSettingsScreen({super.key});

  @override
  State<ViewerSettingsScreen> createState() => _ViewerSettingsScreenState();
}

class _ViewerSettingsScreenState extends State<ViewerSettingsScreen> {
  ReadingDirection _readingDirection = ReadingDirection.vertical;
  BackgroundTheme _backgroundTheme = BackgroundTheme.dark;
  ScaleType _scaleType = ScaleType.smart;
  TapZoneMode _tapZoneMode = TapZoneMode.pagedOnly;
  ViewerContentFilter _contentFilter = ViewerContentFilter.original;
  double _pageSpacing = 8;
  bool _autoHideControls = true;
  bool _showPageNumber = true;
  double _brightness = 0;
  double _contrast = 1;
  double _saturation = 1;
  bool _loaded = false;

  static const double _brightnessMin = -0.5;
  static const double _brightnessMax = 0.5;
  static const double _contrastMin = 0.5;
  static const double _contrastMax = 1.5;
  static const double _saturationMin = 0;
  static const double _saturationMax = 2;

  static const double _pageSpacingMin = 0;
  static const double _pageSpacingMax = 28;
  static const int _pageSpacingDivisions = 14;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = SettingsProvider.of(context).settingsService;
    final results = await Future.wait([
      s.getReadingDirection(),
      s.getBackgroundTheme(),
      s.getScaleType(),
      s.getTapZoneMode(),
      s.getViewerContentFilter(),
      s.getPageSpacing(),
      s.getAutoHideControls(),
      s.getShowPageIndicator(),
      s.getBrightness(),
      s.getContrast(),
      s.getSaturation(),
    ]);
    if (!mounted) return;
    setState(() {
      _readingDirection = results[0] as ReadingDirection;
      _backgroundTheme = results[1] as BackgroundTheme;
      _scaleType = results[2] as ScaleType;
      _tapZoneMode = results[3] as TapZoneMode;
      _contentFilter = results[4] as ViewerContentFilter;
      _pageSpacing = results[5] as double;
      _autoHideControls = results[6] as bool;
      _showPageNumber = results[7] as bool;
      _brightness = results[8] as double;
      _contrast = results[9] as double;
      _saturation = results[10] as double;
    });
  }

  SettingsService get _settings => SettingsProvider.of(context).settingsService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Viewer Settings'),
            centerTitle: false,
            expandedHeight: 150,
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.only(
              start: 12,
              end: 12,
              bottom: 48,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 14,
                  ),
                  child: Text(
                    'Reading',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surfaceTint,
                    ),
                  ),
                ),
                M3ECardColumn(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  margin: EdgeInsets.zero,
                  children: [
                    _buildEnumTile<ReadingDirection>(
                      icon: Symbols.book_5_rounded,
                      title: 'Reading Mode',
                      selected: _readingDirection,
                      values: ReadingDirection.values,
                      labelOf: (v) => v.label,
                      onChanged: (value) {
                        setState(() => _readingDirection = value);
                        _settings.setReadingDirection(value);
                      },
                    ),
                    _buildEnumTile<ScaleType>(
                      icon: Symbols.fit_screen,
                      title: 'Page Scale',
                      selected: _scaleType,
                      values: ScaleType.values,
                      labelOf: (v) => v.label,
                      onChanged: (value) {
                        setState(() => _scaleType = value);
                        _settings.setScaleType(value);
                      },
                    ),

                    ListTile(
                      leading: Icon(Symbols.space_bar),
                      title: Text('Page Spacing'),
                      subtitle: Text(
                        '${_pageSpacing.round()} px',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      onTap: () {
                        _showPageSpacingSlider();
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 14,
                  ),
                  child: Text(
                    'Controls',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surfaceTint,
                    ),
                  ),
                ),
                M3ECardColumn(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  margin: EdgeInsets.zero,
                  children: [
                    _buildEnumTile<TapZoneMode>(
                      icon: Symbols.touch_app,
                      title: 'Tap Zones',
                      selected: _tapZoneMode,
                      values: TapZoneMode.values,
                      labelOf: (v) => v.label,
                      onChanged: (value) {
                        setState(() => _tapZoneMode = value);
                        _settings.setTapZoneMode(value);
                      },
                    ),
                    SwitchListTile(
                      secondary: Icon(Icons.visibility_off_outlined),
                      title: Text('Auto-hide Controls'),
                      subtitle: Text('Hide reader controls after inactivity'),
                      value: _autoHideControls,
                      onChanged: (value) {
                        setState(() => _autoHideControls = value);
                        _settings.setAutoHideControls(value);
                      },
                    ),
                    SwitchListTile(
                      secondary: Icon(Icons.numbers_outlined),
                      title: Text('Page Indicator'),
                      subtitle: Text(
                        'Keep the current page visible while reading',
                      ),
                      value: _showPageNumber,
                      onChanged: (value) {
                        setState(() => _showPageNumber = value);
                        _settings.setShowPageIndicator(value);
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 14,
                  ),
                  child: Text(
                    'Appearance',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surfaceTint,
                    ),
                  ),
                ),
                M3ECardColumn(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  margin: EdgeInsets.zero,
                  children: [
                    _buildEnumTile<BackgroundTheme>(
                      icon: Symbols.palette,
                      title: 'Background Theme',
                      selected: _backgroundTheme,
                      values: BackgroundTheme.values,
                      labelOf: (v) => v.label,
                      onChanged: (value) {
                        setState(() => _backgroundTheme = value);
                        _settings.setBackgroundTheme(value);
                      },
                    ),
                    _buildEnumTile<ViewerContentFilter>(
                      icon: Symbols.filter,
                      title: 'Content Filter',
                      selected: _contentFilter,
                      values: ViewerContentFilter.values,
                      labelOf: _contentFilterLabel,
                      onChanged: (value) {
                        setState(() => _contentFilter = value);
                        _settings.setViewerContentFilter(value);
                      },
                    ),
                    _buildSliderTile(
                      icon: Icons.brightness_6_outlined,
                      title: 'Brightness',
                      value: _brightness,
                      min: _brightnessMin,
                      max: _brightnessMax,
                      label: _signedPercent(_brightness),
                      onChanged: (v) {
                        setState(() => _brightness = v);
                        _settings.setBrightness(v);
                      },
                    ),
                    _buildSliderTile(
                      icon: Icons.contrast_outlined,
                      title: 'Contrast',
                      value: _contrast,
                      min: _contrastMin,
                      max: _contrastMax,
                      label: '${(_contrast * 100).round()}%',
                      onChanged: (v) {
                        setState(() => _contrast = v);
                        _settings.setContrast(v);
                      },
                    ),
                    _buildSliderTile(
                      icon: Icons.palette_outlined,
                      title: 'Saturation',
                      value: _saturation,
                      min: _saturationMin,
                      max: _saturationMax,
                      label: '${(_saturation * 100).round()}%',
                      onChanged: (v) {
                        setState(() => _saturation = v);
                        _settings.setSaturation(v);
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 14,
                  ),
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surfaceTint,
                    ),
                  ),
                ),
                M3ECardColumn(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  margin: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: Icon(Icons.restore_outlined),
                      title: Text('Reset to Defaults'),
                      subtitle: Text(
                        'Reset all viewer settings to their default values',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      onTap: () {
                        _showResetConfirmationDialog();
                      },
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnumTile<T extends Enum>({
    required IconData icon,
    required String title,
    required T selected,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(
        labelOf(selected),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.outline,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showEnumPicker<T>(
        title: title,
        selected: selected,
        values: values,
        labelOf: labelOf,
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _showEnumPicker<T extends Enum>({
    required String title,
    required T selected,
    required List<T> values,
    required String Function(T) labelOf,
    required ValueChanged<T> onChanged,
  }) async {
    final result = await showModalBottomSheet<T>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final value in values)
                ListTile(
                  title: Text(labelOf(value)),
                  trailing: value == selected
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () => Navigator.pop(context, value),
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (result != null) {
      onChanged(result);
    }
  }

  Future<void> _showPageSpacingSlider() async {
    final result = await showModalBottomSheet<double>(
      context: context,
      builder: (context) {
        double value = _pageSpacing;
        return StatefulBuilder(
          builder: (context, setState) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Text(
                      'Page Spacing',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      children: [
                        Text('${_pageSpacingMin.round()}'),
                        Expanded(
                          child: Slider(
                            value: value,
                            min: _pageSpacingMin,
                            max: _pageSpacingMax,
                            divisions: _pageSpacingDivisions,
                            label: '${value.round()} px',
                            onChanged: (v) => setState(() => value = v),
                          ),
                        ),
                        Text('${_pageSpacingMax.round()}'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '${value.round()} px',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.pop(context, value),
                        child: const Text('Save'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (result != null) {
      setState(() => _pageSpacing = result);
      _settings.setPageSpacing(result);
    }
  }

  String _contentFilterLabel(ViewerContentFilter filter) {
    return switch (filter) {
      ViewerContentFilter.original => 'Original',
      ViewerContentFilter.grayscale => 'Grayscale',
      ViewerContentFilter.sepia => 'Sepia',
      ViewerContentFilter.invert => 'Invert',
    };
  }

  String _signedPercent(double value) {
    final pct = (value * 100).round();
    return pct > 0 ? '+$pct%' : '$pct%';
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required double value,
    required double min,
    required double max,
    required String label,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ListTile(
            leading: Icon(icon),
            title: Text(title),
            trailing: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Future<void> _showResetConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.restore_outlined,
          color: Theme.of(context).colorScheme.error,
        ),
        title: const Text('Reset to Defaults?'),
        content: const Text(
          'This will reset all viewer settings including reading mode, '
          'appearance, brightness, contrast, and saturation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _readingDirection = ReadingDirection.vertical;
      _backgroundTheme = BackgroundTheme.dark;
      _scaleType = ScaleType.smart;
      _tapZoneMode = TapZoneMode.pagedOnly;
      _contentFilter = ViewerContentFilter.original;
      _pageSpacing = SettingsService.defaultPageSpacing;
      _autoHideControls = true;
      _showPageNumber = true;
      _brightness = SettingsService.defaultBrightness;
      _contrast = SettingsService.defaultContrast;
      _saturation = SettingsService.defaultSaturation;
    });
    _settings.setReadingDirection(ReadingDirection.vertical);
    _settings.setBackgroundTheme(BackgroundTheme.dark);
    _settings.setScaleType(ScaleType.smart);
    _settings.setTapZoneMode(TapZoneMode.pagedOnly);
    _settings.setViewerContentFilter(ViewerContentFilter.original);
    _settings.setPageSpacing(SettingsService.defaultPageSpacing);
    _settings.setAutoHideControls(true);
    _settings.setShowPageIndicator(true);
    _settings.setBrightness(SettingsService.defaultBrightness);
    _settings.setContrast(SettingsService.defaultContrast);
    _settings.setSaturation(SettingsService.defaultSaturation);
  }
}
