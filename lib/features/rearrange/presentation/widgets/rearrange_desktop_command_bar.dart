import 'package:flutter/material.dart';
import 'package:pdf_tools/features/rearrange/presentation/constants/rearrange_constants.dart';

class RearrangeDesktopCommandBar extends StatelessWidget {
  final String fileName;
  final int pageCount;
  final bool isDirty;
  final bool hasSelection;
  final int selectedPageIndex;
  final VoidCallback onPickFile;
  final VoidCallback onMoveSelected;
  final VoidCallback onSave;
  final List<Widget> moveMenuItems;
  
  const RearrangeDesktopCommandBar({
    super.key,
    required this.fileName,
    required this.pageCount,
    required this.isDirty,
    required this.hasSelection,
    required this.selectedPageIndex,
    required this.onPickFile,
    required this.onMoveSelected,
    required this.onSave,
    required this.moveMenuItems,
  });
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RearrangeConstants.expandedPadding,
          vertical: RearrangeConstants.compactPadding,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(
                    '$pageCount pages${isDirty ? ' • Unsaved changes' : ''}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Change PDF'),
            ),
            const SizedBox(width: RearrangeConstants.compactPadding),
            MenuAnchor(
              builder: (context, controller, child) => OutlinedButton.icon(
                onPressed: hasSelection
                    ? () => controller.isOpen
                          ? controller.close()
                          : controller.open()
                    : null,
                icon: const Icon(Icons.drive_file_move_outline),
                label: Text(
                  hasSelection
                      ? 'Position ${selectedPageIndex + 1}'
                      : 'Select a page',
                ),
              ),
              menuChildren: moveMenuItems,
            ),
            const SizedBox(width: RearrangeConstants.compactPadding),
            FilledButton.icon(
              onPressed: isDirty ? onSave : null,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save PDF'),
            ),
          ],
        ),
      ),
    );
  }
}