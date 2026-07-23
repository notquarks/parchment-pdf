import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_tools/core/widgets/pdf_tool_empty_state.dart';

class ImgToPdfEmptyState extends StatelessWidget {
  const ImgToPdfEmptyState({super.key, required this.onPickFile});

  final VoidCallback onPickFile;

  @override
  Widget build(BuildContext context) {
    return PdfToolEmptyState(
      icon: Symbols.picture_as_pdf,
      title: 'Convert Images to PDF',
      description: 'Choose images and convert them to a PDF file.',
      actionIcon: Icons.upload_file,
      actionLabel: 'Choose Images',
      onAction: onPickFile,
    );
  }
}
