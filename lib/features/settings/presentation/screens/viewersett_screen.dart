import 'package:flutter/material.dart';

class ViewerSettingsScreen extends StatelessWidget {
  const ViewerSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Viewer Settings'),
            centerTitle: false,
            expandedHeight: 150,
          ),
          SliverPadding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 12),
            sliver: SliverList.builder(itemBuilder:   (context, index) {
              return ListTile(
                leading: const Icon(Icons.settings),
                title: Text(
                  'Viewer Setting ${index + 1}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                onTap: () {
                  // Handle viewer setting tap
                },
              );
            }, itemCount: 32),
          ),
        ]
      )
    );
  }
}