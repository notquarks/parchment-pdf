import 'package:flutter/material.dart';

class ViewerSectionHeader extends StatelessWidget {
  const ViewerSectionHeader({super.key, required this.title});

  static const double _horizontalPadding = 24;
  static const double _topPadding = 20;
  static const double _bottomPadding = 6;
  static const double _fontSize = 12;
  static const double _letterSpacing = 1.1;

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _horizontalPadding,
        _topPadding,
        _horizontalPadding,
        _bottomPadding,
      ),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: _fontSize,
          fontWeight: FontWeight.w600,
          letterSpacing: _letterSpacing,
        ),
      ),
    );
  }
}

class ViewerEnumSelect<T extends Enum> extends StatelessWidget {
  const ViewerEnumSelect({
    super.key,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onChanged,
    this.leading,
  });

  static const double _horizontalPadding = 24;
  static const double _verticalPadding = 10;
  static const double _leadingGap = 16;
  static const double _menuGap = 8;
  static const double _iconSize = 20;

  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onChanged;
  final IconData? leading;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(
              leading,
              size: _iconSize,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: _leadingGap),
          ],
          Expanded(child: Text(label)),
          const SizedBox(width: _menuGap),
          MenuAnchor(
            useRootOverlay: true,
            menuChildren: [
              for (final value in values)
                MenuItemButton(
                  trailingIcon: value == selected
                      ? Icon(
                          Icons.check,
                          color: colorScheme.primary,
                          size: _iconSize,
                        )
                      : null,
                  onPressed: () => onChanged(value),
                  child: Text(labelOf(value)),
                ),
            ],
            builder: (context, controller, child) {
              return TextButton.icon(
                onPressed: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                icon: const Icon(Icons.arrow_drop_down),
                label: Text(labelOf(selected)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class ViewerToggleRow extends StatelessWidget {
  const ViewerToggleRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.leading,
    this.subtitle,
  });

  static const double _horizontalPadding = 24;
  static const double _verticalPadding = 6;
  static const double _leadingGap = 16;
  static const double _iconSize = 20;

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  final IconData? leading;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            Icon(
              leading,
              size: _iconSize,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: _leadingGap),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          Switch.adaptive(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class ViewerSliderRow extends StatelessWidget {
  const ViewerSliderRow({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.valueLabel,
    this.leading,
    this.divisions,
    this.onChangeEnd,
  });

  static const double _horizontalPadding = 24;
  static const double _verticalPadding = 6;
  static const double _labelGap = 8;
  static const double _valueWidth = 56;
  static const double _iconSize = 20;

  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String valueLabel;
  final IconData? leading;
  final int? divisions;
  final ValueChanged<double>? onChangeEnd;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _horizontalPadding,
        vertical: _verticalPadding,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (leading != null) ...[
                Icon(
                  leading,
                  size: _iconSize,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: _labelGap),
              ],
              Expanded(child: Text(label)),
              SizedBox(
                width: _valueWidth,
                child: Text(
                  valueLabel,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max).toDouble(),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ],
      ),
    );
  }
}

class ViewerActionRow extends StatelessWidget {
  const ViewerActionRow({
    super.key,
    required this.label,
    required this.onPressed,
    required this.leading,
  });

  static const double _horizontalPadding = 12;

  final String label;
  final VoidCallback onPressed;
  final IconData leading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _horizontalPadding),
      child: ListTile(
        leading: Icon(leading),
        title: Text(label),
        onTap: onPressed,
      ),
    );
  }
}
