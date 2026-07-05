import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:pdf_tools/components/item_card.dart';
import 'package:pdf_tools/components/m3_flex_space.dart';
import 'package:pdf_tools/screen/files_screen.dart';
import 'package:pdf_tools/screen/merge_screen.dart';
import 'package:pdf_tools/screen/onboarding_screen.dart';
import 'package:pdf_tools/screen/settings_screen.dart';
import 'package:pdf_tools/screen/split_screen.dart';
import 'package:pdf_tools/screen/tools_screen.dart';
import 'package:pdf_tools/services/settings_provider.dart';
import 'package:pdf_tools/services/settings_service.dart';
import 'package:pdf_tools/services/theme_notifier.dart';
import 'package:pdf_tools/util/pdf.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await PdfService.ensureInitialized();

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

class _MyAppState extends State<MyApp> {
  late bool _onboardingDone;

  @override
  void initState() {
    super.initState();
    _onboardingDone = widget.onboardingDone;
    widget.themeNotifier.addListener(_onThemeChanged);
  }

  void _onThemeChanged() => setState(() {});

  @override
  void dispose() {
    widget.themeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SettingsProvider(
      settingsService: widget.settingsService,
      themeNotifier: widget.themeNotifier,
      child: MaterialApp(
        title: 'Parchment',
        themeMode: widget.themeNotifier.value,
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: .fromSeed(
            seedColor: Colors.orangeAccent,
            brightness: Brightness.light,
          ),
        ),
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          colorScheme: .fromSeed(
            seedColor: Colors.orangeAccent,
            brightness: Brightness.dark,
          ),
        ),
        home: _onboardingDone
            ? const MainScreen()
            : _OnboardingGate(
                settingsService: widget.settingsService,
                themeNotifier: widget.themeNotifier,
                onComplete: () => setState(() => _onboardingDone = true),
              ),
        routes: {
          '/merge': (context) => const MergeScreen(),
          '/split': (context) => const SplitScreen(),
          '/settings': (context) => const SettingsScreen(),
        },
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedPage = 0;
  final List<Widget> _pages = const [
    HomeScreen(title: 'Parchment'),
    FilesScreen(),
    ToolsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedPage, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedPage,
        onDestinationSelected: (index) => setState(() => _selectedPage = index),
        destinations: const [
          NavigationDestination(
            label: 'Home',
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_filled),
          ),
          NavigationDestination(
            label: 'Files',
            icon: Icon(Icons.file_copy_outlined),
            selectedIcon: Icon(Icons.file_copy),
          ),
          NavigationDestination(
            label: 'Tools',
            icon: Icon(Icons.home_repair_service_outlined),
            selectedIcon: Icon(Icons.home_repair_service),
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 150.0,
          pinned: true,
          flexibleSpace: FlexibleSpaceM3(title: title),
          actions: [
            M3ETextButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: Icon(Icons.settings),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(4.0),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
            ),
            delegate: SliverChildListDelegate([
              ItemCard(
                title: 'Merge',
                subtitle: 'Combine multiple pdf`s into one.',
                icon: Icon(Icons.merge, size: 28),
                onTap: () => Navigator.pushNamed(context, '/merge'),
              ),
              ItemCard(
                title: 'Split',
                subtitle: 'Extract pages or split docs.',
                icon: Icon(Icons.insert_page_break_outlined, size: 28),
                onTap: () => Navigator.pushNamed(context, '/split'),
              ),
              ItemCard(
                title: 'Compress',
                subtitle: 'Reduce file size quickly.',
                icon: Icon(Icons.compress_outlined, size: 28),
                onTap: () => Navigator.pushNamed(context, '/compress'),
              ),
              ItemCard(
                title: 'Edit',
                subtitle: 'Modify pdf file.',
                icon: Icon(Icons.edit_note_outlined, size: 28),
                onTap: () => Navigator.pushNamed(context, '/edit'),
              ),
            ]),
          ),
        ),
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text('Recent Files'),
            trailing: TextButton(
              onPressed: () {},
              child: const Text("View All"),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          sliver: SliverList.builder(
            itemCount: 20,
            itemBuilder: (context, index) {
              return ItemCard(
                title: 'Test $index',
                icon: const Icon(Icons.insert_drive_file),
                subtitle: "Date Time",
                onTap: () {},
              );
            },
          ),
        ),
      ],
    );
  }
}

class _OnboardingGate extends StatelessWidget {
  final SettingsService settingsService;
  final ThemeNotifier themeNotifier;
  final VoidCallback onComplete;

  const _OnboardingGate({
    required this.settingsService,
    required this.themeNotifier,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    return OnboardingScreen(
      settingsService: settingsService,
      themeNotifier: themeNotifier,
      onComplete: onComplete,
    );
  }
}
