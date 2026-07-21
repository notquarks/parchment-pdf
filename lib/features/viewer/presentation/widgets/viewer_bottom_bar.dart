import 'package:flutter/material.dart';

class ViewerBottomBar extends StatefulWidget {
  const ViewerBottomBar({
    super.key,
    required this.pageNumber,
    required this.pageCount,
    required this.canNavigate,
    required this.compact,
    required this.showNavigationButtons,
    required this.onPrevious,
    required this.onNext,
    required this.onPageSelected,
    required this.onPageLabelPressed,
    required this.onShowNavigation,
    required this.onShowTools,
  });

  final int pageNumber;
  final int pageCount;
  final bool canNavigate;
  final bool compact;
  final bool showNavigationButtons;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<int> onPageSelected;
  final VoidCallback onPageLabelPressed;
  final VoidCallback onShowNavigation;
  final VoidCallback onShowTools;

  @override
  State<ViewerBottomBar> createState() => _ViewerBottomBarState();
}

class _ViewerBottomBarState extends State<ViewerBottomBar> {
  static const double _horizontalMargin = 12;
  static const double _bottomMargin = 10;
  static const double _compactPadding = 8;
  static const double _regularPadding = 10;
  static const double _radius = 28;
  static const double _controlGap = 4;
  static const double _pageLabelMinWidth = 76;
  static const double _pageLabelMaxWidth = 112;
  static const double _elevation = 4;

  double? _previewPage;

  int get _safePageCount => widget.pageCount > 0 ? widget.pageCount : 1;
  double get _sliderValue => (_previewPage ?? widget.pageNumber.toDouble())
      .clamp(1, _safePageCount.toDouble())
      .toDouble();
  int get _displayPage => widget.pageCount == 0 ? 0 : _sliderValue.round();

  @override
  Widget build(BuildContext context) {
    final padding = widget.compact ? _compactPadding : _regularPadding;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        _horizontalMargin,
        0,
        _horizontalMargin,
        _bottomMargin,
      ),
      child: Material(
        elevation: _elevation,
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(_radius),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Row(
            children: [
              IconButton(
                tooltip: 'Pages and outline',
                onPressed: widget.onShowNavigation,
                icon: const Icon(Icons.view_sidebar_outlined),
              ),
              if (widget.showNavigationButtons) ...[
                const SizedBox(width: _controlGap),
                IconButton(
                  tooltip: 'Previous page',
                  onPressed: widget.pageNumber > 1 && widget.canNavigate
                      ? widget.onPrevious
                      : null,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _pageLabelMinWidth,
                  maxWidth: _pageLabelMaxWidth,
                ),
                child: TextButton(
                  onPressed: widget.pageCount > 0
                      ? widget.onPageLabelPressed
                      : null,
                  child: Text(
                    '$_displayPage / ${widget.pageCount}',
                    maxLines: 1,
                  ),
                ),
              ),
              Expanded(
                child: Slider(
                  value: _sliderValue,
                  min: 1,
                  max: _safePageCount.toDouble(),
                  onChangeStart: widget.pageCount > 1
                      ? (value) => setState(() => _previewPage = value)
                      : null,
                  onChanged: widget.pageCount > 1
                      ? (value) => setState(() => _previewPage = value)
                      : null,
                  onChangeEnd: widget.pageCount > 1
                      ? (value) {
                          final page = value.round().clamp(1, widget.pageCount).toInt();
                          setState(() => _previewPage = null);
                          widget.onPageSelected(page);
                        }
                      : null,
                ),
              ),
              if (widget.showNavigationButtons) ...[
                IconButton(
                  tooltip: 'Next page',
                  onPressed:
                      widget.pageNumber < widget.pageCount && widget.canNavigate
                      ? widget.onNext
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
                const SizedBox(width: _controlGap),
              ],
              IconButton(
                tooltip: 'Reader settings',
                onPressed: widget.onShowTools,
                icon: const Icon(Icons.tune),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
