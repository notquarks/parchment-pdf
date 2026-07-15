import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'viewer_navigation_panel.dart';

class ViewerScaffold extends StatelessWidget {
  const ViewerScaffold({
    super.key,
    required this.backgroundColor,
    required this.searchVisible,
    required this.navigationVisible,
    required this.navigationTab,
    required this.document,
    required this.pageCount,
    required this.pageNumber,
    required this.outline,
    required this.textSearcher,
    required this.searchQuery,
    required this.shortcutBindings,
    required this.onBackRequest,
    required this.onCloseNavigation,
    required this.onPageSelected,
    required this.onOutlineSelected,
    required this.onSearchResultSelected,
    required this.viewerBuilder,
  });

  static const double _compactBreakpoint = 600;
  static const double _expandedBreakpoint = 960;
  static const double _expandedPadding = 12;
  static const double _navigationGap = 12;

  final Color backgroundColor;
  final bool searchVisible;
  final bool navigationVisible;
  final ViewerNavigationTab navigationTab;
  final PdfDocument? document;
  final int pageCount;
  final int pageNumber;
  final List<PdfOutlineNode> outline;
  final PdfTextSearcher? textSearcher;
  final String searchQuery;
  final Map<ShortcutActivator, VoidCallback> shortcutBindings;
  final VoidCallback onBackRequest;
  final VoidCallback onCloseNavigation;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<PdfDest?> onOutlineSelected;
  final ValueChanged<int> onSearchResultSelected;
  final Widget Function(bool compact, bool expanded) viewerBuilder;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !searchVisible && !navigationVisible,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) onBackRequest();
      },
      child: CallbackShortcuts(
        bindings: shortcutBindings,
        child: Focus(
          autofocus: true,
          child: Scaffold(
            backgroundColor: backgroundColor,
            body: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < _compactBreakpoint;
                final expanded = constraints.maxWidth >= _expandedBreakpoint;

                return Row(
                  children: [
                    if (expanded && navigationVisible)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          _expandedPadding,
                          _expandedPadding,
                          0,
                          _expandedPadding,
                        ),
                        child: ViewerNavigationPanel(
                          key: ValueKey(navigationTab),
                          document: document,
                          pageCount: pageCount,
                          pageNumber: pageNumber,
                          outline: outline,
                          textSearcher: textSearcher,
                          searchQuery: searchQuery,
                          initialTab: navigationTab,
                          onClose: onCloseNavigation,
                          onPageSelected: onPageSelected,
                          onOutlineSelected: onOutlineSelected,
                          onSearchResultSelected: onSearchResultSelected,
                        ),
                      ),
                    if (expanded && navigationVisible)
                      const SizedBox(width: _navigationGap),
                    Expanded(child: viewerBuilder(compact, expanded)),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
