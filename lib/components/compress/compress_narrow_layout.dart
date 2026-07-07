import 'package:flutter/material.dart';
import 'package:pdf_tools/components/compress/compress_controls.dart';
import 'package:pdf_tools/components/compress/compress_file_info.dart';
import 'package:pdf_tools/components/compress/compress_preview_card.dart';
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressNarrowLayout extends StatelessWidget {
  const CompressNarrowLayout({
    super.key,
    required this.documentRef,
    required this.files,
    required this.quality,
    required this.onQualityChanged,
  });

  final PdfDocumentRef documentRef;
  final List<PickedPdfInfo> files;
  final int quality;
  final ValueChanged<int> onQualityChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 24,
        children: [
          CompressPreviewCard(documentRef: documentRef),
          CompressFileInfo(
            documentRef: documentRef,
            files: files,
            isWide: false,
          ),
          CompressControls(
            quality: quality,
            onQualityChanged: onQualityChanged,
          ),
        ],
      ),
    );
  }
}
