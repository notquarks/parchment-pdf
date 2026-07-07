import 'package:flutter/material.dart';
import 'package:pdf_tools/components/compress/compress_controls.dart';
import 'package:pdf_tools/components/compress/compress_file_info.dart';
import 'package:pdf_tools/components/compress/compress_inline_actions.dart';
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressWideLayout extends StatelessWidget {
  const CompressWideLayout({
    super.key,
    required this.documentRef,
    required this.files,
    required this.quality,
    required this.onQualityChanged,
    required this.onAddFile,
    required this.onCompress,
  });

  final PdfDocumentRef documentRef;
  final List<PickedPdfInfo> files;
  final int quality;
  final ValueChanged<int> onQualityChanged;
  final VoidCallback onAddFile;
  final VoidCallback onCompress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisSize: .max,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: PdfDocumentViewBuilder(
                documentRef: documentRef,
                builder: (context, document) {
                  if (document == null) {
                    return Center(
                      child: Icon(
                        Icons.description_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    );
                  }
                  return AspectRatio(
                    aspectRatio: 0.65,
                    child: PdfPageView(
                      document: document,
                      pageNumber: 1,
                      alignment: Alignment.center,
                    ),
                  );
                },
              ),
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
