import 'package:flutter/material.dart';
import 'package:pdf_tools/features/viewer/presentation/screens/view_screen.dart';
import 'package:pdfrx/pdfrx.dart';

class PreviewShortcut extends StatelessWidget {
  const PreviewShortcut({
    super.key,
    required this.documentRef,
    required this.child,
  });

  final Widget child;
  final PdfDocumentRef documentRef;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ViewScreen(documentRef: documentRef),
        ),
      ),
      child: Stack(
        children: [
          child,
          Positioned(
            top: 8,
            right: 12,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.zoom_out_map,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
