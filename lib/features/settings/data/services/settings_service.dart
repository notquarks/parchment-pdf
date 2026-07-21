import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_tools/features/viewer/data/models/viewer_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyDarkMode = 'dark_mode';
  static const _keyLanguage = 'language';
  static const _keySavePath = 'save_path';
  static const _keyOnboardingComplete = 'onboarding_complete';
  static const _keyReadingDirection = 'reading_direction';
  static const _keyBackgroundTheme = 'background_theme';
  static const _keyScaleType = 'scale_type';
  static const _keyTapZoneMode = 'tap_zone_mode';
  static const _keyContentFilter = 'viewer_content_filter';
  static const _keyPageSpacing = 'page_spacing';

  late final SharedPreferencesAsync _prefs;

  Future<void> init() async {
    _prefs = SharedPreferencesAsync();
  }

  Future<bool> getDarkMode() async {
    return await _prefs.getBool(_keyDarkMode) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    await _prefs.setBool(_keyDarkMode, value);
  }

  Future<String> getLanguage() async {
    return await _prefs.getString(_keyLanguage) ?? 'English';
  }

  Future<void> setLanguage(String value) async {
    await _prefs.setString(_keyLanguage, value);
  }

  Future<ReadingDirection> getReadingDirection() async {
    final name = await _prefs.getString(_keyReadingDirection);
    return ReadingDirection.values.byName(
      name ?? ReadingDirection.vertical.name,
    );
  }

  Future<void> setReadingDirection(ReadingDirection value) async {
    await _prefs.setString(_keyReadingDirection, value.name);
  }

  Future<BackgroundTheme> getBackgroundTheme() async {
    final name = await _prefs.getString(_keyBackgroundTheme);
    return BackgroundTheme.values.byName(name ?? BackgroundTheme.dark.name);
  }

  Future<void> setBackgroundTheme(BackgroundTheme value) async {
    await _prefs.setString(_keyBackgroundTheme, value.name);
  }

  Future<ScaleType> getScaleType() async {
    final name = await _prefs.getString(_keyScaleType);
    return ScaleType.values.byName(name ?? ScaleType.smart.name);
  }

  Future<void> setScaleType(ScaleType value) async {
    await _prefs.setString(_keyScaleType, value.name);
  }

  Future<TapZoneMode> getTapZoneMode() async {
    final name = await _prefs.getString(_keyTapZoneMode);
    return TapZoneMode.values.byName(name ?? TapZoneMode.pagedOnly.name);
  }

  Future<void> setTapZoneMode(TapZoneMode value) async {
    await _prefs.setString(_keyTapZoneMode, value.name);
  }

  Future<ViewerContentFilter> getViewerContentFilter() async {
    final name = await _prefs.getString(_keyContentFilter);
    return ViewerContentFilter.values.byName(
      name ?? ViewerContentFilter.original.name,
    );
  }

  Future<bool> getAutoHideControls() async {
    return await _prefs.getBool('auto_hide_controls') ?? true;
  }

  Future<void> setAutoHideControls(bool value) async {
    await _prefs.setBool('auto_hide_controls', value);
  }

  Future<bool> getShowPageIndicator() async {
    return await _prefs.getBool('show_page_indicator') ?? true;
  }

  Future<void> setShowPageIndicator(bool value) async {
    await _prefs.setBool('show_page_indicator', value);
  }

  Future<void> setViewerContentFilter(ViewerContentFilter value) async {
    await _prefs.setString(_keyContentFilter, value.name);
  }

  static const double defaultPageSpacing = 8;

  Future<double> getPageSpacing() async {
    return await _prefs.getDouble(_keyPageSpacing) ?? defaultPageSpacing;
  }

  Future<void> setPageSpacing(double value) async {
    await _prefs.setDouble(_keyPageSpacing, value);
  }

  static const double defaultBrightness = 0;
  static const double defaultContrast = 1;
  static const double defaultSaturation = 1;

  Future<double> getBrightness() async {
    return await _prefs.getDouble('brightness') ?? defaultBrightness;
  }

  Future<void> setBrightness(double value) async {
    await _prefs.setDouble('brightness', value);
  }

  Future<double> getContrast() async {
    return await _prefs.getDouble('contrast') ?? defaultContrast;
  }

  Future<void> setContrast(double value) async {
    await _prefs.setDouble('contrast', value);
  }

  Future<double> getSaturation() async {
    return await _prefs.getDouble('saturation') ?? defaultSaturation;
  }

  Future<void> setSaturation(double value) async {
    await _prefs.setDouble('saturation', value);
  }

  static Future<String> defaultSavePath() async {
    if (Platform.isAndroid) {
      final dir = await getExternalStorageDirectory();
      return dir?.path ?? '/storage/emulated/0/Download';
    }
    if (Platform.isIOS) {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    }
    final dir = await getDownloadsDirectory();
    return dir?.path ?? Directory.current.path;
  }

  Future<String> getSavePath() async {
    final saved = await _prefs.getString(_keySavePath);
    if (saved != null && await _isWritable(saved)) return saved;
    return await defaultSavePath();
  }

  static Future<bool> _isWritable(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return false;
      final probe = File(p.join(path, '.write_probe'));
      await probe.writeAsString('');
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setSavePath(String value) async {
    if (!await _isWritable(value)) return false;
    await _prefs.setString(_keySavePath, value);
    return true;
  }

  ThemeMode getThemeMode(bool isDark) {
    return isDark ? ThemeMode.dark : ThemeMode.light;
  }

  Future<bool> getOnboardingComplete() async {
    return await _prefs.getBool(_keyOnboardingComplete) ?? false;
  }

  Future<void> setOnboardingComplete(bool value) async {
    await _prefs.setBool(_keyOnboardingComplete, value);
  }
}
