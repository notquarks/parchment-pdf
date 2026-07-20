import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/settings/data/services/theme_notifier.dart';
import 'package:pdf_tools/features/settings/presentation/screens/onboarding_screen.dart';

class AdvancedSettingsScreen extends StatefulWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  State<AdvancedSettingsScreen> createState() => _AdvancedSettingsScreenState();
}

class _AdvancedSettingsScreenState extends State<AdvancedSettingsScreen> {
  late final SettingsService _settingsService;

  late final ThemeNotifier _themeNotifier;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Advanced Settings'),
            centerTitle: false,
            expandedHeight: 150,
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
            sliver: SliverList(delegate: SliverChildListDelegate([ListTile(
                      leading: const Icon(Icons.rocket_launch),
                      title: Text(
                        'Setup Wizard',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        'Re-run the initial setup',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OnboardingScreen(
                            settingsService: _settingsService,
                            themeNotifier: _themeNotifier,
                          ),
                        ),
                      ),
                    ),]),),
      )]
      ),
    );
  }
}