import 'package:flutter/material.dart';
import 'package:pdf_tools/components/loading_spinner.dart';
import 'package:pdf_tools/components/preview_shortcut.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressPreviewCard extends StatelessWidget {
  const CompressPreviewCard({super.key, required this.documentRef});

  final PdfDocumentRef documentRef;

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    return PdfDocumentViewBuilder(
      documentRef: documentRef,
      builder: (context, document) {
        if (document == null) {
          return Card(
            child: SizedBox(
              width: shortest * 0.6,
              child: AspectRatio(
                aspectRatio: 0.65,
                child: Center(child: LoadingSpinner(size: 0.4)),
              ),
            ),
          );
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: PreviewShortcut(
            documentRef: documentRef,
            child: SizedBox(
              width: MediaQuery.of(context).size.shortestSide * 0.6,
              child: AspectRatio(
                aspectRatio: 0.65,
                child: PdfPageView(
                  document: document,
                  pageNumber: 1,
                  alignment: Alignment.center,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
