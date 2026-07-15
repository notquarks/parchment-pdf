import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ViewerZoomControl extends StatelessWidget {
  const ViewerZoomControl({
    super.key,
    required this.controller,
    required this.fitZoom,
    required this.onInteraction,
    this.compact = false,
  });

  static const double _gap = 2;
  static const double _labelWidth = 64;

  final PdfViewerController controller;
  final double fitZoom;
  final VoidCallback onInteraction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, child) {
        if (!controller.isReady) return const SizedBox.shrink();
        final percent = _relativePercent(controller.currentZoom, fitZoom);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Zoom out',
              onPressed: () {
                onInteraction();
                controller.zoomDown();
              },
              icon: const Icon(Icons.remove),
            ),
            if (!compact)
              SizedBox(
                width: _labelWidth,
                child: Text(
                  '$percent%',
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(width: _gap),
            IconButton(
              tooltip: 'Zoom in',
              onPressed: () {
                onInteraction();
                controller.zoomUp();
              },
              icon: const Icon(Icons.add),
            ),
            IconButton(
              tooltip: 'Reset zoom',
              onPressed: () {
                onInteraction();
                controller.setZoom(controller.centerPosition, fitZoom);
              },
              icon: const Icon(Icons.fit_screen_outlined),
            ),
          ],
        );
      },
    );
  }
}

class ViewerZoomHud extends StatelessWidget {
  const ViewerZoomHud({
    super.key,
    required this.controller,
    required this.fitZoom,
    required this.visible,
  });

  static const double _radius = 18;
  static const double _horizontalPadding = 12;
  static const double _verticalPadding = 8;
  static const int _animationMilliseconds = 160;

  final PdfViewerController controller;
  final double fitZoom;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: _animationMilliseconds),
        child: ListenableBuilder(
          listenable: controller,
          builder: (context, child) {
            if (!controller.isReady) return const SizedBox.shrink();
            final percent = _relativePercent(controller.currentZoom, fitZoom);
            return Material(
              color: Theme.of(context).colorScheme.inverseSurface,
              borderRadius: BorderRadius.circular(_radius),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _horizontalPadding,
                  vertical: _verticalPadding,
                ),
                child: Text(
                  '$percent%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

int _relativePercent(double zoom, double fitZoom) {
  if (fitZoom <= 0) return 100;
  return (zoom / fitZoom * 100).round();
}
