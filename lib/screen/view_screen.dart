import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ViewScreen extends StatelessWidget {
  const ViewScreen({super.key, required this.documentRef});

  final PdfDocumentRef documentRef;
  final int pageNumber = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(documentRef.key.sourceName.toString())),
      body: PdfDocumentViewBuilder(
        documentRef: documentRef,
        builder: (context, document) {
          if (document == null) {
            return Container(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              alignment: Alignment.center,
              child: Icon(
                Icons.description_outlined,
                size: 32,
                color: Theme.of(context).colorScheme.outline,
              ),
            );
          }
          return InkWell(
            child: PdfPageView(
              document: document,
              pageNumber: pageNumber,
              alignment: Alignment.center,
            ),
          );
        },
      ),
    );
  }
}
