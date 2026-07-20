import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:pdf_tools/core/utils/storage_helper.dart';
import 'package:pdf_tools/features/home/presentation/widgets/m3_flex_space.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/settings/data/services/theme_notifier.dart';
import 'package:pdf_tools/features/settings/presentation/screens/onboarding_screen.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final SettingsService _settingsService;
  late final ThemeNotifier _themeNotifier;
  bool _darkMode = false;
  String _language = 'English';
  String _savePath = '';
  String _appVersion = '';
  bool _loading = true;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final provider = SettingsProvider.of(context);
      _settingsService = provider.settingsService;
      _themeNotifier = provider.themeNotifier;
      _loadSettings();
    }
  }

  Future<void> _loadSettings() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final darkMode = await _settingsService.getDarkMode();
    final language = await _settingsService.getLanguage();
    final savePath = await _settingsService.getSavePath();
    if (!mounted) return;
    setState(() {
      _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
      _darkMode = darkMode;
      _language = language;
      _savePath = savePath;
      _loading = false;
    });
  }

  Future<void> _toggleDarkMode(bool value) async {
    setState(() => _darkMode = value);
    await _settingsService.setDarkMode(value);
    _themeNotifier.toggleDark(value);
  }

  Future<void> _pickSavePath() async {
    final granted = await StorageHelper.ensureStoragePermission();
    if (!granted) {
      if (mounted)
        _showSnack('Storage permission needed to save to custom folders.');
      return;
    }

    final path = await StorageHelper.pickFolder();
    if (path == null || !mounted) return;

    if (await _settingsService.setSavePath(path)) {
      setState(() => _savePath = path);
    } else {
      _showSnack('Cannot write to selected folder. Choose another.');
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Settings'),
            centerTitle: false,
            expandedHeight: 150,
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 12, bottom: 96),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 14,
                  ),
                  child: Text(
                    'Preferences',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surfaceTint,
                    ),
                  ),
                ),
                M3ECardColumn(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                  ),
                  margin: EdgeInsets.zero,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.dark_mode),
                      title: Text(
                        'Dark Mode',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        'Dark Mode: $_darkMode',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      trailing: Switch.adaptive(
                        padding: EdgeInsets.zero,
                        value: _darkMode,
                        onChanged: _toggleDarkMode,
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.language),
                      title: Text(
                        'Language',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        _language,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.folder),
                      title: Text(
                        'Save Location',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        _savePath,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _pickSavePath,
                    ),
                    ListTile(
                      leading: const Icon(Symbols.chrome_reader_mode_rounded),
                      title: Text(
                        'Viewer Settings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      onTap: () { Navigator.pushNamed(context, '/viewer_settings'); },
                    ),
                    ListTile(
                      leading: const Icon(Symbols.code),
                      title: Text(
                        'Advanced Settings',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      onTap: () {
                        Navigator.pushNamed(context, '/advanced_settings');
                      },
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6.0,
                    vertical: 14,
                  ),
                  child: Text(
                    'About',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.surfaceTint,
                    ),
                  ),
                ),
                M3ECardColumn(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 2,
                  ),
                  margin: EdgeInsets.zero,
                  children: [
                    
                    ListTile(
                      leading: const Icon(Icons.info),
                      title: Text(
                        'Version',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      subtitle: Text(
                        _appVersion,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.outline,
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.system_update),
                      title: Text(
                        'Check for Updates',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      onTap: () {},
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: Text(
                        'Repository',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      onTap: () async {
                        launchUrl(
                          Uri.parse(
                            'https://github.com/notquarks/parchment-pdf',
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
