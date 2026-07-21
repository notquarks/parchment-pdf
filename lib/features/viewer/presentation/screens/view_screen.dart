import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdf_tools/features/viewer/data/models/viewer_settings.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';

import '../widgets/viewer_chrome.dart';
import '../widgets/viewer_dialogs.dart';
import '../widgets/viewer_document.dart';
import '../widgets/viewer_navigation_panel.dart';
import '../widgets/viewer_overlays.dart';
import '../widgets/viewer_presenters.dart';
import '../widgets/viewer_scaffold.dart';

part '../logic/viewer_ui_state.dart';

class ViewScreen extends StatefulWidget {
  const ViewScreen({super.key, required this.documentRef});

  final PdfDocumentRef documentRef;

  @override
  State<ViewScreen> createState() => _ViewScreenState();
}

class _ViewScreenState extends State<ViewScreen> with _ViewerUiState {
  static const double _expandedBreakpoint = 960;
  static const double _defaultPageSpacing = 8;
  static const double _defaultBrightness = 0;
  static const double _defaultContrast = 1;
  static const double _defaultSaturation = 1;
  static const double _navigationZoomTolerance = 1.08;
  static const Color _grayBackground = Color(0xFF292929);
  static const Color _sepiaBackground = Color(0xFFF5E6C5);
  static const double _minimumFitZoom = 0.01;
  static const double _defaultFitZoom = 1;
  static const double _actualSizeZoom = 1;

  @override
  final PdfViewerController _controller = PdfViewerController();

  PdfDocument? _document;
  List<PdfOutlineNode> _outline = const [];
  int _pageNumber = 1;
  @override
  int _pageCount = 0;

  ReadingDirection _readingDirection = ReadingDirection.vertical;
  BackgroundTheme _backgroundTheme = BackgroundTheme.dark;
  ScaleType _scaleType = ScaleType.smart;
  ViewerContentFilter _contentFilter = ViewerContentFilter.original;
  TapZoneMode _tapZoneMode = TapZoneMode.pagedOnly;
  double _brightness = _defaultBrightness;
  double _contrast = _defaultContrast;
  double _saturation = _defaultSaturation;
  double _pageSpacing = _defaultPageSpacing;
  bool _showPageIndicator = true;

  ViewerNavigationTab _navigationTab = ViewerNavigationTab.thumbnails;
  bool _settingsLoaded = false;

  SettingsService get _settings => SettingsProvider.of(context).settingsService;

  String get _fileName => p.basename(widget.documentRef.key.sourceName);

  bool get _tapZonesEnabled {
    return switch (_tapZoneMode) {
      TapZoneMode.off => false,
      TapZoneMode.always => true,
      TapZoneMode.pagedOnly => _readingDirection.isPaged,
    };
  }

  bool get _canNavigatePages {
    if (!_controller.isReady || _isInteracting || _selectionActive) {
      return false;
    }
    final fitZoom = _fitZoom;
    if (fitZoom <= 0) return false;
    return _controller.currentZoom / fitZoom <= _navigationZoomTolerance;
  }

  @override
  double get _fitZoom {
    if (!_controller.isReady) return _defaultFitZoom;
    final alternative = _controller.alternativeFitScale;
    if (alternative != null && alternative > _minimumFitZoom) {
      return alternative;
    }
    final pages = _document?.pages;
    if (pages == null || _pageNumber < 1 || _pageNumber > pages.length) {
      return _defaultFitZoom;
    }
    final page = pages[_pageNumber - 1];
    final viewSize = _controller.viewSize;
    final availableWidth = max(
      _minimumFitZoom,
      viewSize.width - _pageSpacing * 2,
    );
    final availableHeight = max(
      _minimumFitZoom,
      viewSize.height - _pageSpacing * 2,
    );
    return min(availableWidth / page.width, availableHeight / page.height);
  }

  Color get _viewerBackground {
    return switch (_backgroundTheme) {
      BackgroundTheme.light => Colors.white,
      BackgroundTheme.gray => _grayBackground,
      BackgroundTheme.dark => Colors.black,
      BackgroundTheme.sepia => _sepiaBackground,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final s = _settings;
    final results = await Future.wait([
      s.getReadingDirection(),
      s.getBackgroundTheme(),
      s.getScaleType(),
      s.getTapZoneMode(),
      s.getViewerContentFilter(),
    ]);
    if (!mounted) return;
    setState(() {
      _readingDirection = results[0] as ReadingDirection;
      _backgroundTheme = results[1] as BackgroundTheme;
      _scaleType = results[2] as ScaleType;
      _tapZoneMode = results[3] as TapZoneMode;
      _contentFilter = results[4] as ViewerContentFilter;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _applyScaleType();
    });
  }

  @override
  void dispose() {
    _disposeViewerUiState();
    super.dispose();
  }

  @override
  Future<void> _goToPage(int page) async {
    if (!_controller.isReady || _pageCount == 0) return;
    final safePage = max(1, min(page, _pageCount));
    await _controller.goToPage(pageNumber: safePage);
    _showChrome();
  }

  void _goToPrevious() {
    if (!_canNavigatePages || _pageNumber <= 1) return;
    _goToPage(_pageNumber - 1);
  }

  void _goToNext() {
    if (!_canNavigatePages || _pageNumber >= _pageCount) return;
    _goToPage(_pageNumber + 1);
  }

  @override
  Future<void> _showGoToPageDialog() async {
    if (_pageCount == 0) return;
    final selectedPage = await showGoToPageDialog(
      context: context,
      pageNumber: _pageNumber,
      pageCount: _pageCount,
    );
    if (selectedPage != null) await _goToPage(selectedPage);
  }

  Future<void> _openNavigation(ViewerNavigationTab tab) async {
    final expanded = MediaQuery.sizeOf(context).width >= _expandedBreakpoint;
    if (expanded) {
      setState(() {
        _navigationVisible = true;
        _navigationTab = tab;
        _chromeVisible = true;
      });
      _hideTimer?.cancel();
      return;
    }

    _hideTimer?.cancel();
    await showViewerNavigationSheet(
      context: context,
      document: _document,
      pageCount: _pageCount,
      pageNumber: _pageNumber,
      outline: _outline,
      textSearcher: _textSearcher,
      searchQuery: _searchController.text,
      initialTab: tab,
      onPageSelected: _goToPage,
      onOutlineSelected: _controller.goToDest,
      onSearchResultSelected: (index) => _textSearcher?.goToMatchOfIndex(index),
    );
    _startHideTimer();
  }

  Future<void> _showTools() async {
    final expanded = MediaQuery.sizeOf(context).width >= _expandedBreakpoint;
    _hideTimer?.cancel();

    await showViewerTools(
      context: context,
      expanded: expanded,
      readingDirection: _readingDirection,
      backgroundTheme: _backgroundTheme,
      scaleType: _scaleType,
      contentFilter: _contentFilter,
      tapZoneMode: _tapZoneMode,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      pageSpacing: _pageSpacing,
      showPageIndicator: _showPageIndicator,
      autoHideControls: _autoHideControls,
      onReadingDirectionChanged: _changeReadingDirection,
      onBackgroundThemeChanged: (value) {
        setState(() => _backgroundTheme = value);
        _settings.setBackgroundTheme(value);
      },
      onScaleTypeChanged: (value) {
        setState(() => _scaleType = value);
        _applyScaleType();
        _settings.setScaleType(value);
      },
      onContentFilterChanged: (value) {
        setState(() => _contentFilter = value);
        _settings.setViewerContentFilter(value);
      },
      onTapZoneModeChanged: (value) {
        setState(() => _tapZoneMode = value);
        _settings.setTapZoneMode(value);
      },
      onBrightnessChanged: (value) {
        setState(() => _brightness = value);
      },
      onContrastChanged: (value) {
        setState(() => _contrast = value);
      },
      onSaturationChanged: (value) {
        setState(() => _saturation = value);
      },
      onPageSpacingChanged: _changePageSpacing,
      onShowPageIndicatorChanged: (value) {
        setState(() => _showPageIndicator = value);
      },
      onAutoHideControlsChanged: (value) {
        setState(() {
          _autoHideControls = value;
          if (!value) _chromeVisible = true;
        });
        if (value) _startHideTimer();
      },
      onResetAppearance: () {
        setState(() {
          _backgroundTheme = BackgroundTheme.dark;
          _contentFilter = ViewerContentFilter.original;
          _brightness = _defaultBrightness;
          _contrast = _defaultContrast;
          _saturation = _defaultSaturation;
        });
        _settings.setBackgroundTheme(BackgroundTheme.dark);
        _settings.setViewerContentFilter(ViewerContentFilter.original);
      },
    );
    _startHideTimer();
  }

  void _changeReadingDirection(ReadingDirection direction) {
    final currentPage = _pageNumber;
    setState(() => _readingDirection = direction);
    _settings.setReadingDirection(direction);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_controller.isReady) return;
      _controller.invalidate();
      await _controller.goToPage(pageNumber: currentPage);
      await _applyScaleType();
    });
  }

  void _changePageSpacing(double spacing) {
    final currentPage = _pageNumber;
    setState(() => _pageSpacing = spacing);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!_controller.isReady) return;
      _controller.invalidate();
      await _controller.goToPage(pageNumber: currentPage);
    });
  }

  Future<void> _applyScaleType() async {
    if (!_controller.isReady || _pageCount == 0) return;
    final page = max(1, min(_pageNumber, _pageCount));

    switch (_scaleType) {
      case ScaleType.smart:
        final pages = _document?.pages;
        if (pages == null || page > pages.length) return;
        final currentPage = pages[page - 1];
        final pageRatio = currentPage.width / currentPage.height;
        final viewRatio =
            _controller.viewSize.width / _controller.viewSize.height;
        final matrix = pageRatio < viewRatio
            ? _controller.calcMatrixFitWidthForPage(pageNumber: page)
            : _controller.calcMatrixForFit(pageNumber: page);
        await _controller.goTo(matrix);
      case ScaleType.fitScreen:
        await _controller.goTo(_controller.calcMatrixForFit(pageNumber: page));
      case ScaleType.fitWidth:
        await _controller.goTo(
          _controller.calcMatrixFitWidthForPage(pageNumber: page),
        );
      case ScaleType.fitHeight:
        await _controller.goTo(
          _controller.calcMatrixFitHeightForPage(pageNumber: page),
        );
      case ScaleType.original:
        await _controller.goToPage(pageNumber: page);
        await _controller.setZoom(_controller.centerPosition, _actualSizeZoom);
    }
    _showZoomHud();
  }

  @override
  void _setScaleType(ScaleType value) {
    setState(() => _scaleType = value);
    _applyScaleType();
  }

  List<Widget> _buildViewerOverlays(
    BuildContext context,
    Size size,
    bool Function(Offset localPosition) handleLinkTap,
  ) {
    return buildViewerOverlays(
      size: size,
      controller: _controller,
      readingDirection: _readingDirection,
      canNavigate: _tapZonesEnabled && _canNavigatePages,
      isTapSuppressed: () => _isTapSuppressed,
      onPrevious: _goToPrevious,
      onNext: _goToNext,
      onToggleChrome: _toggleChrome,
      onDoubleTap: _handleDoubleTap,
    );
  }

  Widget _buildViewer() {
    return ViewerDocument(
      documentRef: widget.documentRef,
      controller: _controller,
      initialPageNumber: _pageNumber,
      pageSpacing: _pageSpacing,
      backgroundColor: _viewerBackground,
      readingDirection: _readingDirection,
      contentFilter: _contentFilter,
      brightness: _brightness,
      contrast: _contrast,
      saturation: _saturation,
      textSearcher: _textSearcher,
      viewerOverlayBuilder: _buildViewerOverlays,
      onInteractionStart: _handleInteractionStart,
      onInteractionUpdate: _handleInteractionUpdate,
      onInteractionEnd: _handleInteractionEnd,
      onDocumentChanged: _handleDocumentChanged,
      onViewerReady: _handleViewerReady,
      onPageChanged: _handlePageChanged,
      onTextSelectionChanged: _handleTextSelectionChanged,
    );
  }

  void _handleDocumentChanged(PdfDocument? document) {
    if (document != null) return;
    _disposeTextSearcher();
    if (!mounted) return;
    setState(() {
      _document = null;
      _outline = const [];
      _pageCount = 0;
    });
  }

  Future<void> _handleViewerReady(
    PdfDocument document,
    PdfViewerController controller,
  ) async {
    _disposeTextSearcher();
    final searcher = PdfTextSearcher(controller)..addListener(_onSearchUpdate);
    final pageCount = document.pages.length;
    final pageNumber = pageCount == 0 ? 1 : max(1, min(_pageNumber, pageCount));

    if (!mounted) {
      searcher.removeListener(_onSearchUpdate);
      searcher.dispose();
      return;
    }

    setState(() {
      _document = document;
      _textSearcher = searcher;
      _outline = const [];
      _pageCount = pageCount;
      _pageNumber = pageNumber;
    });
    controller.requestFocus();

    if (pageCount > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !controller.isReady) return;
        await controller.goToPage(pageNumber: pageNumber);
        await _applyScaleType();
      });
    }

    try {
      final outline = await document.loadOutline();
      if (mounted && identical(_document, document)) {
        setState(() => _outline = outline);
      }
    } catch (_) {}

    _startHideTimer();
  }

  void _handlePageChanged(int? page) {
    if (page == null || page == _pageNumber) return;
    setState(() => _pageNumber = page);
  }

  void _handleTextSelectionChanged(PdfTextSelection selection) {
    final active = selection.hasSelectedText;
    if (active == _selectionActive) return;
    setState(() => _selectionActive = active);
    if (active) {
      _hideTimer?.cancel();
      _showChrome(restartTimer: false);
    } else {
      _startHideTimer();
    }
  }

  Widget _buildViewerArea({required bool compact, required bool expanded}) {
    return ViewerChrome(
      viewer: _buildViewer(),
      fileName: _fileName,
      controller: _controller,
      fitZoom: _fitZoom,
      pageNumber: _pageNumber,
      pageCount: _pageCount,
      canNavigate: _canNavigatePages,
      compact: compact,
      expanded: expanded,
      chromeVisible: _chromeVisible,
      searchVisible: _searchVisible,
      showPageIndicator: _showPageIndicator,
      zoomHudVisible: _zoomHudVisible,
      searchController: _searchController,
      searchFocusNode: _searchFocusNode,
      textSearcher: _textSearcher,
      onBack: _handleBackRequest,
      onOpenSearch: _openSearch,
      onCloseSearch: _closeSearch,
      onSearchChanged: _queueSearch,
      onSearchSubmitted: (query) {
        _searchDebounce?.cancel();
        _performSearch(query);
      },
      onSearchNext: _searchNext,
      onSearchPrevious: _searchPrevious,
      onClearSearch: _clearSearch,
      onShowSearchResults: () => _openNavigation(ViewerNavigationTab.search),
      onPrevious: _goToPrevious,
      onNext: _goToNext,
      onPageSelected: _goToPage,
      onPageLabelPressed: _showGoToPageDialog,
      onShowNavigation: () => _openNavigation(ViewerNavigationTab.thumbnails),
      onShowTools: _showTools,
      onZoomInteraction: () {
        _showZoomHud();
        _showChrome();
      },
      onPointerActivity: _showChrome,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ViewerScaffold(
      backgroundColor: _viewerBackground,
      searchVisible: _searchVisible,
      navigationVisible: _navigationVisible,
      navigationTab: _navigationTab,
      document: _document,
      pageCount: _pageCount,
      pageNumber: _pageNumber,
      outline: _outline,
      textSearcher: _textSearcher,
      searchQuery: _searchController.text,
      shortcutBindings: _shortcutBindings,
      onBackRequest: _handleBackRequest,
      onCloseNavigation: () {
        setState(() => _navigationVisible = false);
        _startHideTimer();
      },
      onPageSelected: _goToPage,
      onOutlineSelected: _controller.goToDest,
      onSearchResultSelected: (index) => _textSearcher?.goToMatchOfIndex(index),
      viewerBuilder: (compact, expanded) =>
          _buildViewerArea(compact: compact, expanded: expanded),
    );
  }
}
