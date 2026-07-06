import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class PageSmallPreview extends StatelessWidget {
  const PageSmallPreview({
    super.key,
    required this.documentRef,
    required this.pageNumber,
    this.isSelected = false,
  });

  final PdfDocumentRef documentRef;
  final int pageNumber;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final selected = isSelected;
    final borderColor = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outlineVariant;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: selected ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: PdfDocumentViewBuilder(
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
            return PdfPageView(
              document: document,
              pageNumber: pageNumber,
              alignment: Alignment.center,
            );
          },
        ),
      ),
    );
  }
}
