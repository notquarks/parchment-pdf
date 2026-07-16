import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf_tools/core/widgets/item_card.dart';
import 'package:pdf_tools/features/home/data/models/recent_file.dart';
import 'package:pdf_tools/features/home/presentation/providers/recent_files_provider.dart';
import 'package:pdf_tools/features/home/presentation/tool_definitions.dart';
import 'package:pdf_tools/features/home/presentation/widgets/m3_flex_space.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.title, this.onViewAllFiles});

  final String title;
  final VoidCallback? onViewAllFiles;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<RecentFile> _recentFiles = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadRecentFiles();
  }

  Future<void> _loadRecentFiles() async {
    final service = RecentFilesProvider.of(context);
    final files = await service.getRecentFiles();
    if (!mounted) return;
    setState(() {
      _recentFiles = files.take(10).toList();
    });
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 150.0,
          pinned: true,
          floating: false,
          flexibleSpace: FlexibleSpaceM3(title: widget.title),
          actions: [
            M3ETextButton(
              onPressed: () => Navigator.pushNamed(context, '/settings'),
              child: Icon(Icons.settings),
            ),
          ],
        ),
        SliverPadding(
          padding: const EdgeInsets.all(4.0),
          sliver: SliverLayoutBuilder(
            builder: (context, constraints) {
              const maxCrossAxisExtent = 200.0;
              const crossAxisSpacing = 8.0;
              const mainAxisSpacing = 8.0;
              const maxColumns = 4;
              const cardHeightCompact = 200.0;
              const cardHeightWide = 128.0;
              final extent = constraints.crossAxisExtent;
              var crossAxisCount =
                  (extent / (maxCrossAxisExtent + crossAxisSpacing)).ceil();
              if (crossAxisCount < 1) crossAxisCount = 1;
              if (crossAxisCount > maxColumns) crossAxisCount = maxColumns;
              final usable = extent - crossAxisSpacing * (crossAxisCount - 1);
              final cardWidth = usable / crossAxisCount;
              final compact = cardWidth < ItemCard.gridBreakpoint;
              final cardHeight = compact ? cardHeightCompact : cardHeightWide;
              final childAspectRatio = cardWidth > 0
                  ? cardWidth / cardHeight
                  : 1.0;
              return SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  childAspectRatio: childAspectRatio,
                  crossAxisSpacing: crossAxisSpacing,
                  mainAxisSpacing: mainAxisSpacing,
                ),
                delegate: SliverChildListDelegate([
                  for (final tool in toolDefinitions)
                    ItemCard(
                      title: tool.title,
                      subtitle: tool.subtitle,
                      icon: Icon(tool.icon, size: 28),
                      onTap: () => Navigator.pushNamed(context, tool.route),
                      isCompact: compact,
                    ),
                ]),
              );
            },
          ),
        ),
        SliverToBoxAdapter(
          child: ListTile(
            title: const Text('Recent Files'),
            trailing: widget.onViewAllFiles != null
                ? TextButton(
                    onPressed: widget.onViewAllFiles,
                    child: const Text("View All"),
                  )
                : null,
          ),
        ),
        if (_recentFiles.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Text(
                  'No recent files',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            sliver: SliverList.builder(
              itemCount: _recentFiles.length,
              itemBuilder: (context, index) {
                final file = _recentFiles[index];
                return ItemCard(
                  title: file.fileName,
                  icon: Icon(Symbols.docs),
                  subtitle: _formatTimestamp(file.timestamp),
                  onTap: () => OpenFilex.open(file.filePath),
                );
              },
            ),
          ),
      ],
    );
  }
}
