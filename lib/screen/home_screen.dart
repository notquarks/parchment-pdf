import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:pdf_tools/components/item_card.dart';
import 'package:pdf_tools/components/m3_flex_space.dart';

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
          floating: false,
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
                  ItemCard(
                    title: 'Merge',
                    subtitle: 'Combine multiple pdf`s into one.',
                    icon: Icon(Icons.merge, size: 28),
                    onTap: () => Navigator.pushNamed(context, '/merge'),
                    isCompact: compact,
                  ),
                  ItemCard(
                    title: 'Split',
                    subtitle: 'Extract pages or split docs.',
                    icon: Icon(Icons.insert_page_break_outlined, size: 28),
                    onTap: () => Navigator.pushNamed(context, '/split'),
                    isCompact: compact,
                  ),
                  ItemCard(
                    title: 'Compress',
                    subtitle: 'Reduce file size quickly.',
                    icon: Icon(Icons.compress_outlined, size: 28),
                    onTap: () => Navigator.pushNamed(context, '/compress'),
                    isCompact: compact,
                  ),
                  ItemCard(
                    title: 'Edit',
                    subtitle: 'Modify pdf file.',
                    icon: Icon(Icons.edit_note_outlined, size: 28),
                    onTap: () => Navigator.pushNamed(context, '/edit'),
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
