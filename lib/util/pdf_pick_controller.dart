import 'package:pdf_tools/util/pdf.dart';

class PdfPickController {
  PdfPickController({
    required this.isMounted,
    required this.onEvent,
    required this.onError,
  });

  final bool Function() isMounted;
  final void Function(PdfFileEvent event) onEvent;
  final void Function(String message) onError;

  int _pickGeneration = 0;

  Future<void> pickAndProcess({
    bool allowMultiple = false,
    String failurePrefix = 'Failed to load files',
  }) async {
    if (!isMounted()) return;
    try {
      final files = await pickPdfFiles(allowMultiple: allowMultiple);
      if (!isMounted() || files.isEmpty) return;
      final generation = ++_pickGeneration;
      await for (final event in processPdfFilesStream(files)) {
        if (!isMounted() || _pickGeneration != generation) return;
        onEvent(event);
      }
    } catch (e) {
      if (!isMounted()) return;
      onError('$failurePrefix: $e');
    }
  }
}
