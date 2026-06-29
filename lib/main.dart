import 'package:flutter/material.dart';
import 'package:pdf_tools/components/ItemCard.dart';
import 'package:pdf_tools/screen/files_screen.dart';
import 'package:pdf_tools/screen/merge_screen.dart';
import 'package:pdf_tools/screen/settings_screen.dart';
import 'package:pdf_tools/screen/tools_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Parchment',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: .fromSeed(
          seedColor: Colors.white,
          brightness: Brightness.light,
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: .fromSeed(
          seedColor: Colors.black,
          brightness: Brightness.dark,
        ),
      ),
      // home: const HomeScreen(title: 'Parchment'),
      initialRoute: '/',
      routes: {
        '/': (context) => const MainScreen(),
        '/merge': (context) => const MergeScreen(),
      },
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
          flexibleSpace: FlexibleSpaceBar(
            title: Text(title),
            centerTitle: false,
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => ItemCard(
              title: 'Merge',
              subtitle: 'Combine multiple pdf`s into one.',
              icon: Icon(Icons.merge),
              onTap: () => Navigator.pushNamed(context, '/merge'),
            ),
            childCount: 20,
          ),
        ),
      ],
    );
  }
}
