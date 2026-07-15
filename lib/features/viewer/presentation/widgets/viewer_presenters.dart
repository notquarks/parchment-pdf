import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'color_matrix_utils.dart';
import 'viewer_navigation_panel.dart';
import 'viewer_tools_sheet.dart';

Future<void> showViewerNavigationSheet({
  required BuildContext context,
  required PdfDocument? document,
  required int pageCount,
  required int pageNumber,
  required List<PdfOutlineNode> outline,
  required PdfTextSearcher? textSearcher,
  required String searchQuery,
  required ViewerNavigationTab initialTab,
  required ValueChanged<int> onPageSelected,
  required ValueChanged<PdfDest?> onOutlineSelected,
  required ValueChanged<int> onSearchResultSelected,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) {
      return ViewerNavigationPanel(
        document: document,
        pageCount: pageCount,
        pageNumber: pageNumber,
        outline: outline,
        textSearcher: textSearcher,
        searchQuery: searchQuery,
        initialTab: initialTab,
        isSheet: true,
        onClose: () => Navigator.pop(sheetContext),
        onPageSelected: (page) {
          Navigator.pop(sheetContext);
          onPageSelected(page);
        },
        onOutlineSelected: (destination) {
          Navigator.pop(sheetContext);
          onOutlineSelected(destination);
        },
        onSearchResultSelected: (index) {
          Navigator.pop(sheetContext);
          onSearchResultSelected(index);
        },
      );
    },
  );
}

Future<void> showViewerTools({
  required BuildContext context,
  required bool expanded,
  required ReadingDirection readingDirection,
  required BackgroundTheme backgroundTheme,
  required ScaleType scaleType,
  required ViewerContentFilter contentFilter,
  required TapZoneMode tapZoneMode,
  required double brightness,
  required double contrast,
  required double saturation,
  required double pageSpacing,
  required bool showPageIndicator,
  required bool autoHideControls,
  required ValueChanged<ReadingDirection> onReadingDirectionChanged,
  required ValueChanged<BackgroundTheme> onBackgroundThemeChanged,
  required ValueChanged<ScaleType> onScaleTypeChanged,
  required ValueChanged<ViewerContentFilter> onContentFilterChanged,
  required ValueChanged<TapZoneMode> onTapZoneModeChanged,
  required ValueChanged<double> onBrightnessChanged,
  required ValueChanged<double> onContrastChanged,
  required ValueChanged<double> onSaturationChanged,
  required ValueChanged<double> onPageSpacingChanged,
  required ValueChanged<bool> onShowPageIndicatorChanged,
  required ValueChanged<bool> onAutoHideControlsChanged,
  required VoidCallback onResetAppearance,
}) {
  final tools = ViewerToolsSheet(
    readingDirection: readingDirection,
    backgroundTheme: backgroundTheme,
    scaleType: scaleType,
    contentFilter: contentFilter,
    tapZoneMode: tapZoneMode,
    brightness: brightness,
    contrast: contrast,
    saturation: saturation,
    pageSpacing: pageSpacing,
    showPageIndicator: showPageIndicator,
    autoHideControls: autoHideControls,
    onReadingDirectionChanged: onReadingDirectionChanged,
    onBackgroundThemeChanged: onBackgroundThemeChanged,
    onScaleTypeChanged: onScaleTypeChanged,
    onContentFilterChanged: onContentFilterChanged,
    onTapZoneModeChanged: onTapZoneModeChanged,
    onBrightnessChanged: onBrightnessChanged,
    onContrastChanged: onContrastChanged,
    onSaturationChanged: onSaturationChanged,
    onPageSpacingChanged: onPageSpacingChanged,
    onShowPageIndicatorChanged: onShowPageIndicatorChanged,
    onAutoHideControlsChanged: onAutoHideControlsChanged,
    onResetAppearance: onResetAppearance,
    isPanel: expanded,
  );

  if (expanded) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withAlpha(64),
      builder: (context) {
        return Align(
          alignment: Alignment.centerRight,
          child: Padding(padding: const EdgeInsets.all(12), child: tools),
        );
      },
    );
  }

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => tools,
  );
}
