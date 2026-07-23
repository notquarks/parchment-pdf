import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_tools/core/widgets/pdf_tool_empty_state.dart';

class TrimEmptyState extends StatelessWidget {
  const TrimEmptyState({super.key, required this.onPickFile});

  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return PdfToolEmptyState(
      icon: Symbols.scan_delete,
      title: 'Trim PDF pages',
      description: 'Choose a PDF and select the pages you want to delete.',
      actionIcon: Icons.upload_file,
      actionLabel: 'Choose PDF',
      onAction: onPickFile,
    );
  }
}
