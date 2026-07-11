import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ViewerSearchBar extends StatelessWidget {
  const ViewerSearchBar({
    super.key,
    required this.searchController,
    required this.textSearcher,
    required this.onToggleSearch,
    required this.onSearch,
    required this.onSearchNext,
    required this.onSearchPrev,
    required this.onClearSearch,
  });

  final TextEditingController searchController;
  final PdfTextSearcher? textSearcher;
  final VoidCallback onToggleSearch;
  final ValueChanged<String> onSearch;
  final VoidCallback onSearchNext;
  final VoidCallback onSearchPrev;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: Theme.of(context).colorScheme.surface,
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onToggleSearch,
          ),
          Expanded(
            child: TextField(
              controller: searchController,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search in document',
                border: InputBorder.none,
              ),
              onSubmitted: onSearch,
              onChanged: (value) => onSearch(value),
            ),
          ),
          if (searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              onPressed: onClearSearch,
            ),
          if (textSearcher != null)
            ListenableBuilder(
              listenable: textSearcher!,
              builder: (context, _) {
                final matches = textSearcher!.matches;
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
            onPressed: onSearchPrev,
          ),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down),
            onPressed: onSearchNext,
          ),
        ],
      ),
    );
  }
}
