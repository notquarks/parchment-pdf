import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:qpdf_optimizer/qpdf_optimizer.dart';

void main() {
  final nativeSupported = Platform.isWindows || Platform.isAndroid;

  test('optimizes a PDF through the native FFI bridge', () async {
    final outputDirectory = await Directory.systemTemp.createTemp(
      'qpdf_optimizer_test_',
    );
    final input = File('${outputDirectory.path}/input.pdf');
    final output = File('${outputDirectory.path}/optimized.pdf');

    try {
      await _writePdf(input);
      final result = await const QpdfOptimizer().optimize(
        inputPath: input.absolute.path,
        outputPath: output.path,
        options: QpdfOptimizerOptions.fromQuality(75),
      );

      expect(result.status, QpdfOptimizerStatus.completed);
      expect(result.pagesProcessed, 1);
      expect(result.originalBytes, greaterThan(0));
      expect(result.outputBytes, greaterThan(0));
      expect(await output.exists(), isTrue);
      expect(await output.length(), greaterThan(0));
      final bytes = await output.readAsBytes();
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    } finally {
      if (await outputDirectory.exists()) {
        await outputDirectory.delete(recursive: true);
      }
    }
  }, skip: !nativeSupported);

  test('returns native qpdf diagnostics for an invalid PDF', () async {
    final outputDirectory = await Directory.systemTemp.createTemp(
      'qpdf_optimizer_error_test_',
    );
    final input = File('${outputDirectory.path}/invalid.pdf');
    final output = File('${outputDirectory.path}/optimized.pdf');

    try {
      await input.writeAsString('not a PDF');
      final result = await const QpdfOptimizer().optimize(
        inputPath: input.path,
        outputPath: output.path,
        options: const QpdfOptimizerOptions(),
      );

      expect(result.status, QpdfOptimizerStatus.failed);
      expect(result.message, contains(input.path));
    } finally {
      if (await outputDirectory.exists()) {
        await outputDirectory.delete(recursive: true);
      }
    }
  }, skip: !nativeSupported);

  test(
    'reports unavailable optimization on unsupported platforms',
    () async {
      final result = await const QpdfOptimizer().optimize(
        inputPath: 'input.pdf',
        outputPath: 'output.pdf',
        options: const QpdfOptimizerOptions(),
      );

      expect(result.status, QpdfOptimizerStatus.unavailable);
    },
    skip: nativeSupported,
  );
}

Future<void> _writePdf(File file) async {
  final document = pw.Document();
  document.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (context) => pw.Text('qpdf optimizer test'),
    ),
  );
  await file.writeAsBytes(await document.save());
}
