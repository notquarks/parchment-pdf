import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const _keyDarkMode = 'dark_mode';
  static const _keyLanguage = 'language';
  static const _keySavePath = 'save_path';
  static const _keyOnboardingComplete = 'onboarding_complete';

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
