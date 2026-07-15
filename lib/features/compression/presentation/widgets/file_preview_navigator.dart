import 'package:flutter/material.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_preview_card.dart';
import 'package:pdfrx/pdfrx.dart';

class FilePreviewNavigator extends StatelessWidget {
  const FilePreviewNavigator({
    super.key,
    required this.documentRef,
    required this.file,
    required this.selectedIndex,
    required this.totalFiles,
    required this.onPrevious,
    required this.onNext,
    this.layout = CompressPreviewLayout.compact,
    this.compact = false,
  });

  final PdfDocumentRef documentRef;
  final PickedPdfInfo file;
  final int selectedIndex;
  final int totalFiles;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final CompressPreviewLayout layout;
  final bool compact;

  bool get _hasPrevious => selectedIndex > 0;
  bool get _hasNext => selectedIndex < totalFiles - 1;
  bool get _hasMultipleFiles => totalFiles > 1;

  @override
  Widget build(BuildContext context) {
    final preview = CompressPreviewCard(
      documentRef: documentRef,
      file: file,
      layout: layout,
    );

    if (!_hasMultipleFiles) {
      return preview;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (compact)
          preview
        else
          Row(
            children: [
              _NavArrow(
                icon: Icons.chevron_left,
                enabled: _hasPrevious,
                onPressed: onPrevious,
              ),
              Expanded(child: preview),
              _NavArrow(
                icon: Icons.chevron_right,
                enabled: _hasNext,
                onPressed: onNext,
              ),
            ],
          ),
        if (!compact) ...[
          const SizedBox(height: 8),
          _FileCounter(current: selectedIndex + 1, total: totalFiles),
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
    return IconButton(
      tooltip: icon == Icons.chevron_left ? 'Previous file' : 'Next file',
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
    return Text(
      '$current of $total',
      style: Theme.of(context).textTheme.labelLarge,
    );
  }
}
