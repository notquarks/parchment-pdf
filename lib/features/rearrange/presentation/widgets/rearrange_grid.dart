import 'package:flutter/material.dart';
import 'package:pdf_tools/features/rearrange/presentation/constants/rearrange_constants.dart';

class RearrangeGrid extends StatelessWidget {
  final List<int> pageOrder;
  final bool compact;
  final bool expanded;
  final Function(int fromIndex, int toIndex) onMovePage;
  final Widget Function(int index, bool compact) pageCardBuilder;
  
  const RearrangeGrid({
    super.key,
    required this.pageOrder,
    required this.compact,
    required this.expanded,
    required this.onMovePage,
    required this.pageCardBuilder,
  });
  
  @override
  Widget build(BuildContext context) {
    final horizontalPadding = expanded ? RearrangeConstants.expandedPadding : RearrangeConstants.compactPadding;
    final cardExtent = compact
        ? RearrangeConstants.compactCardExtent
        : expanded
        ? RearrangeConstants.expandedCardExtent
        : RearrangeConstants.mediumCardExtent;

    return GridView.builder(
      padding: EdgeInsets.fromLTRB(
        horizontalPadding,
        RearrangeConstants.expandedPadding,
        horizontalPadding,
        RearrangeConstants.expandedPadding,
      ),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: cardExtent,
        childAspectRatio: RearrangeConstants.cardAspectRatio,
        crossAxisSpacing: RearrangeConstants.gridSpacing,
        mainAxisSpacing: RearrangeConstants.gridSpacing,
      ),
      itemCount: pageOrder.length,
      itemBuilder: (context, index) => pageCardBuilder(index, compact),
    );
  }
}