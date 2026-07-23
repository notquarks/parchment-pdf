import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:pdf_tools/core/widgets/item_card.dart';
import 'package:pdf_tools/features/home/presentation/tool_definitions.dart';
import 'package:pdf_tools/features/home/presentation/widgets/m3_flex_space.dart';

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 150.0,
          pinned: true,
          floating: false,
          flexibleSpace: FlexibleSpaceM3(title: 'Tools'),
          actions: [
            M3ETextButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: Icon(Icons.settings),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(4.0),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              for (final tool in toolDefinitions)
                ItemCard(
                  title: tool.title,
                  subtitle: tool.subtitle,
                  icon: Icon(tool.icon, size: 24),
                  onTap: () => Navigator.pushNamed(context, tool.route),
                  isCompact: false,
                ),
            ]),
          ),
        ),
      ],
    );
  }
}
