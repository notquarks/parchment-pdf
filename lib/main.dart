import 'package:flutter/material.dart';
import 'package:pdf_tools/screen/compress_screen.dart';
import 'package:pdf_tools/screen/main_screen.dart';
import 'package:pdf_tools/screen/merge_screen.dart';
import 'package:pdf_tools/screen/onboarding_screen.dart';
import 'package:pdf_tools/screen/settings_screen.dart';
import 'package:pdf_tools/screen/split_screen.dart';
import 'package:pdf_tools/screen/view_screen.dart';
import 'package:pdf_tools/services/settings_provider.dart';
import 'package:pdf_tools/services/settings_service.dart';
import 'package:pdf_tools/services/theme_notifier.dart';
import 'package:pdf_tools/util/pdf.dart';

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

  runApp(
    MyApp(
      settingsService: settingsService,
      themeNotifier: themeNotifier,
      onboardingDone: onboardingDone,
    ),
  );
}

class MyApp extends StatefulWidget {
  final SettingsService settingsService;
  final ThemeNotifier themeNotifier;
  final bool onboardingDone;

  const MyApp({
    super.key,
    required this.settingsService,
    required this.themeNotifier,
    required this.onboardingDone,
  });

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late bool _onboardingDone;

  @override
  void initState() {
    super.initState();
    _onboardingDone = widget.onboardingDone;
    widget.themeNotifier.addListener(_onThemeChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    PaintingBinding.instance.imageCache.clear();
    WidgetsBinding.instance.removeObserver(this);
    widget.themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return SettingsProvider(
      settingsService: widget.settingsService,
      themeNotifier: widget.themeNotifier,
      child: MaterialApp(
        themeMode: widget.themeNotifier.value,
        theme: ThemeData(
          brightness: Brightness.light,
          colorSchemeSeed: Colors.orangeAccent,
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: Colors.orangeAccent,
          useMaterial3: true,
        ),
        home: _onboardingDone
            ? const MainScreen()
            : _OnboardingGate(
                settingsService: widget.settingsService,
                themeNotifier: widget.themeNotifier,
                onComplete: () => setState(() => _onboardingDone = true),
              ),
        routes: {
          '/merge': (_) => const MergeScreen(),
          '/split': (_) => const SplitScreen(),
          '/compress': (_) => const CompressScreen(),
          '/settings': (_) => const SettingsScreen(),
        },
      ),
    );
  }
}

class _OnboardingGate extends StatelessWidget {
  const _OnboardingGate({
    required this.settingsService,
    required this.themeNotifier,
    required this.onComplete,
  });

  final SettingsService settingsService;
  final ThemeNotifier themeNotifier;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      settingsService: settingsService,
      themeNotifier: themeNotifier,
      onComplete: onComplete,
    );
  }
}
