import 'package:flutter/material.dart';
import 'package:pdf_tools/components/compress/compress_preview_card.dart';
import 'package:pdfrx/pdfrx.dart';

class FilePreviewNavigator extends StatelessWidget {
  const FilePreviewNavigator({
    super.key,
    required this.documentRef,
    required this.selectedIndex,
    required this.totalFiles,
    required this.onPrevious,
    required this.onNext,
    this.compact = false,
  });

  final PdfDocumentRef documentRef;
  final int selectedIndex;
  final int totalFiles;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final bool compact;

  bool get _hasPrevious => selectedIndex > 0;
  bool get _hasNext => selectedIndex < totalFiles - 1;
  bool get _hasMultipleFiles => totalFiles > 1;

  @override
  Widget build(BuildContext context) {
    if (!_hasMultipleFiles) {
      return CompressPreviewCard(documentRef: documentRef);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (!compact)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _NavArrow(
                icon: Icons.chevron_left,
                enabled: _hasPrevious,
                onPressed: onPrevious,
              ),
              CompressPreviewCard(documentRef: documentRef),
              _NavArrow(
                icon: Icons.chevron_right,
                enabled: _hasNext,
                onPressed: onNext,
              ),
            ],
          )
        else
          CompressPreviewCard(documentRef: documentRef),
        if (!compact) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: _FileCounter(current: selectedIndex + 1, total: totalFiles),
          ),
        ],
      ],
    );
  }
}

class _NavArrow extends StatelessWidget {
  const _NavArrow({
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return IconButton(
      iconSize: 28,
      style: IconButton.styleFrom(
        foregroundColor: enabled
            ? colorScheme.primary
            : colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
    );
  }
}

class _FileCounter extends StatelessWidget {
  const _FileCounter({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        '$current / $total',
        style: TextStyle(
          color: colorScheme.onPrimaryContainer,
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }
}
