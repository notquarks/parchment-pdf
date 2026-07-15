import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'viewer_bottom_bar.dart';
import 'viewer_search_bar.dart';
import 'viewer_zoom_control.dart';

class ViewerChrome extends StatelessWidget {
  const ViewerChrome({
    super.key,
    required this.viewer,
    required this.fileName,
    required this.controller,
    required this.fitZoom,
    required this.pageNumber,
    required this.pageCount,
    required this.canNavigate,
    required this.compact,
    required this.expanded,
    required this.chromeVisible,
    required this.searchVisible,
    required this.showPageIndicator,
    required this.zoomHudVisible,
    required this.searchController,
    required this.searchFocusNode,
    required this.textSearcher,
    required this.onBack,
    required this.onOpenSearch,
    required this.onCloseSearch,
    required this.onSearchChanged,
    required this.onSearchSubmitted,
    required this.onSearchNext,
    required this.onSearchPrevious,
    required this.onClearSearch,
    required this.onShowSearchResults,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSelected,
    required this.onPageLabelPressed,
    required this.onShowNavigation,
    required this.onShowTools,
    required this.onZoomInteraction,
    required this.onPointerActivity,
  });

  static const int _animationMilliseconds = 180;
  static const double _pageIndicatorMargin = 16;
  static const double _pageIndicatorBottomVisible = 92;
  static const double _pageIndicatorBottomHidden = 16;
  static const double _pageIndicatorRadius = 18;
  static const double _pageIndicatorHorizontalPadding = 12;
  static const double _pageIndicatorVerticalPadding = 7;

  final Widget viewer;
  final String fileName;
  final PdfViewerController controller;
  final double fitZoom;
  final int pageNumber;
  final int pageCount;
  final bool canNavigate;
  final bool compact;
  final bool expanded;
  final bool chromeVisible;
  final bool searchVisible;
  final bool showPageIndicator;
  final bool zoomHudVisible;
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final PdfTextSearcher? textSearcher;
  final VoidCallback onBack;
  final VoidCallback onOpenSearch;
  final VoidCallback onCloseSearch;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSearchSubmitted;
  final VoidCallback onSearchNext;
  final VoidCallback onSearchPrevious;
  final VoidCallback onClearSearch;
  final VoidCallback onShowSearchResults;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onPageLabelPressed;
  final VoidCallback onShowNavigation;
  final VoidCallback onShowTools;
  final VoidCallback onZoomInteraction;
  final VoidCallback onPointerActivity;

  bool get _isDesktopPlatform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.macOS ||
      TargetPlatform.linux => true,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) {
        if (_isDesktopPlatform) onPointerActivity();
      },
      onHover: (_) {
        if (_isDesktopPlatform && chromeVisible) onPointerActivity();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          viewer,
          _buildControls(context),
          _buildPageIndicator(context),
          if (controller.isReady)
            Center(
              child: ViewerZoomHud(
                controller: controller,
                fitZoom: fitZoom,
                visible: zoomHudVisible,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: AnimatedSlide(
            offset: chromeVisible || searchVisible
                ? Offset.zero
                : const Offset(0, -1),
            duration: const Duration(milliseconds: _animationMilliseconds),
            child: AnimatedOpacity(
              opacity: chromeVisible || searchVisible ? 1 : 0,
              duration: const Duration(milliseconds: _animationMilliseconds),
              child: IgnorePointer(
                ignoring: !chromeVisible && !searchVisible,
                child: _buildTopBar(),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: AnimatedSlide(
            offset: chromeVisible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: _animationMilliseconds),
            child: AnimatedOpacity(
              opacity: chromeVisible ? 1 : 0,
              duration: const Duration(milliseconds: _animationMilliseconds),
              child: IgnorePointer(
                ignoring: !chromeVisible,
                child: ViewerBottomBar(
                  pageNumber: pageNumber,
                  pageCount: pageCount,
                  canNavigate: canNavigate,
                  compact: compact,
                  showNavigationButtons: !compact,
                  onPrevious: onPrevious,
                  onNext: onNext,
                  onPageSelected: onPageSelected,
                  onPageLabelPressed: onPageLabelPressed,
                  onShowNavigation: onShowNavigation,
                  onShowTools: onShowTools,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    if (searchVisible) {
      return ViewerSearchBar(
        searchController: searchController,
        focusNode: searchFocusNode,
        textSearcher: textSearcher,
        compact: compact,
        onClose: onCloseSearch,
        onChanged: onSearchChanged,
        onSubmitted: onSearchSubmitted,
        onSearchNext: onSearchNext,
        onSearchPrev: onSearchPrevious,
        onClearSearch: onClearSearch,
        onShowResults: onShowSearchResults,
      );
    }

    return AppBar(
      leading: BackButton(onPressed: onBack),
      title: Text(fileName, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: 'Search',
          onPressed: onOpenSearch,
          icon: const Icon(Icons.search),
        ),
        if (!compact && controller.isReady)
          ViewerZoomControl(
            controller: controller,
            fitZoom: fitZoom,
            compact: !expanded,
            onInteraction: onZoomInteraction,
          ),
      ],
    );
  }

  Widget _buildPageIndicator(BuildContext context) {
    final visible =
        showPageIndicator && pageCount > 0 && !chromeVisible && !searchVisible;

    return AnimatedPositioned(
      duration: const Duration(milliseconds: _animationMilliseconds),
      right: _pageIndicatorMargin,
      bottom: chromeVisible
          ? _pageIndicatorBottomVisible
          : _pageIndicatorBottomHidden,
      child: IgnorePointer(
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: _animationMilliseconds),
          child: Material(
            color: Theme.of(context).colorScheme.inverseSurface,
            borderRadius: BorderRadius.circular(_pageIndicatorRadius),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _pageIndicatorHorizontalPadding,
                vertical: _pageIndicatorVerticalPadding,
              ),
              child: Text(
                '$pageNumber / $pageCount',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
