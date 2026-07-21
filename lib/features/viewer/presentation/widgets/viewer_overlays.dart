import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf_tools/features/viewer/data/models/viewer_settings.dart';

List<Widget> buildViewerOverlays({
  required Size size,
  required PdfViewerController controller,
  required ReadingDirection readingDirection,
  required bool canNavigate,
  required bool Function() isTapSuppressed,
  required VoidCallback onPrevious,
  required VoidCallback onNext,
  required VoidCallback onToggleChrome,
  required bool Function(Offset localPosition) onDoubleTap,
}) {
  const tapZoneFraction = 0.28;
  const scrollThumbSize = Size(44, 28);
  final overlays = <Widget>[];
  final sideWidth = size.width * tapZoneFraction;
  final centerWidth = max(0.0, size.width - sideWidth * 2);

  overlays.add(
    PdfViewerScrollThumb(
      controller: controller,
      orientation: readingDirection == ReadingDirection.vertical
          ? ScrollbarOrientation.right
          : ScrollbarOrientation.bottom,
      thumbSize: scrollThumbSize,
      thumbBuilder: (context, thumbSize, pageNumber, controller) {
        return _ScrollThumbLabel(pageNumber: pageNumber);
      },
    ),
  );

  if (canNavigate) {
    overlays.add(
      Positioned(
        left: 0,
        top: 0,
        width: sideWidth,
        height: size.height,
        child: PdfOverlayInteractionRegion(
          onTap: (_) {
            if (isTapSuppressed()) return true;
            if (readingDirection == ReadingDirection.horizontalRtl) {
              onNext();
            } else {
              onPrevious();
            }
            return true;
          },
          onDoubleTap: (details) => onDoubleTap(details.localPosition),
          child: const SizedBox.expand(),
        ),
      ),
    );
    overlays.add(
      Positioned(
        right: 0,
        top: 0,
        width: sideWidth,
        height: size.height,
        child: PdfOverlayInteractionRegion(
          onTap: (_) {
            if (isTapSuppressed()) return true;
            if (readingDirection == ReadingDirection.horizontalRtl) {
              onPrevious();
            } else {
              onNext();
            }
            return true;
          },
          onDoubleTap: (details) => onDoubleTap(details.localPosition),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }

  overlays.add(
    Positioned(
      left: canNavigate ? sideWidth : 0,
      top: 0,
      width: canNavigate ? centerWidth : size.width,
      height: size.height,
      child: PdfOverlayInteractionRegion(
        onTap: (_) {
          if (isTapSuppressed()) return true;
          onToggleChrome();
          return true;
        },
        onDoubleTap: (details) => onDoubleTap(details.localPosition),
        child: const SizedBox.expand(),
      ),
    ),
  );

  return overlays;
}

class _ScrollThumbLabel extends StatelessWidget {
  const _ScrollThumbLabel({required this.pageNumber});

  static const double _radius = 14;

  final int? pageNumber;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.inverseSurface,
      borderRadius: BorderRadius.circular(_radius),
      child: Center(
        child: Text(
          pageNumber?.toString() ?? '\u2013',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onInverseSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
