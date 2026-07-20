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

    await tester.pumpWidget(
      MyApp(
        settingsService: settingsService,
        themeNotifier: themeNotifier,
        onboardingDone: true,
        recentFilesService: recentFilesService,
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
  });

  testWidgets('Recent files refresh after a result is saved', (
    WidgetTester tester,
  ) async {
    final settingsService = _FakeSettingsService();
    final themeNotifier = ThemeNotifier(ThemeMode.light);
    final recentFilesService = _FakeRecentFilesService();

    await tester.pumpWidget(
      MyApp(
        settingsService: settingsService,
        themeNotifier: themeNotifier,
        onboardingDone: true,
        recentFilesService: recentFilesService,
      ),
    );
    await tester.pump();

    expect(find.text('result.pdf'), findsNothing);

    await recentFilesService.addRecentFile(
      RecentFile(
        filePath: '/tmp/result.pdf',
        fileName: 'result.pdf',
        operationType: 'merge',
        inputFileCount: 2,
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('result.pdf'), findsOneWidget);
  });
}

class _FakeSettingsService extends SettingsService {
  @override
  Future<String> getSavePath() async => '';
}

class _FakeRecentFilesService extends RecentFilesService {
  final List<RecentFile> _files = [];

  @override
  Future<void> init() async {}

  @override
  Future<List<RecentFile>> getRecentFiles() async => List.of(_files);

  @override
  Future<void> addRecentFile(RecentFile file) async {
    _files.insert(0, file);
    notifyListeners();
  }

  @override
  Future<void> clearRecentFiles() async {
    _files.clear();
    notifyListeners();
  }
}
