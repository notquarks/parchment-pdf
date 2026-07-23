import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_tools/features/imgtopdf/presentation/widgets/imgtopdf_empty_state.dart';

class ImgToPdfScreen extends StatefulWidget {
  const ImgToPdfScreen({super.key});

  @override
  State<ImgToPdfScreen> createState() => _ImgToPdfScreenState();
}

class _ImgToPdfScreenState extends State<ImgToPdfScreen> {
  final List<File?> _filePicked = <File>[];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Image to PDF')),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text("Image to PDF"),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          if (_filePicked.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Image to PDF feature is under development.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            )
          else
            SliverFillRemaining(
              hasScrollBody: false,
              child: ImgToPdfEmptyState(onPickFile: () {}),
            ),
        ],
      ),
    );
  }
}
