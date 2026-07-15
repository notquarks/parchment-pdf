import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

enum ViewerNavigationTab { thumbnails, outline, search }

class ViewerNavigationPanel extends StatelessWidget {
  const ViewerNavigationPanel({
    super.key,
    required this.document,
    required this.pageCount,
    required this.pageNumber,
    required this.outline,
    required this.textSearcher,
    required this.searchQuery,
    required this.onPageSelected,
    required this.onOutlineSelected,
    required this.onSearchResultSelected,
    required this.onClose,
    this.initialTab = ViewerNavigationTab.thumbnails,
    this.isSheet = false,
  });

  static const double panelWidth = 336;
  static const double _sheetHeightFactor = 0.78;
  static const double _panelRadius = 20;
  static const double _sheetRadius = 24;
  static const double _thumbnailExtent = 144;
  static const double _thumbnailAspectRatio = 0.7;
  static const double _thumbnailSpacing = 10;
  static const double _thumbnailPadding = 12;
  static const double _thumbnailRadius = 10;
  static const double _selectedBorderWidth = 2;
  static const double _defaultBorderWidth = 1;
  static const double _emptyStatePadding = 32;
  static const double _thumbnailLabelPadding = 6;
  static const double _searchProgressGap = 16;
  static const double _resultDividerHeight = 1;
  static const double _emptyIconSize = 42;
  static const double _emptyTitleGap = 12;
  static const double _emptyMessageGap = 6;
  static const int _resultMaxLines = 3;
  static const int _snippetContextCharacters = 42;

  final PdfDocument? document;
  final int pageCount;
  final int pageNumber;
  final List<PdfOutlineNode> outline;
  final PdfTextSearcher? textSearcher;
  final String searchQuery;
  final ValueChanged<int> onPageSelected;
  final ValueChanged<PdfDest?> onOutlineSelected;
  final ValueChanged<int> onSearchResultSelected;
  final VoidCallback onClose;
  final ViewerNavigationTab initialTab;
  final bool isSheet;

  @override
  Widget build(BuildContext context) {
    final height = isSheet
        ? MediaQuery.sizeOf(context).height * _sheetHeightFactor
        : double.infinity;
    final radius = isSheet
        ? const BorderRadius.vertical(top: Radius.circular(_sheetRadius))
        : const BorderRadius.all(Radius.circular(_panelRadius));

    return DefaultTabController(
      length: ViewerNavigationTab.values.length,
      initialIndex: initialTab.index,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: isSheet ? double.infinity : panelWidth,
          height: height,
          child: SafeArea(
            top: !isSheet,
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    'Document navigation',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  trailing: IconButton(
                    tooltip: 'Close',
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.grid_view_outlined), text: 'Pages'),
                    Tab(icon: Icon(Icons.account_tree_outlined), text: 'Outline'),
                    Tab(icon: Icon(Icons.search), text: 'Results'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildThumbnails(context),
                      _buildOutline(context),
                      _buildSearchResults(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnails(BuildContext context) {
    final loadedDocument = document;
    if (loadedDocument == null || pageCount == 0) {
      return const Center(child: CircularProgressIndicator());
    }

    return GridView.builder(
      padding: const EdgeInsets.all(_thumbnailPadding),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: _thumbnailExtent,
        childAspectRatio: _thumbnailAspectRatio,
        crossAxisSpacing: _thumbnailSpacing,
        mainAxisSpacing: _thumbnailSpacing,
      ),
      itemCount: pageCount,
      itemBuilder: (context, index) {
        final itemPage = index + 1;
        final selected = itemPage == pageNumber;
        final colorScheme = Theme.of(context).colorScheme;

        return Semantics(
          selected: selected,
          button: true,
          label: 'Page $itemPage of $pageCount',
          child: InkWell(
            borderRadius: BorderRadius.circular(_thumbnailRadius),
            onTap: () => onPageSelected(itemPage),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(_thumbnailRadius),
                border: Border.all(
                  color: selected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant,
                  width: selected
                      ? _selectedBorderWidth
                      : _defaultBorderWidth,
                ),
              ),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(_thumbnailRadius),
                      ),
                      child: PdfPageView(
                        document: loadedDocument,
                        pageNumber: itemPage,
                        backgroundColor: colorScheme.surface,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: _thumbnailLabelPadding,
                    ),
                    child: Text(
                      '$itemPage',
                      style: selected
                          ? Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            )
                          : Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOutline(BuildContext context) {
    if (document == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (outline.isEmpty) {
      return _emptyState(
        context,
        icon: Icons.account_tree_outlined,
        title: 'No outline',
        message: 'This PDF does not contain document bookmarks.',
      );
    }

    return ListView(
      children: [
        for (final node in outline)
          _OutlineTile(
            node: node,
            depth: 0,
            onSelected: onOutlineSelected,
          ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context) {
    final searcher = textSearcher;
    if (searchQuery.trim().isEmpty) {
      return _emptyState(
        context,
        icon: Icons.manage_search_outlined,
        title: 'Search results',
        message: 'Search the document to see matching pages and text.',
      );
    }
    if (searcher == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListenableBuilder(
      listenable: searcher,
      builder: (context, child) {
        final matches = searcher.matches;
        if (matches.isEmpty && searcher.isSearching) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(value: searcher.searchProgress),
                const SizedBox(height: _searchProgressGap),
                const Text('Searching document…'),
              ],
            ),
          );
        }
        if (matches.isEmpty) {
          return _emptyState(
            context,
            icon: Icons.search_off_outlined,
            title: 'No matches',
            message: 'No text matched “$searchQuery”.',
          );
        }

        return ListView.separated(
          itemCount: matches.length,
          separatorBuilder: (context, index) =>
              const Divider(height: _resultDividerHeight),
          itemBuilder: (context, index) {
            final match = matches[index];
            final active = searcher.currentIndex == index;
            return ListTile(
              selected: active,
              leading: CircleAvatar(child: Text('${match.pageNumber}')),
              title: Text(
                _snippet(match),
                maxLines: _resultMaxLines,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text('Page ${match.pageNumber}'),
              onTap: () => onSearchResultSelected(index),
            );
          },
        );
      },
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String message,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(_emptyStatePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: _emptyIconSize,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: _emptyTitleGap),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: _emptyMessageGap),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _snippet(PdfPageTextRange match) {
    final source = match.pageText.fullText;
    if (source.isEmpty) return match.text;

    final safeStart = match.start.clamp(0, source.length).toInt();
    final safeEnd = match.end.clamp(safeStart, source.length).toInt();
    final start = max(0, safeStart - _snippetContextCharacters);
    final end = min(source.length, safeEnd + _snippetContextCharacters);
    final snippet = source
        .substring(start, end)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final prefix = start > 0 ? '…' : '';
    final suffix = end < source.length ? '…' : '';
    return '$prefix$snippet$suffix';
  }
}

class _OutlineTile extends StatelessWidget {
  const _OutlineTile({
    required this.node,
    required this.depth,
    required this.onSelected,
  });

  static const double _indent = 14;
  static const int _maxVisualDepth = 6;

  final PdfOutlineNode node;
  final int depth;
  final ValueChanged<PdfDest?> onSelected;

  @override
  Widget build(BuildContext context) {
    final visualDepth = min(depth, _maxVisualDepth);
    final leadingPadding = visualDepth * _indent;

    if (node.children.isEmpty) {
      return Padding(
        padding: EdgeInsets.only(left: leadingPadding),
        child: ListTile(
          dense: true,
          title: Text(node.title),
          onTap: node.dest == null ? null : () => onSelected(node.dest),
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.only(left: leadingPadding),
      child: ExpansionTile(
        title: Text(node.title),
        controlAffinity: ListTileControlAffinity.leading,
        children: [
          if (node.dest != null)
            ListTile(
              dense: true,
              leading: const Icon(Icons.arrow_forward),
              title: const Text('Open section'),
              onTap: () => onSelected(node.dest),
            ),
          for (final child in node.children)
            _OutlineTile(
              node: child,
              depth: depth + 1,
              onSelected: onSelected,
            ),
        ],
      ),
    );
  }
}
