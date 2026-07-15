import 'package:flutter/material.dart';
import 'package:pdf_tools/features/rearrange/presentation/constants/rearrange_constants.dart';

class RearrangeCompactCommandBar extends StatelessWidget {
  final bool canUndo;
  final bool canRedo;
  final bool isDirty;
  final VoidCallback onPickFile;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  
  const RearrangeCompactCommandBar({
    super.key,
    required this.canUndo,
    required this.canRedo,
    required this.isDirty,
    required this.onPickFile,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
  });
  
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Material(
        elevation: RearrangeConstants.gridSpacing,
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.all(RearrangeConstants.compactPadding),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Change PDF',
                onPressed: onPickFile,
                icon: const Icon(Icons.swap_horiz),
              ),
              IconButton(
                tooltip: 'Undo',
                onPressed: canUndo ? onUndo : null,
                icon: const Icon(Icons.undo),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: canRedo ? onRedo : null,
                icon: const Icon(Icons.redo),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: isDirty ? onSave : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save PDF'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}