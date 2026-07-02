import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:pdf_tools/components/FlexibleSpaceM3.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _darkMode = false;
  String _language = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 150,
            flexibleSpace: FlexibleSpaceM3(title: 'Settings'),
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
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
                  padding: .symmetric(horizontal: 2, vertical: 4),
                  margin: .zero,
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
                        padding: .zero,
                        value: _darkMode,
                        onChanged: (value) {
                          setState(() {
                            _darkMode = value;
                          });
                        },
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
                      trailing: Switch.adaptive(
                        padding: .zero,
                        value: _darkMode,
                        onChanged: (value) {
                          setState(() {
                            _darkMode = value;
                          });
                        },
                      ),
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
