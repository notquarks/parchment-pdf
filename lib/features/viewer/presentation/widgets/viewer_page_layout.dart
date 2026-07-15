import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'viewer_tools_sheet.dart';

int? calculateHorizontalRtlPage(
  Rect visibleRect,
  List<Rect> pageRects,
  PdfViewerController controller,
) {
  int? bestPage;
  var bestVisibility = 0.0;

  for (var index = 0; index < pageRects.length; index++) {
    final rect = pageRects[index];
    if (rect.right <= visibleRect.left || rect.left >= visibleRect.right) {
      continue;
    }
    final left = max(rect.left, visibleRect.left);
    final right = min(rect.right, visibleRect.right);
    final visibility = (right - left) / rect.width;
    if (visibility > bestVisibility) {
      bestVisibility = visibility;
      bestPage = index + 1;
    }
  }

  return bestPage;
}

PdfPageLayout layoutHorizontalPages(
  List<PdfPage> pages,
  PdfViewerParams params, {
  required ReadingDirection readingDirection,
}) {
  final height =
      pages.fold<double>(0, (value, page) => max(value, page.height)) +
      params.margin * 2;
  final pageLayouts = <Rect>[];
  var x = params.margin;

  for (final page in pages) {
    pageLayouts.add(
      Rect.fromLTWH(x, (height - page.height) / 2, page.width, page.height),
    );
    x += page.width + params.margin;
  }

  final width = x;
  if (readingDirection == ReadingDirection.horizontalRtl) {
    for (var index = 0; index < pageLayouts.length; index++) {
      final rect = pageLayouts[index];
      pageLayouts[index] = Rect.fromLTWH(
        width - rect.left - rect.width,
        rect.top,
        rect.width,
        rect.height,
      );
    }
  }

  return PdfPageLayout(
    pageLayouts: pageLayouts,
    documentSize: Size(width, height),
  );
}
