import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/settings/data/services/theme_notifier.dart';
import 'package:pdf_tools/core/utils/storage_helper.dart';

class OnboardingScreen extends StatefulWidget {
  final SettingsService settingsService;
  final ThemeNotifier themeNotifier;
  final VoidCallback? onComplete;

  const OnboardingScreen({
    super.key,
    required this.settingsService,
    required this.themeNotifier,
    this.onComplete,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  bool _darkMode = false;
  String _savePath = '';
  String _initialSavePath = '';
  bool _permissionGranted = false;
  bool _defaultsLoaded = false;

  static const _totalPages = 3;

  @override
  void initState() {
    super.initState();
    _initDefaults();
  }

  Future<void> _initDefaults() async {
    _darkMode = await widget.settingsService.getDarkMode();
    _savePath = await widget.settingsService.getSavePath();
    _initialSavePath = _savePath;
    if (Platform.isAndroid) {
      _permissionGranted = await StorageHelper.isStoragePermissionGranted();
    } else {
      _permissionGranted = true;
    }
    if (!mounted) return;
    setState(() {
      _defaultsLoaded = true;
    });
  }

  void _nextPage() {
    if (_currentPage >= _totalPages - 1) return;
    if (_currentPage == 1 &&
        Platform.isAndroid &&
        !_permissionGranted) {
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finish() async {
    if (!_canFinish) return;
    if (!_defaultsLoaded) {
      return;
    }
    if (_darkMode != await widget.settingsService.getDarkMode()) {
      await widget.settingsService.setDarkMode(_darkMode);
    }
    widget.themeNotifier.toggleDark(_darkMode);
    if (_savePath.isNotEmpty && _savePath != _initialSavePath) {
      await widget.settingsService.setSavePath(_savePath);
    }
    await widget.settingsService.setOnboardingComplete(true);
    if (!mounted) return;
    if (widget.onComplete != null) {
      widget.onComplete!();
    } else {
      Navigator.of(context).pop();
    }
  }

  bool get _canFinish {
    if (_currentPage == _totalPages - 1) {
      return _savePath.isNotEmpty;
    }
    if (_currentPage == 1 && Platform.isAndroid) {
      return _permissionGranted;
    }
    return true;
  }

  bool get _canSkip =>
      !(_currentPage == 1 && Platform.isAndroid);

  bool get _canAdvance {
    if (_currentPage >= _totalPages - 1) return false;
    if (_currentPage == 1 && Platform.isAndroid && !_permissionGranted) {
      return false;
    }
    return true;
  }

  Future<void> _pickFolder() async {
    final path = await StorageHelper.pickFolder();
    if (path != null && mounted) {
      setState(() => _savePath = path);
    }
  }

  Future<void> _requestPermission() async {
    final granted = await StorageHelper.ensureStoragePermission();
    if (mounted) {
      setState(() => _permissionGranted = granted);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == i
                          ? cs.primary
                          : cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _ThemePage(
                    darkMode: _darkMode,
                    onChanged: (v) {
                      setState(() => _darkMode = v);
                      widget.themeNotifier.toggleDark(v);
                    },
                  ),
                  _PermissionPage(
                    isAndroid: Platform.isAndroid,
                    granted: _permissionGranted,
                    onRequest: _requestPermission,
                  ),
                  _SaveLocationPage(
                    savePath: _savePath,
                    onPickFolder: _pickFolder,
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _previousPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox.shrink(),
                  const Spacer(),
                  if (_currentPage < _totalPages - 1) ...[
                    if (_canSkip)
                      TextButton(
                        onPressed: _finish,
                        child: const Text('Skip'),
                      ),
                    if (_canSkip) const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _canAdvance ? _nextPage : null,
                      child: const Text('Next'),
                    ),
                  ] else
                    FilledButton(
                      onPressed: _canFinish ? _finish : null,
                      child: const Text('Get Started'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePage extends StatelessWidget {
  final bool darkMode;
  final ValueChanged<bool> onChanged;

  const _ThemePage({required this.darkMode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.dark_mode, size: 64, color: cs.primary),
          const SizedBox(height: 24),
          Text('Choose Your Theme', style: tt.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Pick a light or dark appearance.',
            style: tt.bodyMedium?.copyWith(color: cs.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('Light'),
                icon: Icon(Icons.light_mode),
              ),
              ButtonSegment(
                value: true,
                label: Text('Dark'),
                icon: Icon(Icons.dark_mode),
              ),
            ],
            selected: {darkMode},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      ),
    );
  }
}

class _SaveLocationPage extends StatelessWidget {
  final String savePath;
  final VoidCallback onPickFolder;

  const _SaveLocationPage({required this.savePath, required this.onPickFolder});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open, size: 64, color: cs.primary),
          const SizedBox(height: 24),
          Text('Save Location', style: tt.headlineSmall),
          const SizedBox(height: 12),
          Text(
            'Choose where your processed files will be saved.',
            style: tt.bodyMedium?.copyWith(color: cs.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          Card(
            child: ListTile(
              leading: const Icon(Icons.folder),
              title: Text(
                savePath,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.edit),
              onTap: onPickFolder,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionPage extends StatelessWidget {
  final bool isAndroid;
  final bool granted;
  final VoidCallback onRequest;

  const _PermissionPage({
    required this.isAndroid,
    required this.granted,
    required this.onRequest,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            granted ? Icons.check_circle : Icons.lock_open,
            size: 64,
            color: granted ? cs.onPrimaryContainer : cs.primary,
          ),
          const SizedBox(height: 24),
          Text('Storage Access', style: tt.headlineSmall),
          const SizedBox(height: 12),
          Text(
            isAndroid
                ? 'Grant storage permission so the app can save files to your chosen folders.'
                : 'No extra permissions needed on this platform.',
            style: tt.bodyMedium?.copyWith(color: cs.outline),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (isAndroid && !granted)
            FilledButton.icon(
              onPressed: onRequest,
              icon: const Icon(Icons.shield),
              label: const Text('Grant Permission'),
            )
          else if (isAndroid && granted)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Text('Permission granted', style: tt.bodyLarge),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check, color: cs.onPrimaryContainer),
                const SizedBox(width: 8),
                Text('All set!', style: tt.bodyLarge),
              ],
            ),
        ],
      ),
    );
  }
}
