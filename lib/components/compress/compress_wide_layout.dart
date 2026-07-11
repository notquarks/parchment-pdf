import 'package:flutter/material.dart';
import 'package:pdf_tools/components/compress/compress_controls.dart';
import 'package:pdf_tools/components/compress/compress_file_info.dart';
import 'package:pdf_tools/components/compress/compress_inline_actions.dart';
import 'package:pdf_tools/components/compress/file_preview_navigator.dart';
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressWideLayout extends StatelessWidget {
  const CompressWideLayout({
    super.key,
    required this.documentRef,
    required this.files,
    required this.selectedIndex,
    required this.quality,
    required this.onQualityChanged,
    required this.onAddFile,
    required this.onCompress,
    required this.onFileSelected,
  });

  final PdfDocumentRef documentRef;
  final List<PickedPdfInfo> files;
  final int selectedIndex;
  final int quality;
  final ValueChanged<int> onQualityChanged;
  final VoidCallback onAddFile;
  final VoidCallback onCompress;
  final ValueChanged<int> onFileSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilePreviewNavigator(
                  documentRef: documentRef,
                  selectedIndex: selectedIndex,
                  totalFiles: files.length,
                  onPrevious: () => onFileSelected(selectedIndex - 1),
                  onNext: () => onFileSelected(selectedIndex + 1),
                  compact: true,
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CompressFileInfo(
                  documentRef: documentRef,
                  files: files,
                  isWide: true,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CompressControls(
                        quality: quality,
                        onQualityChanged: onQualityChanged,
                      ),
                      const Spacer(),
                      CompressInlineActions(
                        onAddFile: onAddFile,
                        onCompress: onCompress,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
