import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'color_matrix_utils.dart';
import 'viewer_page_layout.dart';
import 'viewer_tools_sheet.dart';

class ViewerDocument extends StatelessWidget {
  const ViewerDocument({
    super.key,
    required this.documentRef,
    required this.controller,
    required this.initialPageNumber,
    required this.pageSpacing,
    required this.backgroundColor,
    required this.readingDirection,
    required this.contentFilter,
    required this.brightness,
    required this.contrast,
    required this.saturation,
    required this.textSearcher,
    required this.viewerOverlayBuilder,
    required this.onInteractionStart,
    required this.onInteractionUpdate,
    required this.onInteractionEnd,
    required this.onDocumentChanged,
    required this.onViewerReady,
    required this.onPageChanged,
    required this.onTextSelectionChanged,
  });

  static const double _loadingPadding = 20;
  static const double _loadingGap = 14;
  static const int _matchAlpha = 112;
  static const int _activeMatchAlpha = 190;
  static const int _maxImageCacheBytes = 80 * 1024 * 1024;

  final PdfDocumentRef documentRef;
  final PdfViewerController controller;
  final int initialPageNumber;
  final double pageSpacing;
  final Color backgroundColor;
  final ReadingDirection readingDirection;
  final ViewerContentFilter contentFilter;
  final double brightness;
  final double contrast;
  final double saturation;
  final PdfTextSearcher? textSearcher;
  final PdfViewerOverlaysBuilder viewerOverlayBuilder;
  final GestureScaleStartCallback onInteractionStart;
  final GestureScaleUpdateCallback onInteractionUpdate;
  final GestureScaleEndCallback onInteractionEnd;
  final PdfViewerDocumentChangedCallback onDocumentChanged;
  final PdfViewerReadyCallback onViewerReady;
  final PdfPageChangedCallback onPageChanged;
  final PdfViewerTextSelectionChangeCallback onTextSelectionChanged;

  @override
  Widget build(BuildContext context) {
    final filter = viewerColorFilter(
      filter: contentFilter,
      brightness: brightness,
      contrast: contrast,
      saturation: saturation,
    );

    final viewer = PdfViewer(
      documentRef,
      controller: controller,
      initialPageNumber: initialPageNumber,
      params: PdfViewerParams(
        margin: pageSpacing,
        backgroundColor: backgroundColor,
        underflowAnchor: PdfPageAnchor.all,
        pageAnchor: readingDirection.isPaged
            ? PdfPageAnchor.all
            : PdfPageAnchor.top,
        layoutPages: readingDirection == ReadingDirection.vertical
            ? null
            : (pages, params) => layoutHorizontalPages(
                pages,
                params,
                readingDirection: readingDirection,
              ),
        calculateCurrentPageNumber:
            readingDirection == ReadingDirection.horizontalRtl
            ? calculateHorizontalRtlPage
            : null,
        viewerOverlayBuilder: viewerOverlayBuilder,
        onInteractionStart: onInteractionStart,
        onInteractionUpdate: onInteractionUpdate,
        onInteractionEnd: onInteractionEnd,
        onDocumentChanged: onDocumentChanged,
        onViewerReady: onViewerReady,
        onPageChanged: onPageChanged,
        textSelectionParams: PdfTextSelectionParams(
          onTextSelectionChange: onTextSelectionChanged,
        ),
        forceEnableTextSemantics: true,
        pagePaintCallbacks: [
          if (textSearcher != null) textSearcher!.pageTextMatchPaintCallback,
        ],
        matchTextColor: Theme.of(
          context,
        ).colorScheme.primary.withAlpha(_matchAlpha),
        activeMatchTextColor: Theme.of(
          context,
        ).colorScheme.primaryContainer.withAlpha(_activeMatchAlpha),
        loadingBannerBuilder: (context, bytesDownloaded, totalBytes) {
          final progress = totalBytes == null || totalBytes == 0
              ? null
              : bytesDownloaded / totalBytes;
          return Center(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(_loadingPadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(value: progress),
                    const SizedBox(height: _loadingGap),
                    const Text('Loading document\u2026'),
                  ],
                ),
              ),
            ),
          );
        },
        scrollPhysics: PdfViewerParams.getScrollPhysics(context),
        scrollHorizontallyByMouseWheel: readingDirection.isPaged,
        interactionDelegateProvider:
            const PdfViewerScrollInteractionDelegateProviderPhysics(),
        sizeDelegateProvider: const PdfViewerSizeDelegateProviderSmart(),
        maxImageBytesCachedOnMemory: _maxImageCacheBytes,
      ),
    );

    if (filter == null) return viewer;
    return ColorFiltered(colorFilter: filter, child: viewer);
  }
}
