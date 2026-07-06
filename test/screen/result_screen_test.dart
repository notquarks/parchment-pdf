import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_tools/model/task_messages.dart';

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
}
