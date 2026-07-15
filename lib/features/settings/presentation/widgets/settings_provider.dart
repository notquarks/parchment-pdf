import 'package:flutter/material.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/settings/data/services/theme_notifier.dart';

class SettingsProvider extends InheritedWidget {
  final SettingsService settingsService;
  final ThemeNotifier themeNotifier;

  const SettingsProvider({
    super.key,
    required this.settingsService,
    required this.themeNotifier,
    required super.child,
  });

  static SettingsProvider of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<SettingsProvider>();
    assert(provider != null, 'No SettingsProvider found in context');
    return provider!;
  }

  @override
  bool updateShouldNotify(SettingsProvider oldWidget) =>
      settingsService != oldWidget.settingsService ||
      themeNotifier != oldWidget.themeNotifier;
}
