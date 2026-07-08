import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../components/viewer/color_matrix_utils.dart';
import '../components/viewer/viewer_tools_sheet.dart';

class ViewScreen extends StatefulWidget {
  const ViewScreen({super.key, required this.documentRef});
  final PdfDocumentRef documentRef;

  @override
  State<ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<ViewScreen> {
  int pageNumber = 1;
  int pageCount = 0;
  PdfViewerController? _controller;

  ReadingDirection _readingDirection = ReadingDirection.vertical;
  bool _grayscale = false;
  double _brightness = 0.0;
  BackgroundTheme _backgroundTheme = BackgroundTheme.dark;
  ScaleType _scaleType = ScaleType.fitScreen;
  bool _cropBorders = false;
  bool _isUiVisible = true;
  Timer? _hideTimer;

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  void _toggleUi() {
    setState(() => _isUiVisible = !_isUiVisible);
    if (_isUiVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _isUiVisible = false);
    });
  }

  String get filePath => p.basename(widget.documentRef.key.sourceName);

  Color get _backgroundColor {
    switch (_backgroundTheme) {
      case BackgroundTheme.light:
        return Colors.white;
      case BackgroundTheme.dark:
        return Colors.black;
      case BackgroundTheme.sepia:
        return const Color(0xFFF5E6C8);
    }
  }

  Widget _applyColorFilters(Widget child) {
    final hasFilter = _grayscale || _brightness != 0.0;
    if (!hasFilter) return child;
    var result = child;
    if (_grayscale) {
      result = ColorFiltered(colorFilter: grayscaleFilter(), child: result);
    }
    if (_brightness != 0.0) {
      result = ColorFiltered(
        colorFilter: brightnessFilter(_brightness),
        child: result,
      );
    }
    return result;
  }

  void _goToPrevious() => _controller?.goToPage(pageNumber: pageNumber - 1);
  void _goToNext() => _controller?.goToPage(pageNumber: pageNumber + 1);
  void _onSliderChanged(double value) =>
      _controller?.goToPage(pageNumber: value.round());

  void _snapToNearestPage() {
    _controller?.goToPage(pageNumber: pageNumber);
  }

  int? _calcCurrentPage(
    Rect visibleRect,
    List<Rect> pageRects,
    PdfViewerController controller,
  ) {
    int? bestPage;
    double bestVisibility = 0;
    for (int i = 0; i < pageRects.length; i++) {
      final r = pageRects[i];
      if (r.right <= visibleRect.left || r.left >= visibleRect.right) continue;
      final vLeft = r.left > visibleRect.left ? r.left : visibleRect.left;
      final vRight = r.right < visibleRect.right ? r.right : visibleRect.right;
      final visibility = (vRight - vLeft) / r.width;
      if (visibility > bestVisibility) {
        bestVisibility = visibility;
        bestPage = i + 1;
      }
    }
    return bestPage;
  }

  void _applyScaleType() {
    final c = _controller;
    if (c == null) return;
    switch (_scaleType) {
      case ScaleType.fitScreen:
        c.goToPage(pageNumber: pageNumber, anchor: PdfPageAnchor.all);
      case ScaleType.fitWidth:
        final m = c.calcMatrixFitWidthForPage(pageNumber: pageNumber);
        c.goTo(m);
      case ScaleType.fitHeight:
        final m = c.calcMatrixFitHeightForPage(pageNumber: pageNumber);
        c.goTo(m);
      case ScaleType.original:
        c.goToPosition(documentOffset: Offset.zero, zoom: 1.0);
    }
  }

  void _showToolsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => ViewerToolsSheet(
        readingDirection: _readingDirection,
        backgroundTheme: _backgroundTheme,
        scaleType: _scaleType,
        grayscale: _grayscale,
        brightness: _brightness,
        cropBorders: _cropBorders,
        onReadingDirectionChanged: (d) {
          setState(() => _readingDirection = d);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _controller?.goToPage(pageNumber: pageNumber);
          });
        },
        onBackgroundThemeChanged: (t) => setState(() => _backgroundTheme = t),
        onScaleTypeChanged: (t) {
          setState(() => _scaleType = t);
          _applyScaleType();
        },
        onGrayscaleToggled: () => setState(() => _grayscale = !_grayscale),
        onBrightnessChanged: (b) => setState(() => _brightness = b),
        onCropBordersToggled: () =>
            setState(() => _cropBorders = !_cropBorders),
      ),
    );
  }

  Widget _bottomBar() {
    final maxPage = pageCount > 1 ? pageCount.toDouble() : 1.0;
    return Container(
      height: kBottomNavigationBarHeight,
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: .max,
        children: [
          M3EFilledButton(
            onPressed: pageNumber > 1 ? _goToPrevious : null,
            child: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(pageNumber.toString()),
                ),
                Expanded(
                  child: Slider(
                    value: pageNumber.toDouble(),
                    min: 1,
                    max: maxPage,
                    divisions: pageCount > 1 ? pageCount - 1 : null,
                    onChanged: pageCount > 1 ? _onSliderChanged : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(pageCount.toString()),
                ),
              ],
            ),
          ),
          M3EFilledButton(
            onPressed: _showToolsSheet,
            child: const Icon(Icons.tune),
          ),
          const SizedBox(width: 8),
          M3EFilledButton(
            onPressed: pageNumber < pageCount ? _goToNext : null,
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  Widget _zoomControl() {
    final c = _controller;
    if (c == null) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () { c.zoomUp(); },
          ),
          ValueListenableBuilder<Matrix4>(
            valueListenable: c,
            builder: (context, value, child) {
              return Text('${(value.zoom * 100).round()}%');
            },
          ),
          IconButton(
            icon: const Icon(Icons.remove),
            onPressed: () { c.zoomDown(); },
          ),
        ],
      ),
    );
  }

  Widget _viewer() {
    return PdfViewer(
      widget.documentRef,
      controller: _controller,
      initialPageNumber: pageNumber,
      params: PdfViewerParams(
        backgroundColor: _backgroundColor,
        layoutPages: _readingDirection == ReadingDirection.vertical
            ? null
            : (pages, params) {
                final isRtl =
                    _readingDirection == ReadingDirection.horizontalRtl;
                final height =
                    pages.fold(0.0, (prev, page) => max(prev, page.height)) +
                    params.margin * 2;
                final pageLayouts = <Rect>[];
                double x = params.margin;
                for (final page in pages) {
                  pageLayouts.add(
                    Rect.fromLTWH(
                      x,
                      (height - page.height) / 2,
                      page.width,
                      page.height,
                    ),
                  );
                  x += page.width + params.margin;
                }
                final totalWidth = x;
                if (isRtl) {
                  for (int i = 0; i < pageLayouts.length; i++) {
                    final r = pageLayouts[i];
                    pageLayouts[i] = Rect.fromLTWH(
                      totalWidth - r.left - r.width,
                      r.top,
                      r.width,
                      r.height,
                    );
                  }
                }
                return PdfPageLayout(
                  pageLayouts: pageLayouts,
                  documentSize: Size(totalWidth, height),
                );
              },
        calculateCurrentPageNumber:
            _readingDirection == ReadingDirection.horizontalRtl
            ? _calcCurrentPage
            : null,
        viewerOverlayBuilder: (context, size, handleLinkTap) {
          final w = size.width / 3;
          return [
            Positioned(
              left: 0,
              top: 0,
              width: w,
              height: size.height,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerUp: (_) => _snapToNearestPage(),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () =>
                      _readingDirection == ReadingDirection.horizontalRtl
                      ? _goToNext()
                      : _goToPrevious(),
                  child: SizedBox.expand(),
                ),
              ),
            ),
            Positioned(
              left: w,
              top: 0,
              width: w,
              height: size.height,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _toggleUi,
                child: SizedBox.expand(),
              ),
            ),
            Positioned(
              right: 0,
              top: 0,
              width: w,
              height: size.height,
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerUp: (_) => _snapToNearestPage(),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () =>
                      _readingDirection == ReadingDirection.horizontalRtl
                      ? _goToPrevious()
                      : _goToNext(),
                  child: SizedBox.expand(),
                ),
              ),
            ),
          ];
        },
        onViewerReady: (document, controller) {
          setState(() {
            _controller = controller;
            pageCount = document.pages.length;
            if (pageNumber > pageCount) pageNumber = pageCount;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.goToPage(pageNumber: pageNumber);
          });
          _startHideTimer();
        },
        onPageChanged: (page) {
          if (page != null) setState(() => pageNumber = page);
        },
        textSelectionParams: PdfTextSelectionParams(),
        maxImageBytesCachedOnMemory: 50 * 1024 * 1024,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _applyColorFilters(_viewer()),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _isUiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_isUiVisible,
                child: AppBar(title: Text(filePath)),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: AnimatedOpacity(
              opacity: _isUiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_isUiVisible,
                child: _bottomBar(),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 90,
            child: AnimatedOpacity(
              opacity: _isUiVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_isUiVisible,
                child: _zoomControl(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
