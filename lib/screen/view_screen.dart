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
  bool _isZoomActive = false;
  Timer? _hideTimer;

  PdfTextSearcher? _textSearcher;
  bool _isSearchVisible = false;
  final _searchController = TextEditingController();

  bool _isInteracting = false;
  bool _selectionActive = false;

  @override
  void dispose() {
    _textSearcher?.removeListener(_onSearchUpdate);
    _textSearcher?.dispose();
    _searchController.dispose();
    _hideTimer?.cancel();
    super.dispose();
  }

  void _onSearchUpdate() {
    if (mounted) setState(() {});
  }

  void _toggleUi() {
    setState(() {
      _isUiVisible = !_isUiVisible;
      if (!_isUiVisible) {
        _isZoomActive = false;
      }
    });
    if (_isUiVisible) {
      _startHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          _isUiVisible = false;
          _isZoomActive = false;
        });
      }
    });
  }

  String get filePath => p.basename(widget.documentRef.key.sourceName);

  bool get _canNavigatePages {
    final zoom = _controller?.value.zoom ?? 1.0;
    return zoom <= 1.05 && !_isInteracting && !_selectionActive;
  }

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

  double _calcFitZoom() {
    final c = _controller;
    if (c == null) return 1.0;
    final pages = c.document.pages;
    if (pageNumber < 1 || pageNumber > pages.length) return 1.0;
    final page = pages[pageNumber - 1];
    final viewport = MediaQuery.sizeOf(context);
    const margin = 8.0;
    final fitZoom = min(
      viewport.width / (page.width + margin * 2),
      viewport.height / (page.height + margin * 2),
    );
    return fitZoom > 0 ? fitZoom : 1.0;
  }

  void _goToPrevious() {
    if (!_canNavigatePages) return;
    _controller?.goToPage(pageNumber: pageNumber - 1);
  }

  void _goToNext() {
    if (!_canNavigatePages) return;
    _controller?.goToPage(pageNumber: pageNumber + 1);
  }

  void _onSliderChanged(double value) =>
      _controller?.goToPage(pageNumber: value.round());

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

  void _toggleSearch() {
    setState(() {
      _isSearchVisible = !_isSearchVisible;
      if (!_isSearchVisible) {
        _textSearcher?.resetTextSearch();
        _searchController.clear();
      }
    });
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      _textSearcher?.resetTextSearch();
      return;
    }
    _textSearcher?.startTextSearch(query, caseInsensitive: true);
  }

  void _searchNext() => _textSearcher?.goToNextMatch();
  void _searchPrev() => _textSearcher?.goToPrevMatch();

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

  Widget _searchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        // crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _toggleSearch,
          ),
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search in document',
                border: InputBorder.none,
              ),
              onSubmitted: _performSearch,
              onChanged: (value) {
                setState(() {});
                if (value.isNotEmpty) _performSearch(value);
              },
            ),
          ),
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: () {
                _searchController.clear();
                _textSearcher?.resetTextSearch();
              },
            ),
          if (_textSearcher != null)
            ListenableBuilder(
              listenable: _textSearcher!,
              builder: (context, _) {
                final matches = _textSearcher!.matches;
                if (matches.isEmpty) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    '${matches.length}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up),
            onPressed: _searchPrev,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: _searchNext,
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final maxPage = pageCount > 1 ? pageCount.toDouble() : 1.0;
    return Container(
      height: kBottomNavigationBarHeight,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          M3EFilledButton(
            onPressed: pageNumber > 1 && _canNavigatePages
                ? _goToPrevious
                : null,
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
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: M3EFilledButton(
              onPressed: pageNumber < pageCount && _canNavigatePages
                  ? _goToNext
                  : null,
              child: const Icon(Icons.arrow_forward),
            ),
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
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ValueListenableBuilder<Matrix4>(
        valueListenable: c,
        builder: (context, value, child) {
          final zoom = value.zoom;
          final fitZoom = _calcFitZoom();
          final relativePercent = ((zoom / fitZoom - 1) * 100).round();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$relativePercent%'),
              IconButton(
                onPressed: () {
                  setState(() => _isZoomActive = true);
                  final newPercent = (relativePercent + 10).clamp(-50, 200);
                  final newZoom = (newPercent / 100 + 1) * fitZoom;
                  c.setZoom(c.centerPosition, newZoom);
                  _startHideTimer();
                },
                icon: const Icon(Icons.zoom_in),
              ),
              RotatedBox(
                quarterTurns: 3,
                child: SizedBox(
                  width: 150,
                  child: Slider(
                    value: relativePercent.toDouble().clamp(-50, 200),
                    min: -50,
                    max: 200,
                    onChangeStart: (_) {
                      _hideTimer?.cancel();
                      setState(() => _isZoomActive = true);
                    },
                    onChangeEnd: (_) {
                      _startHideTimer();
                    },
                    onChanged: (newPercent) {
                      final newZoom = (newPercent / 100 + 1) * fitZoom;
                      c.setZoom(c.centerPosition, newZoom);
                    },
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _isZoomActive = true);
                  final newPercent = (relativePercent - 10).clamp(-50, 200);
                  final newZoom = (newPercent / 100 + 1) * fitZoom;
                  c.setZoom(c.centerPosition, newZoom);
                  _startHideTimer();
                },
                icon: const Icon(Icons.zoom_out),
              ),
              IconButton(
                onPressed: () {
                  setState(() => _isZoomActive = true);
                  c.setZoom(c.centerPosition, fitZoom);
                  _startHideTimer();
                },
                icon: const Icon(Icons.settings_backup_restore_outlined),
              ),
            ],
          );
        },
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
        normalizeMatrix: _readingDirection != ReadingDirection.vertical
            ? (matrix, viewSize, layout, controller) {
                if (controller == null || !controller.isReady) return matrix;
                final zoom = matrix.zoom;
                final fitZoom = _calcFitZoom();
                if (zoom <= fitZoom * 1.02) return matrix;
                final idx = pageNumber - 1;
                if (idx < 0 || idx >= layout.pageLayouts.length) return matrix;
                final pageRect = layout.pageLayouts[idx];
                final position = matrix.calcPosition(viewSize);
                final hw = viewSize.width / 2 / zoom;
                final hh = viewSize.height / 2 / zoom;
                final minX = pageRect.left + hw;
                final maxX = pageRect.right - hw;
                final minY = pageRect.top + hh;
                final maxY = pageRect.bottom - hh;
                final x = maxX >= minX
                    ? position.dx.clamp(minX, maxX)
                    : (minX + maxX) / 2;
                final y = maxY >= minY
                    ? position.dy.clamp(minY, maxY)
                    : (minY + maxY) / 2;
                return controller.calcMatrixFor(
                  Offset(x, y),
                  zoom: zoom,
                  viewSize: viewSize,
                );
              }
            : null,
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
          final canNav = _canNavigatePages;
          return [
            if (canNav)
              Positioned(
                left: 0,
                top: 0,
                width: w,
                height: size.height,
                child: PdfOverlayInteractionRegion(
                  onTap: (_) {
                    _readingDirection == ReadingDirection.horizontalRtl
                        ? _goToNext()
                        : _goToPrevious();
                    return true;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
            Positioned(
              left: w,
              top: 0,
              width: w,
              height: size.height,
              child: PdfOverlayInteractionRegion(
                onTap: (_) {
                  _toggleUi();
                  return true;
                },
                onDoubleTap: (_) {
                  final c = _controller;
                  if (c == null) return true;
                  final fitZoom = _calcFitZoom();
                  final currentPercent = ((c.value.zoom / fitZoom - 1) * 100)
                      .round();
                  if (currentPercent > 5) {
                    c.setZoom(c.centerPosition, fitZoom);
                  } else {
                    final newPercent = (currentPercent + 25).clamp(-50, 200);
                    final newZoom = (newPercent / 100 + 1) * fitZoom;
                    c.setZoom(c.centerPosition, newZoom);
                  }
                  return true;
                },
                child: const SizedBox.expand(),
              ),
            ),
            if (canNav)
              Positioned(
                right: 0,
                top: 0,
                width: w,
                height: size.height,
                child: PdfOverlayInteractionRegion(
                  onTap: (_) {
                    _readingDirection == ReadingDirection.horizontalRtl
                        ? _goToPrevious()
                        : _goToNext();
                    return true;
                  },
                  child: const SizedBox.expand(),
                ),
              ),
          ];
        },
        onInteractionStart: (details) {
          _isInteracting = true;
        },
        onInteractionEnd: (details) {
          _isInteracting = false;
          if (mounted) setState(() {});
        },
        onViewerReady: (document, controller) {
          setState(() {
            _controller = controller;
            pageCount = document.pages.length;
            if (pageNumber > pageCount) pageNumber = pageCount;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            controller.goToPage(pageNumber: pageNumber);
            _textSearcher = PdfTextSearcher(controller)
              ..addListener(_onSearchUpdate);
          });
          _startHideTimer();
        },
        onPageChanged: (page) {
          if (page != null) setState(() => pageNumber = page);
        },
        textSelectionParams: PdfTextSelectionParams(
          onTextSelectionChange: (selection) {
            final active = selection.hasSelectedText;
            if (active != _selectionActive) {
              setState(() => _selectionActive = active);
            }
          },
        ),
        pagePaintCallbacks: [
          if (_textSearcher != null) _textSearcher!.pageTextMatchPaintCallback,
        ],
        matchTextColor: Colors.black,
        activeMatchTextColor: Colors.white,
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
              opacity: _isUiVisible || _isSearchVisible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_isUiVisible && !_isSearchVisible,
                child: _isSearchVisible
                    ? _searchBar()
                    : AppBar(
                        title: Text(filePath),
                        actions: [
                          IconButton(
                            icon: const Icon(Icons.search),
                            onPressed: _toggleSearch,
                          ),
                        ],
                      ),
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
            left: 12,
            bottom: MediaQuery.of(context).size.height / 3,
            child: AnimatedOpacity(
              opacity: _isUiVisible || _isZoomActive ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_isUiVisible && !_isZoomActive,
                child: _zoomControl(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
