import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/core/utils/string_utils.dart';
import 'package:pdf_tools/features/compression/data/models/compression_options.dart';
import 'package:pdf_tools/features/home/presentation/widgets/preview_shortcut.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressPreviewCard extends StatelessWidget {
  const CompressPreviewCard({
    super.key,
    required this.documentRef,
    required this.file,
    this.estimate,
    this.isEstimating = false,
    required this.layout,
  });

  static const double _compactMaximumHeight = 360;
  static const double _mediumMaximumHeight = 520;
  static const double _minimumPreviewHeight = 240;
  static const double _cardPadding = 16;
  static const double _metadataSpacing = 12;
  static const double _pageAspectRatio = 0.707;

  final PdfDocumentRef documentRef;
  final PickedPdfInfo file;
  final CompressionEstimate? estimate;
  final bool isEstimating;
  final CompressPreviewLayout layout;

  double get _maximumHeight {
    return switch (layout) {
      CompressPreviewLayout.compact => _compactMaximumHeight,
      CompressPreviewLayout.medium => _mediumMaximumHeight,
      CompressPreviewLayout.expanded => double.infinity,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(_cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.basename(file.file.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      _buildFileMetadata(context),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: _metadataSpacing),
            if (layout == CompressPreviewLayout.expanded)
              Expanded(child: _PreviewSurface(documentRef: documentRef))
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: _minimumPreviewHeight,
                  maxHeight: _maximumHeight,
                ),
                child: _PreviewSurface(documentRef: documentRef),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileMetadata(BuildContext context) {
    final pageCount = file.pageCount;
    final pageLabel = pageCount == null
        ? 'Reading pages…'
        : '$pageCount ${pageCount == 1 ? 'page' : 'pages'}';
    final style = Theme.of(context).textTheme.bodySmall;
    final original = formatBytes(file.sizeBytes, 2);

    if (isEstimating) {
      return Text('$original → Calculating… • $pageLabel', style: style);
    }

    final currentEstimate = estimate;
    if (currentEstimate == null || !currentEstimate.hasMeaningfulReduction) {
      return Text('$original • $pageLabel', style: style);
    }

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text: original,
            style: const TextStyle(decoration: TextDecoration.lineThrough),
          ),
          TextSpan(
            text: '  →  ≈ ${formatBytes(currentEstimate.estimatedSize, 0)}'
                ' • $pageLabel',
          ),
        ],
      ),
    );
  }
}

enum CompressPreviewLayout { compact, medium, expanded }

class _PreviewSurface extends StatelessWidget {
  const _PreviewSurface({required this.documentRef});

  static const double _surfaceRadius = 16;
  static const double _pageMaximumWidth = 540;

  final PdfDocumentRef documentRef;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(_surfaceRadius),
      ),
      child: PdfDocumentViewBuilder(
        documentRef: documentRef,
        builder: (context, document) {
          if (document == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return PreviewShortcut(
            documentRef: documentRef,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _pageMaximumWidth),
                child: AspectRatio(
                  aspectRatio: CompressPreviewCard._pageAspectRatio,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Material(
                      elevation: 2,
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(4),
                      child: PdfPageView(
                        document: document,
                        pageNumber: 1,
                        alignment: Alignment.center,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
