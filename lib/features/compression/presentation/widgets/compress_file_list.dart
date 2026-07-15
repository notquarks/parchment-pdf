import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/core/utils/string_utils.dart';

class CompressFileList extends StatelessWidget {
  const CompressFileList({
    super.key,
    required this.files,
    required this.selectedIndex,
    required this.axis,
    required this.onSelected,
    required this.onRemoved,
    this.shrinkWrap = false,
    this.physics,
  });

  static const double _horizontalHeight = 108;
  static const double _horizontalTileWidth = 244;
  static const double _listSpacing = 8;
  static const double _listPadding = 2;

  final List<PickedPdfInfo> files;
  final int selectedIndex;
  final Axis axis;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onRemoved;
  final bool shrinkWrap;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    if (axis == Axis.horizontal) {
      return SizedBox(
        height: _horizontalHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(_listPadding),
          itemCount: files.length,
          separatorBuilder: (_, _) => const SizedBox(width: _listSpacing),
          itemBuilder: (context, index) => SizedBox(
            width: _horizontalTileWidth,
            child: _CompressFileTile(
              file: files[index],
              selected: index == selectedIndex,
              onSelected: () => onSelected(index),
              onRemoved: () => onRemoved(index),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: physics,
      padding: const EdgeInsets.all(_listPadding),
      itemCount: files.length,
      separatorBuilder: (_, _) => const SizedBox(height: _listSpacing),
      itemBuilder: (context, index) => _CompressFileTile(
        file: files[index],
        selected: index == selectedIndex,
        onSelected: () => onSelected(index),
        onRemoved: () => onRemoved(index),
      ),
    );
  }
}

class _CompressFileTile extends StatelessWidget {
  const _CompressFileTile({
    required this.file,
    required this.selected,
    required this.onSelected,
    required this.onRemoved,
  });

  static const double _borderRadius = 16;
  static const double _padding = 12;
  static const double _iconSize = 40;
  static const double _contentSpacing = 10;

  final PickedPdfInfo file;
  final bool selected;
  final VoidCallback onSelected;
  final VoidCallback onRemoved;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pageText = file.pageCount == null
        ? 'Reading pages…'
        : '${file.pageCount} ${file.pageCount == 1 ? 'page' : 'pages'}';
    final semanticsLabel =
        '${p.basename(file.file.path)}, ${formatBytes(file.sizeBytes, 2)}, $pageText${selected ? ', selected' : ''}';

    return Semantics(
      button: true,
      selected: selected,
      label: semanticsLabel,
      child: Material(
        color: selected
            ? colorScheme.secondaryContainer
            : colorScheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_borderRadius),
          side: BorderSide(
            color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onSelected,
          child: Padding(
            padding: const EdgeInsets.all(_padding),
            child: Row(
              children: [
                Container(
                  width: _iconSize,
                  height: _iconSize,
                  decoration: BoxDecoration(
                    color: selected
                        ? colorScheme.primaryContainer
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.picture_as_pdf_outlined,
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: _contentSpacing),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.basename(file.file.path),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatBytes(file.sizeBytes, 2)} • $pageText',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${p.basename(file.file.path)}',
                  onPressed: onRemoved,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
