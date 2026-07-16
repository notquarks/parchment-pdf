import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_tools/app/app.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/settings/data/services/theme_notifier.dart';
import 'package:pdf_tools/features/home/data/services/recent_files_service.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

export 'app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PdfService.ensureInitialized();

  PaintingBinding.instance.imageCache.maximumSizeBytes = 200 * 1024 * 1024;
  PaintingBinding.instance.imageCache.maximumSize = 500;

  final settingsService = SettingsService();
  await settingsService.init();

  final isDark = await settingsService.getDarkMode();
  final onboardingDone = await settingsService.getOnboardingComplete();
  final themeNotifier = ThemeNotifier(
    isDark ? ThemeMode.dark : ThemeMode.light,
  );

  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  final recentFilesService = RecentFilesService();
  await recentFilesService.init();

  runApp(
    MyApp(
      settingsService: settingsService,
      themeNotifier: themeNotifier,
      onboardingDone: onboardingDone,
      recentFilesService: recentFilesService,
    ),
  );
}
