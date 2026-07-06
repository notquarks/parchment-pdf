import 'package:flutter/material.dart';
import 'package:pdf_tools/screen/files_screen.dart';
import 'package:pdf_tools/screen/home_screen.dart';
import 'package:pdf_tools/screen/settings_screen.dart';
import 'package:pdf_tools/screen/tools_screen.dart';

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
