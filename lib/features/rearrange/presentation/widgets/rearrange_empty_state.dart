import 'package:flutter/material.dart';
import 'package:pdf_tools/core/widgets/pdf_tool_empty_state.dart';

class RearrangeEmptyState extends StatelessWidget {
  const RearrangeEmptyState({super.key, required this.onPickFile});

  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return PdfToolEmptyState(
      icon: Icons.low_priority,
      title: 'Rearrange PDF pages',
      description: 'Choose a PDF, then drag its pages into the order you need.',
      actionIcon: Icons.upload_file,
      actionLabel: 'Choose PDF',
      onAction: onPickFile,
    );
  }
}
