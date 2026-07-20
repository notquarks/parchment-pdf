import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tools/features/compression/data/models/task_messages.dart';
import 'package:pdf_tools/features/home/data/models/recent_file.dart';
import 'package:pdf_tools/features/home/data/services/recent_files_service.dart';
import 'package:pdf_tools/features/home/presentation/providers/recent_files_provider.dart';
import 'package:pdf_tools/features/result/presentation/screens/result_screen.dart';

void main() {
  group('TaskMessages', () {
    test('split has correct messages', () {
      const m = TaskMessages.split;
      expect(m.title, 'Split');
      expect(m.progress, 'Splitting…');
      expect(m.success, 'Successfully Split!');
      expect(m.failure, 'Split failed');
    });

    test('merge has correct messages', () {
      const m = TaskMessages.merge;
      expect(m.title, 'Merge');
      expect(m.progress, 'Merging…');
      expect(m.success, 'Successfully Merged!');
      expect(m.failure, 'Merge failed');
    });

    test('compress has correct messages', () {
      const m = TaskMessages.compress;
      expect(m.title, 'Compress');
      expect(m.progress, 'Compressing…');
      expect(m.success, 'Successfully Compressed!');
      expect(m.failure, 'Compress failed');
    });

    test('failure defaults to title-based string', () {
      const m = TaskMessages(
        title: 'Rotate',
        progress: 'Rotating…',
        success: 'Successfully Rotated!',
      );
      expect(m.failure, 'Rotate failed');
    });
  });

  testWidgets('records every compressed output separately', (tester) async {
    final recentFiles = _FakeRecentFilesService();
    final results = Completer<List<String>>();

    await tester.pumpWidget(
      MaterialApp(
        home: RecentFilesProvider(
          service: recentFiles,
          child: ResultScreen(
            messages: TaskMessages.compress,
            fileCount: 3,
            mergeMultiFuture: results.future,
          ),
        ),
      ),
    );

    results.complete(['/tmp/first.pdf', '/tmp/second.pdf']);
    await tester.pump();
    await tester.pump();

    expect(recentFiles.files, hasLength(2));
    expect(
      recentFiles.files.map((file) => file.filePath),
      containsAll(['/tmp/first.pdf', '/tmp/second.pdf']),
    );
    expect(
      recentFiles.files.every(
        (file) => file.operationType == 'compress' && file.inputFileCount == 1,
      ),
      isTrue,
    );
  });

  testWidgets('does not record unchanged compressed files', (tester) async {
    final recentFiles = _FakeRecentFilesService();

    await tester.pumpWidget(
      MaterialApp(
        home: RecentFilesProvider(
          service: recentFiles,
          child: ResultScreen(
            messages: TaskMessages.compress,
            fileCount: 2,
            mergeMultiFuture: Future.value([]),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(recentFiles.files, isEmpty);
  });
}

class _FakeRecentFilesService extends RecentFilesService {
  final List<RecentFile> files = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> addRecentFile(RecentFile file) async {
    files.add(file);
    notifyListeners();
  }
}
