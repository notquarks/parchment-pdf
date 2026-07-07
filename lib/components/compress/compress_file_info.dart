import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdf_tools/util/string_util.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressFileInfo extends StatelessWidget {
  const CompressFileInfo({
    super.key,
    required this.documentRef,
    required this.files,
    required this.isWide,
  });

  final PdfDocumentRef documentRef;
  final List<PickedPdfInfo> files;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    return PdfDocumentViewBuilder(
      documentRef: documentRef,
      builder: (context, document) {
        if (document == null) return const SizedBox.shrink();
        final file = _currentFile(document.sourceName);
        final name = Text(
          p.basename(document.sourceName),
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isWide ? TextAlign.start : TextAlign.center,
        );
        final chip = (file != null)
            ? Chip(
                shape: const StadiumBorder(),
                label: Text(
                  '${formatBytes(file.sizeBytes, 2)} • ${document.pages.length} pages',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : null;
        if (isWide && chip != null) {
          return Row(
            spacing: 12,
            children: [
              Expanded(child: name),
              chip,
            ],
          );
        }
        return Column(children: [name, ?chip]);
      },
    );
  }

  PickedPdfInfo? _currentFile(String? sourceName) {
    if (files.isEmpty) return null;
    return files.firstWhere(
      (f) => f.file.path == sourceName,
      orElse: () => files.first,
    );
  }
}
