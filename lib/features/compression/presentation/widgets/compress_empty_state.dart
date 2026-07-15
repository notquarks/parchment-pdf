import 'package:flutter/material.dart';
import 'package:pdf_tools/core/widgets/pdf_tool_empty_state.dart';

class CompressEmptyState extends StatelessWidget {
  const CompressEmptyState({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return PdfToolEmptyState(
      icon: Icons.picture_as_pdf_outlined,
      title: 'Compress PDF files',
      description:
          'Choose one or more PDFs, select a compression level, and save smaller copies without changing the originals.',
      actionIcon: Icons.add,
      actionLabel: 'Choose PDF files',
      onAction: onPick,
    );
  }
}
