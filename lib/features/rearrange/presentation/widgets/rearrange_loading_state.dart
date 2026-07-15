import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/core/widgets/loading_spinner.dart';
import 'package:pdf_tools/features/rearrange/presentation/constants/rearrange_constants.dart';

class RearrangeLoadingState extends StatelessWidget {
  final String filePath;
  final VoidCallback onPickFile;
  
  const RearrangeLoadingState({super.key, required this.filePath, required this.onPickFile});
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(RearrangeConstants.expandedPadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LoadingSpinner(size: 0.4),
            const SizedBox(height: RearrangeConstants.expandedPadding),
            Text(
              'Loading page thumbnails…',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: RearrangeConstants.compactPadding),
            Text(
              p.basename(filePath),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: RearrangeConstants.expandedPadding),
            OutlinedButton.icon(
              onPressed: onPickFile,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Choose another PDF'),
            ),
          ],
        ),
      ),
    );
  }
}