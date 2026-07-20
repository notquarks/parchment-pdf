import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf_tools/core/widgets/page_small_preview.dart';
import 'package:pdf_tools/features/rearrange/presentation/constants/rearrange_constants.dart';

class RearrangePageCard extends StatelessWidget {
  final int index;
  final int pageNumber;
  final bool isSelected;
  final bool isDropTarget;
  final bool compact;
  final bool interactive;
  final PdfDocumentRef documentRef;
  final VoidCallback onTap;
  final VoidCallback onMoveEarlier;
  final VoidCallback onMoveLater;
  final Function(Offset position) onContextMenu;
  final int totalPageCount;
  final Function(String command, int index)? onRunCommand;
  final List<PopupMenuEntry<String>> Function(int index)? popupItemsBuilder;
  
  const RearrangePageCard({
    super.key,
    required this.index,
    required this.pageNumber,
    required this.isSelected,
    required this.isDropTarget,
    required this.compact,
    required this.interactive,
    required this.documentRef,
    required this.onTap,
    required this.onMoveEarlier,
    required this.onMoveLater,
    required this.onContextMenu,
    required this.totalPageCount,
    this.onRunCommand,
    this.popupItemsBuilder,
  });
  
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = isDropTarget
        ? colorScheme.tertiary
        : isSelected
        ? colorScheme.primary
        : colorScheme.outlineVariant;
    final borderWidth = isSelected || isDropTarget
        ? RearrangeConstants.selectedBorderWidth
        : RearrangeConstants.defaultBorderWidth;

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: RearrangeConstants.reorderAnimationMilliseconds),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.secondaryContainer.withValues(
                alpha: RearrangeConstants.selectedSurfaceOpacity,
              )
            : colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(RearrangeConstants.cardRadius),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: isDropTarget
            ? [
                BoxShadow(
                  color: colorScheme.tertiary.withValues(alpha: RearrangeConstants.shadowOpacity),
                  blurRadius: RearrangeConstants.gridSpacing,
                  spreadRadius: RearrangeConstants.shadowSpreadRadius,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RearrangeConstants.cardRadius - 1),
        child: Column(
          children: [
            _buildCardHeader(context, compact),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: RearrangeConstants.compactPadding,
                ),
                child: PageSmallPreview(
                  documentRef: documentRef,
                  pageNumber: pageNumber,
                  isSelected: isSelected,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(RearrangeConstants.compactPadding),
              child: Text(
                'Original page $pageNumber',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (!interactive) return card;

    return Semantics(
      selected: isSelected,
      button: true,
      label:
          'Original page $pageNumber, position ${index + 1} of $totalPageCount',
      onTap: onTap,
      onIncrease: index < totalPageCount - 1 ? onMoveLater : null,
      onDecrease: index > 0 ? onMoveEarlier : null,
      child: InkWell(
        onTap: onTap,
        onSecondaryTapDown: Platform.isWindows
            ? (details) => onContextMenu(details.globalPosition)
            : null,
        borderRadius: BorderRadius.circular(RearrangeConstants.cardRadius),
        child: card,
      ),
    );
  }
  
  Widget _buildCardHeader(BuildContext context, bool compact) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: RearrangeConstants.commandHeight * RearrangeConstants.headerHeightFactor,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          RearrangeConstants.compactPadding,
          RearrangeConstants.gridSpacing / 2,
          RearrangeConstants.gridSpacing / 2,
          0,
        ),
        child: Row(
          children: [
            Container(
              constraints: const BoxConstraints(
                minWidth: RearrangeConstants.commandHeight * RearrangeConstants.badgeSizeFactor,
                minHeight: RearrangeConstants.commandHeight * RearrangeConstants.badgeSizeFactor,
              ),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: RearrangeConstants.gridSpacing / 2),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(RearrangeConstants.commandHeight),
              ),
              child: Text(
                '${index + 1}',
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            const Spacer(),
            if (Platform.isWindows)
              Tooltip(
                message: 'Drag to reorder',
                child: Icon(
                  Icons.drag_indicator,
                  color: colorScheme.onSurfaceVariant,
                ),
              )
            else
              PopupMenuButton<String>(
                tooltip: 'Page actions',
                onSelected: (command) {
                  if (onRunCommand != null) {
                    onRunCommand!(command, index);
                  }
                },
                itemBuilder: (context) => popupItemsBuilder != null 
                    ? popupItemsBuilder!(index)
                    : [],
                icon: const Icon(Icons.more_vert),
              ),
          ],
        ),
      ),
    );
  }
  
  static Widget buildDragFeedback(
    BuildContext context,
    int index,
    int pageNumber,
    PdfDocumentRef documentRef,
    int totalPageCount,
  ) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width < RearrangeConstants.compactBreakpoint
        ? RearrangeConstants.compactCardExtent
        : RearrangeConstants.mediumCardExtent;
    final compact = mediaQuery.size.width < RearrangeConstants.compactBreakpoint;

    return MediaQuery(
      data: mediaQuery,
      child: Material(
        color: Colors.transparent,
        child: Opacity(
          opacity: RearrangeConstants.dragFeedbackOpacity,
          child: Transform.scale(
            scale: RearrangeConstants.dragFeedbackScale,
            child: SizedBox(
              width: width,
              height: width / RearrangeConstants.cardAspectRatio,
              child: RearrangePageCard(
                index: index,
                pageNumber: pageNumber,
                isSelected: false,
                isDropTarget: false,
                compact: compact,
                interactive: false,
                documentRef: documentRef,
                onTap: () {},
                onMoveEarlier: () {},
                onMoveLater: () {},
                onContextMenu: (position) {},
                totalPageCount: totalPageCount,
              ),
            ),
          ),
        ),
      ),
    );
  }
}