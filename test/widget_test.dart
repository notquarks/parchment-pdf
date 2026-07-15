// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_tools/main.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/settings/data/services/theme_notifier.dart';
import 'package:pdf_tools/features/home/data/services/recent_files_service.dart';
import 'package:pdf_tools/features/home/data/models/recent_file.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    final settingsService = _FakeSettingsService();
    final themeNotifier = ThemeNotifier(ThemeMode.light);
    final recentFilesService = _FakeRecentFilesService();

    await tester.pumpWidget(MyApp(
      settingsService: settingsService,
      themeNotifier: themeNotifier,
      onboardingDone: true,
      recentFilesService: recentFilesService,
    ));

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
  });
}

class _FakeSettingsService extends SettingsService {
  @override
  Future<String> getSavePath() async => '';
}

class _FakeRecentFilesService extends RecentFilesService {
  @override
  Future<void> init() async {}

  @override
  Future<List<RecentFile>> getRecentFiles() async => [];

  @override
  Future<void> addRecentFile(RecentFile file) async {}

  @override
  Future<void> clearRecentFiles() async {}
}
