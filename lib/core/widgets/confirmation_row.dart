import 'package:flutter/material.dart';

class ConfirmationRow extends StatelessWidget {
  const ConfirmationRow({super.key, required this.label, required this.value});

  static const double _topPadding = 8;
  static const double _labelWidth = 92;

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: _topPadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(label, style: Theme.of(context).textTheme.labelMedium),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
