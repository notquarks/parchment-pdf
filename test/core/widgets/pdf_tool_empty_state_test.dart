import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tools/core/widgets/pdf_tool_empty_state.dart';

void main() {
  testWidgets('renders its content and invokes the primary action', (
    tester,
  ) async {
    var actionCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PdfToolEmptyState(
            icon: Icons.merge,
            title: 'Merge PDF files',
            description: 'Choose files to merge.',
            actionIcon: Icons.playlist_add,
            actionLabel: 'Choose PDF files',
            onAction: () => actionCount++,
          ),
        ),
      ),
    );

    expect(find.text('Merge PDF files'), findsOneWidget);
    expect(find.text('Choose files to merge.'), findsOneWidget);
    expect(find.byIcon(Icons.merge), findsOneWidget);
    expect(find.byIcon(Icons.playlist_add), findsOneWidget);

    await tester.tap(find.text('Choose PDF files'));
    expect(actionCount, 1);
  });
}
