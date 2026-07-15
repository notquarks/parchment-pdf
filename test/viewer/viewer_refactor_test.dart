import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tools/features/viewer/presentation/widgets/viewer_navigation_panel.dart';
import 'package:pdf_tools/features/viewer/presentation/widgets/viewer_page_layout.dart';
import 'package:pdf_tools/features/viewer/presentation/widgets/viewer_scaffold.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  test('horizontal page calculation chooses the most visible page', () {
    final controller = PdfViewerController();
    final page = calculateHorizontalRtlPage(
      const Rect.fromLTWH(80, 0, 100, 100),
      const [
        Rect.fromLTWH(0, 0, 100, 100),
        Rect.fromLTWH(110, 0, 100, 100),
      ],
      controller,
    );

    expect(page, 2);
  });

  testWidgets('viewer scaffold reports compact and expanded layouts', (
    tester,
  ) async {
    Future<void> pumpAtWidth(double width) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      return tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: Size(width, 800)),
            child: SizedBox(
              height: 800,
              child: ViewerScaffold(
                backgroundColor: Colors.black,
                searchVisible: false,
                navigationVisible: false,
                navigationTab: ViewerNavigationTab.thumbnails,
                document: null,
                pageCount: 0,
                pageNumber: 1,
                outline: const [],
                textSearcher: null,
                searchQuery: '',
                shortcutBindings: const {},
                onBackRequest: () {},
                onCloseNavigation: () {},
                onPageSelected: (_) {},
                onOutlineSelected: (_) {},
                onSearchResultSelected: (_) {},
                viewerBuilder: (compact, expanded) {
                  return Text('$compact/$expanded');
                },
              ),
            ),
          ),
        ),
      );
    }

    await pumpAtWidth(500);
    expect(find.text('true/false'), findsOneWidget);

    await pumpAtWidth(1200);
    expect(find.text('false/true'), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  });
}
