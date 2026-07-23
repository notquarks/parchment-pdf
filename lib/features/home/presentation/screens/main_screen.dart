import 'package:flutter/material.dart';
import 'package:pdf_tools/features/home/presentation/screens/files_screen.dart';
import 'package:pdf_tools/features/home/presentation/screens/home_screen.dart';
import 'package:pdf_tools/features/settings/presentation/screens/settings_screen.dart';
import 'package:pdf_tools/features/home/presentation/screens/tools_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedPage = 0;

  void _navigateToFiles() {
    setState(() => _selectedPage = 1);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedPage,
        children: [
          HomeScreen(title: 'Parchiva', onViewAllFiles: _navigateToFiles),
          FilesScreen(),
          ToolsScreen(),
          SettingsScreen(),
        ],
      ),
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
