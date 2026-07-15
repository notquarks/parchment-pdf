import 'package:flutter/material.dart';
import 'package:pdf_tools/core/widgets/pdf_tool_empty_state.dart';

class SplitEmptyState extends StatelessWidget {
  const SplitEmptyState({super.key, required this.onPickFile});

  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return PdfToolEmptyState(
      icon: Icons.content_cut,
      title: 'Split PDF pages',
      description:
          'Choose a PDF, select the pages you need, and split them into separate files.',
      actionIcon: Icons.upload_file,
      actionLabel: 'Choose PDF',
      onAction: onPickFile,
    );
  }
}
