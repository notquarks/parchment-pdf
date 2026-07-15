import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class CompressInlineActions extends StatelessWidget {
  const CompressInlineActions({
    super.key,
    required this.onAddFile,
    required this.onCompress,
  });

  final VoidCallback onAddFile;
  final VoidCallback onCompress;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        spacing: 8,
        children: [
          M3EFilledButton.tonal(
            shape: .square,
            onPressed: onAddFile,
            child: const Icon(Icons.add),
          ),
          Expanded(
            child: M3EButton.icon(
              onPressed: onCompress,
              icon: const Icon(Icons.compress),
              label: const Text('Compress'),
            ),
          ),
        ],
      ),
    );
  }
}
