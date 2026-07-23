import 'package:flutter/material.dart';
import 'package:pdf_tools/app/routes.dart';
import 'package:pdf_tools/features/home/presentation/screens/main_screen.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/settings/data/services/theme_notifier.dart';
import 'package:pdf_tools/features/home/data/services/recent_files_service.dart';
import 'package:pdf_tools/features/home/presentation/providers/recent_files_provider.dart';
import 'package:pdf_tools/features/settings/presentation/screens/onboarding_screen.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    required this.settingsService,
    required this.themeNotifier,
    required this.onboardingDone,
    required this.recentFilesService,
  });

  final SettingsService settingsService;
  final ThemeNotifier themeNotifier;
  final bool onboardingDone;
  final RecentFilesService recentFilesService;

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
    return RecentFilesProvider(
      service: widget.recentFilesService,
      child: SettingsProvider(
        settingsService: widget.settingsService,
        themeNotifier: widget.themeNotifier,
        child: MaterialApp(
          title: 'Parchiva PDF',
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
          routes: AppRoutes.routes,
        ),
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
