import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ViewerSearchBar extends StatelessWidget {
  const ViewerSearchBar({
    super.key,
    required this.searchController,
    required this.focusNode,
    required this.textSearcher,
    required this.compact,
    required this.onClose,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearchNext,
    required this.onSearchPrev,
    required this.onClearSearch,
    required this.onShowResults,
  });

  static const double _horizontalPadding = 8;
  static const double _verticalPadding = 6;
  static const double _compactMaxWidth = 720;
  static const double _regularMaxWidth = 920;
  static const double _radius = 20;
  static const double _elevation = 4;
  static const double _compactDividerHeight = 1;

  final TextEditingController searchController;
  final FocusNode focusNode;
  final PdfTextSearcher? textSearcher;
  final bool compact;
  final VoidCallback onClose;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearchNext;
  final VoidCallback onSearchPrev;
  final VoidCallback onClearSearch;
  final VoidCallback onShowResults;

  @override
  Widget build(BuildContext context) {
    final maxWidth = compact ? _compactMaxWidth : _regularMaxWidth;
    final field = _SearchField(
      searchController: searchController,
      focusNode: focusNode,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onClearSearch: onClearSearch,
    );
    final controls = _SearchControls(
      textSearcher: textSearcher,
      onSearchNext: onSearchNext,
      onSearchPrev: onSearchPrev,
      onShowResults: onShowResults,
    );

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Material(
              elevation: _elevation,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(_radius),
              clipBehavior: Clip.antiAlias,
              child: compact
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            _closeButton(),
                            Expanded(child: field),
                          ],
                        ),
                        const Divider(height: _compactDividerHeight),
                        Align(
                          alignment: Alignment.centerRight,
                          child: controls,
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        _closeButton(),
                        Expanded(child: field),
                        controls,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _closeButton() {
    return IconButton(
      tooltip: 'Close search',
      onPressed: onClose,
      icon: const Icon(Icons.arrow_back),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.searchController,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: searchController,
      focusNode: focusNode,
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search document',
        border: InputBorder.none,
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClearSearch,
                icon: const Icon(Icons.clear),
              ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class _SearchControls extends StatelessWidget {
  const _SearchControls({
    required this.textSearcher,
    required this.onSearchNext,
    required this.onSearchPrev,
    required this.onShowResults,
  });

  final PdfTextSearcher? textSearcher;
  final VoidCallback onSearchNext;
  final VoidCallback onSearchPrev;
  final VoidCallback onShowResults;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SearchStatus(
          textSearcher: textSearcher,
          onShowResults: onShowResults,
        ),
        IconButton(
          tooltip: 'Previous result',
          onPressed: textSearcher?.hasMatches == true ? onSearchPrev : null,
          icon: const Icon(Icons.keyboard_arrow_up),
        ),
        IconButton(
          tooltip: 'Next result',
          onPressed: textSearcher?.hasMatches == true ? onSearchNext : null,
          icon: const Icon(Icons.keyboard_arrow_down),
        ),
        IconButton(
          tooltip: 'Show results',
          onPressed: textSearcher?.hasMatches == true ? onShowResults : null,
          icon: const Icon(Icons.list_alt_outlined),
        ),
      ],
    );
  }
}

class _SearchStatus extends StatelessWidget {
  const _SearchStatus({
    required this.textSearcher,
    required this.onShowResults,
  });

  static const double _statusMinWidth = 64;
  static const double _progressSize = 18;
  static const double _progressStroke = 2;
  static const double _statusPadding = 6;
  static const double _statusHeight = 40;

  final PdfTextSearcher? textSearcher;
  final VoidCallback onShowResults;

  @override
  Widget build(BuildContext context) {
    final searcher = textSearcher;
    if (searcher == null) {
      return const SizedBox(width: _statusMinWidth);
    }

    return ListenableBuilder(
      listenable: searcher,
      builder: (context, child) {
        if (searcher.isSearching && !searcher.hasMatches) {
          return const SizedBox(
            width: _statusMinWidth,
            height: _statusHeight,
            child: Center(
              child: SizedBox.square(
                dimension: _progressSize,
                child: CircularProgressIndicator(strokeWidth: _progressStroke),
              ),
            ),
          );
        }

        final total = searcher.matches.length;
        final current = searcher.currentIndex == null
            ? 0
            : searcher.currentIndex! + 1;
        final label = total == 0 ? '0' : '$current / $total';

        return TextButton(
          onPressed: total > 0 ? onShowResults : null,
          style: TextButton.styleFrom(
            minimumSize: const Size(_statusMinWidth, _statusHeight),
            padding: const EdgeInsets.symmetric(horizontal: _statusPadding),
          ),
          child: Text(label, maxLines: 1),
        );
      },
    );
  }
}
