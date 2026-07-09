// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:pdf_tools/main.dart';
import 'package:pdf_tools/services/settings_service.dart';
import 'package:pdf_tools/services/theme_notifier.dart';

void main() {
  testWidgets('App renders smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsService = SettingsService();
    await settingsService.init();
    final themeNotifier = ThemeNotifier(ThemeMode.light);

    // Build our app and trigger a frame.
    await tester.pumpWidget(MyApp(
      settingsService: settingsService,
      themeNotifier: themeNotifier,
      onboardingDone: true,
    ));

    // Verify the app renders with navigation.
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Files'), findsOneWidget);
  });
}
