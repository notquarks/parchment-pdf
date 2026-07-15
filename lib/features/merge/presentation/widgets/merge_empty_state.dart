import 'package:flutter/material.dart';
import 'package:pdf_tools/core/widgets/pdf_tool_empty_state.dart';

class MergeEmptyState extends StatelessWidget {
  const MergeEmptyState({super.key, required this.onPickFiles});

  final VoidCallback onPickFiles;

  @override
  Widget build(BuildContext context) {
    return PdfToolEmptyState(
      icon: Icons.merge,
      title: 'Merge PDF files',
      description:
          'Choose multiple PDFs, arrange their order, and merge them into a single file.',
      actionIcon: Icons.playlist_add,
      actionLabel: 'Choose PDF files',
      onAction: onPickFiles,
    );
  }
}
