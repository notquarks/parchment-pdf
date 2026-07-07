import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class CompressEmptyState extends StatelessWidget {
  const CompressEmptyState({super.key, required this.onPick});

  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final containerSize = shortest * 0.5;
    final pillSize = containerSize * 0.6;
    final iconSize = pillSize * 0.4;
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: containerSize,
          height: containerSize,
          child: InkWell(
            onTap: onPick,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              spacing: 12,
              children: [
                Text(
                  'Select a Document',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                M3EContainer.pill(
                  width: pillSize,
                  height: pillSize,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.insert_drive_file, size: iconSize),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
