import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';

class ViewerBottomBar extends StatelessWidget {
  const ViewerBottomBar({
    super.key,
    required this.pageNumber,
    required this.pageCount,
    required this.canNavigate,
    required this.onPrevious,
    required this.onNext,
    required this.onSliderChanged,
    required this.onShowTools,
  });

  final int pageNumber;
  final int pageCount;
  final bool canNavigate;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<double> onSliderChanged;
  final VoidCallback onShowTools;

  @override
  Widget build(BuildContext context) {
    final maxPage = pageCount > 1 ? pageCount.toDouble() : 1.0;
    return Container(
      height: kBottomNavigationBarHeight,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.max,
        children: [
          M3EFilledButton(
            onPressed: pageNumber > 1 && canNavigate ? onPrevious : null,
            child: const Icon(Icons.arrow_back),
          ),
          Expanded(
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 12.0),
                  child: Text(pageNumber.toString()),
                ),
                Expanded(
                  child: Slider(
                    value: pageNumber.toDouble(),
                    min: 1,
                    max: maxPage,
                    divisions: pageCount > 1 ? pageCount - 1 : null,
                    onChanged: pageCount > 1 ? onSliderChanged : null,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12.0),
                  child: Text(pageCount.toString()),
                ),
              ],
            ),
          ),
          M3EFilledButton(
            onPressed: onShowTools,
            child: const Icon(Icons.tune),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: M3EFilledButton(
              onPressed: pageNumber < pageCount && canNavigate ? onNext : null,
              child: const Icon(Icons.arrow_forward),
            ),
          ),
        ],
      ),
    );
  }
}
