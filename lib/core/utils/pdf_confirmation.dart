import 'package:flutter/material.dart';
import 'package:pdf_tools/core/widgets/confirmation_row.dart';

class PdfConfirmationRow {
  const PdfConfirmationRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;
}

Future<bool> showPdfConfirmation({
  required BuildContext context,
  required String title,
  required List<PdfConfirmationRow> rows,
  required String message,
  required IconData actionIcon,
  required String actionLabel,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final row in rows)
            ConfirmationRow(label: row.label, value: row.value),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(message),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () => Navigator.pop(context, true),
          icon: Icon(actionIcon),
          label: Text(actionLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
