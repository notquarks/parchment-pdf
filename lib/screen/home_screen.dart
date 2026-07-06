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
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 200,
              childAspectRatio: 1,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
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
