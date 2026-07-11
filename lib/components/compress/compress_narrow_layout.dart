import 'package:flutter/material.dart';
import 'package:pdf_tools/components/compress/compress_controls.dart';
import 'package:pdf_tools/components/compress/compress_file_info.dart';
import 'package:pdf_tools/components/compress/file_preview_navigator.dart';
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressNarrowLayout extends StatelessWidget {
  const CompressNarrowLayout({
    super.key,
    required this.documentRef,
    required this.files,
    required this.selectedIndex,
    required this.quality,
    required this.onQualityChanged,
    required this.onFileSelected,
  });

  final PdfDocumentRef documentRef;
  final List<PickedPdfInfo> files;
  final int selectedIndex;
  final int quality;
  final ValueChanged<int> onQualityChanged;
  final ValueChanged<int> onFileSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 24,
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: FilePreviewNavigator(
              documentRef: documentRef,
              selectedIndex: selectedIndex,
              totalFiles: files.length,
              onPrevious: () => onFileSelected(selectedIndex - 1),
              onNext: () => onFileSelected(selectedIndex + 1),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: CompressFileInfo(
              documentRef: documentRef,
              files: files,
              isWide: false,
            ),
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
