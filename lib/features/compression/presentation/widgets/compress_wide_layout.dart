import 'package:flutter/material.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_controls.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_file_info.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_inline_actions.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_preview_card.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/file_preview_navigator.dart';
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
    if (files.isEmpty || selectedIndex < 0 || selectedIndex >= files.length) {
      return const SizedBox.shrink();
    }

    final selectedFile = files[selectedIndex];

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          Expanded(
            child: FilePreviewNavigator(
              documentRef: documentRef,
              file: selectedFile,
              selectedIndex: selectedIndex,
              totalFiles: files.length,
              onPrevious: () => onFileSelected(selectedIndex - 1),
              onNext: () => onFileSelected(selectedIndex + 1),
              layout: CompressPreviewLayout.expanded,
              compact: true,
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
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
