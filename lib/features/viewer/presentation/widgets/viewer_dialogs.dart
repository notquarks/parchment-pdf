import 'package:flutter/material.dart';

Future<int?> showGoToPageDialog({
  required BuildContext context,
  required int pageNumber,
  required int pageCount,
}) async {
  final inputController = TextEditingController(text: '$pageNumber');
  try {
    return await showDialog<int>(
      context: context,
      builder: (context) {
        int? validPage() {
          final page = int.tryParse(inputController.text);
          return page != null && page >= 1 && page <= pageCount ? page : null;
        }

        return AlertDialog(
          title: const Text('Go to page'),
          content: TextField(
            controller: inputController,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.go,
            decoration: InputDecoration(
              labelText: 'Page number',
              helperText: '1\u2013$pageCount',
            ),
            onSubmitted: (_) {
              final page = validPage();
              if (page != null) Navigator.pop(context, page);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final page = validPage();
                if (page != null) Navigator.pop(context, page);
              },
              child: const Text('Go'),
            ),
          ],
        );
      },
    );
  } finally {
    inputController.dispose();
  }
}
