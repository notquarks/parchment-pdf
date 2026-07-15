part of '../screens/view_screen.dart';

mixin _ViewerUiState on State<ViewScreen> {
  static const double _defaultFitZoom = 1;
  static const double _doubleTapZoomMultiplier = 2;
  static const double _doubleTapResetThreshold = 1.12;
  static const double _interactionScaleThreshold = 0.01;
  static const int _chromeAutoHideSeconds = 4;
  static const int _searchDebounceMilliseconds = 280;
  static const int _tapSuppressionMilliseconds = 220;
  static const int _zoomHudMilliseconds = 900;

  PdfViewerController get _controller;
  double get _fitZoom;
  int get _pageCount;
  void _setScaleType(ScaleType value);
  Future<void> _goToPage(int page);
  Future<void> _showGoToPageDialog();

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  PdfTextSearcher? _textSearcher;
  bool _autoHideControls = true;
  bool _chromeVisible = true;
  bool _searchVisible = false;
  bool _navigationVisible = false;
  bool _isInteracting = false;
  bool _selectionActive = false;
  bool _zoomHudVisible = false;
  DateTime? _lastInteractionEnd;
  double _interactionStartZoom = _defaultFitZoom;

  Timer? _hideTimer;
  Timer? _searchDebounce;
  Timer? _zoomHudTimer;

  bool get _isTapSuppressed {
    final ended = _lastInteractionEnd;
    if (_isInteracting || _selectionActive || ended == null) {
      return _isInteracting || _selectionActive;
    }
    return DateTime.now().difference(ended) <
        const Duration(milliseconds: _tapSuppressionMilliseconds);
  }

  void _disposeViewerUiState() {
    _hideTimer?.cancel();
    _searchDebounce?.cancel();
    _zoomHudTimer?.cancel();
    _disposeTextSearcher();
    _searchController.dispose();
    _searchFocusNode.dispose();
  }

  void _disposeTextSearcher() {
    final searcher = _textSearcher;
    if (searcher == null) return;
    searcher.removeListener(_onSearchUpdate);
    searcher.dispose();
    _textSearcher = null;
  }

  void _onSearchUpdate() {
    if (mounted) setState(() {});
  }

  void _showChrome({bool restartTimer = true}) {
    _hideTimer?.cancel();
    if (!_chromeVisible && mounted) {
      setState(() => _chromeVisible = true);
    }
    if (restartTimer) _startHideTimer();
  }

  void _hideChrome() {
    if (!_autoHideControls || _searchVisible || _navigationVisible) return;
    _hideTimer?.cancel();
    if (_chromeVisible && mounted) {
      setState(() => _chromeVisible = false);
    }
  }

  void _toggleChrome() {
    if (_chromeVisible) {
      _hideChrome();
    } else {
      _showChrome();
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    if (!_autoHideControls || _searchVisible || _navigationVisible) return;
    _hideTimer = Timer(const Duration(seconds: _chromeAutoHideSeconds), () {
      if (mounted) _hideChrome();
    });
  }

  void _showZoomHud() {
    _zoomHudTimer?.cancel();
    if (!_zoomHudVisible && mounted) {
      setState(() => _zoomHudVisible = true);
    }
    _zoomHudTimer = Timer(
      const Duration(milliseconds: _zoomHudMilliseconds),
      () {
        if (mounted) setState(() => _zoomHudVisible = false);
      },
    );
  }

  void _openSearch() {
    _hideTimer?.cancel();
    setState(() {
      _searchVisible = true;
      _chromeVisible = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _searchFocusNode.requestFocus();
    });
  }

  void _closeSearch() {
    _searchFocusNode.unfocus();
    setState(() => _searchVisible = false);
    _startHideTimer();
  }

  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _textSearcher?.resetTextSearch();
    setState(() {});
  }

  void _queueSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: _searchDebounceMilliseconds),
      () => _performSearch(query),
    );
    setState(() {});
  }

  void _performSearch(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) {
      _textSearcher?.resetTextSearch();
      return;
    }
    _textSearcher?.startTextSearch(
      normalized,
      caseInsensitive: true,
      searchImmediately: true,
    );
  }

  void _searchNext() {
    _textSearcher?.goToNextMatch();
    _showChrome();
  }

  void _searchPrevious() {
    _textSearcher?.goToPrevMatch();
    _showChrome();
  }

  void _zoomIn() {
    if (!_controller.isReady) return;
    _controller.zoomUp();
    _showZoomHud();
    _showChrome();
  }

  void _zoomOut() {
    if (!_controller.isReady) return;
    _controller.zoomDown();
    _showZoomHud();
    _showChrome();
  }

  void _fitPage() {
    _setScaleType(ScaleType.fitScreen);
  }

  void _fitWidth() {
    _setScaleType(ScaleType.fitWidth);
  }

  void _actualSize() {
    _setScaleType(ScaleType.original);
  }

  Map<ShortcutActivator, VoidCallback> get _shortcutBindings {
    return {
      const SingleActivator(LogicalKeyboardKey.keyF, control: true):
          _openSearch,
      const SingleActivator(LogicalKeyboardKey.keyG, control: true):
          _showGoToPageDialog,
      const SingleActivator(LogicalKeyboardKey.equal, control: true): _zoomIn,
      const SingleActivator(
        LogicalKeyboardKey.equal,
        control: true,
        shift: true,
      ): _zoomIn,
      const SingleActivator(LogicalKeyboardKey.numpadAdd, control: true):
          _zoomIn,
      const SingleActivator(LogicalKeyboardKey.minus, control: true): _zoomOut,
      const SingleActivator(LogicalKeyboardKey.numpadSubtract, control: true):
          _zoomOut,
      const SingleActivator(LogicalKeyboardKey.digit0, control: true): _fitPage,
      const SingleActivator(LogicalKeyboardKey.digit1, control: true):
          _actualSize,
      const SingleActivator(LogicalKeyboardKey.digit2, control: true):
          _fitWidth,
      const SingleActivator(LogicalKeyboardKey.home, control: true): () {
        _goToPage(1);
      },
      const SingleActivator(LogicalKeyboardKey.end, control: true): () {
        _goToPage(_pageCount);
      },
      const SingleActivator(LogicalKeyboardKey.escape): _handleEscape,
    };
  }

  void _handleBackRequest() {
    if (_searchVisible) {
      _closeSearch();
      return;
    }
    if (_navigationVisible) {
      setState(() => _navigationVisible = false);
      _startHideTimer();
      return;
    }
    Navigator.maybePop(context);
  }

  void _handleEscape() {
    if (_searchVisible) {
      _closeSearch();
      return;
    }
    if (_navigationVisible) {
      setState(() => _navigationVisible = false);
      _startHideTimer();
      return;
    }
    if (_chromeVisible) {
      _hideChrome();
      return;
    }
    Navigator.maybePop(context);
  }

  void _handleInteractionStart(ScaleStartDetails details) {
    _isInteracting = true;
    _interactionStartZoom = _controller.isReady
        ? _controller.currentZoom
        : _defaultFitZoom;
    _hideTimer?.cancel();
  }

  void _handleInteractionUpdate(ScaleUpdateDetails details) {
    if ((details.scale - 1).abs() > _interactionScaleThreshold ||
        (_controller.isReady &&
            (_controller.currentZoom - _interactionStartZoom).abs() >
                _interactionScaleThreshold)) {
      _showZoomHud();
    }
  }

  void _handleInteractionEnd(ScaleEndDetails details) {
    _isInteracting = false;
    _lastInteractionEnd = DateTime.now();
    if (mounted) setState(() {});
    _startHideTimer();
  }

  bool _handleDoubleTap(Offset localPosition) {
    if (_isTapSuppressed || !_controller.isReady) return true;
    final fitZoom = _fitZoom;
    final relativeZoom = _controller.currentZoom / fitZoom;
    final targetZoom = relativeZoom > _doubleTapResetThreshold
        ? fitZoom
        : min(_controller.maxScale, fitZoom * _doubleTapZoomMultiplier);
    _controller.zoomOnLocalPosition(
      localPosition: localPosition,
      newZoom: targetZoom,
    );
    _showZoomHud();
    return true;
  }
}
