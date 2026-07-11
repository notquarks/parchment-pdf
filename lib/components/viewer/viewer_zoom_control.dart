import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

class ViewerZoomControl extends StatelessWidget {
  const ViewerZoomControl({
    super.key,
    required this.controller,
    required this.fitZoom,
    required this.onZoomActiveChanged,
    required this.onStartHideTimer,
    required this.onCancelHideTimer,
  });

  final PdfViewerController controller;
  final double fitZoom;
  final ValueChanged<bool> onZoomActiveChanged;
  final VoidCallback onStartHideTimer;
  final VoidCallback onCancelHideTimer;

  Offset _getZoomAnchor() {
    if (controller.isReady) {
      final layout = controller.layout;
      final idx = controller.pageNumber! - 1;
      if (idx >= 0 && idx < layout.pageLayouts.length) {
        return layout.pageLayouts[idx].center;
      }
    }
    return controller.centerPosition;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, child) {
          if (!controller.isReady) {
            return const SizedBox.shrink();
          }
          final zoom = controller.value.zoom;
          final relativePercent = ((zoom / fitZoom - 1) * 100).round();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$relativePercent%'),
              IconButton(
                onPressed: () {
                  onZoomActiveChanged(true);
                  final newPercent = (relativePercent + 10).clamp(-50, 200);
                  final newZoom = (newPercent / 100 + 1) * fitZoom;
                  controller.setZoom(_getZoomAnchor(), newZoom);
                  onStartHideTimer();
                },
                icon: const Icon(Icons.zoom_in),
              ),
              RotatedBox(
                quarterTurns: 3,
                child: SizedBox(
                  width: 150,
                  child: Slider(
                    value: relativePercent.toDouble().clamp(-50, 200),
                    min: -50,
                    max: 200,
                    onChangeStart: (_) {
                      onCancelHideTimer();
                      onZoomActiveChanged(true);
                    },
                    onChangeEnd: (_) {
                      onStartHideTimer();
                    },
                    onChanged: (newPercent) {
                      final newZoom = (newPercent / 100 + 1) * fitZoom;
                      controller.setZoom(_getZoomAnchor(), newZoom);
                    },
                  ),
                ),
              ),
              IconButton(
                onPressed: () {
                  onZoomActiveChanged(true);
                  final newPercent = (relativePercent - 10).clamp(-50, 200);
                  final newZoom = (newPercent / 100 + 1) * fitZoom;
                  controller.setZoom(_getZoomAnchor(), newZoom);
                  onStartHideTimer();
                },
                icon: const Icon(Icons.zoom_out),
              ),
              IconButton(
                onPressed: () {
                  onZoomActiveChanged(true);
                  controller.setZoom(_getZoomAnchor(), fitZoom);
                  onStartHideTimer();
                },
                icon: const Icon(Icons.settings_backup_restore_outlined),
              ),
            ],
          );
        },
      ),
    );
  }
}
