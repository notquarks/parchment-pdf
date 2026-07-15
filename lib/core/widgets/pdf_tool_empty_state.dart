import 'package:flutter/material.dart';

class PdfToolEmptyState extends StatelessWidget {
  const PdfToolEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.actionIcon,
    required this.actionLabel,
    required this.onAction,
  });

  static const double _maximumWidth = 560;
  static const double _horizontalPadding = 24;
  static const double _verticalPadding = 32;
  static const double _cardPadding = 28;
  static const double _illustrationExtent = 96;
  static const double _illustrationRadius = 28;
  static const double _illustrationIconSize = 48;
  static const double _sectionSpacing = 20;
  static const double _textSpacing = 8;

  final IconData icon;
  final String title;
  final String description;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: _horizontalPadding,
          vertical: _verticalPadding,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maximumWidth),
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(_cardPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: _illustrationExtent,
                    height: _illustrationExtent,
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(_illustrationRadius),
                    ),
                    child: Icon(
                      icon,
                      size: _illustrationIconSize,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: _sectionSpacing),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: _textSpacing),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: _sectionSpacing),
                  FilledButton.icon(
                    onPressed: onAction,
                    icon: Icon(actionIcon),
                    label: Text(actionLabel),
                  ),
                  const SizedBox(height: _sectionSpacing),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
