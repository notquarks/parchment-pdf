import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_tools/features/compression/compression.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pdf_tools_test_');
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('keeps the original when the optimized PDF is not smaller', () async {
    final inputFile = File('${directory.path}/input.pdf');
    final outputFile = File('${directory.path}/output.pdf');
    await _writePdf(inputFile, 'This is the original PDF content.');

    final service = CompressionService(
      optimizer: _TestPdfOptimizer((inputPath, outputPath) async {
        final input = await File(inputPath).readAsBytes();
        final bytes = Uint8List(input.length + 100);
        bytes.setAll(0, input);
        await File(outputPath).writeAsBytes(bytes);
      }),
    );

    final result = await service.compressPdf(
      filePath: inputFile.path,
      outputPath: outputFile.path,
      options: CompressionOptions.withQuality(75),
    );

    expect(result.wasCompressed, isFalse);
    expect(await outputFile.exists(), isFalse);
    expect(await File('${outputFile.path}.tmp').exists(), isFalse);

    await service.dispose();
  });

  test('saves a valid smaller optimized PDF', () async {
    final inputFile = File('${directory.path}/input.pdf');
    final outputFile = File('${directory.path}/output.pdf');
    await _writePdf(
      inputFile,
      'This is the original PDF content.',
      padding: 1000,
    );

    final service = CompressionService(
      optimizer: _TestPdfOptimizer((inputPath, outputPath) async {
        await _writePdf(File(outputPath), 'Small PDF');
      }),
    );

    final result = await service.compressPdf(
      filePath: inputFile.path,
      outputPath: outputFile.path,
      options: CompressionOptions.withQuality(75),
    );

    expect(result.wasCompressed, isTrue);
    expect(result.outputPath, outputFile.path);
    expect(await outputFile.exists(), isTrue);
    expect(await File('${outputFile.path}.tmp').exists(), isFalse);

    await service.dispose();
  });

  test('reports an unavailable optimizer without publishing output', () async {
    final inputFile = File('${directory.path}/input.pdf');
    final outputFile = File('${directory.path}/output.pdf');
    await _writePdf(inputFile, 'Input PDF');

    final service = CompressionService(
      optimizer: _UnavailablePdfOptimizer(),
    );

    await expectLater(
      service.compressPdf(
        filePath: inputFile.path,
        outputPath: outputFile.path,
        options: CompressionOptions.withQuality(75),
      ),
      throwsA(isA<PdfOptimizerException>()),
    );
    expect(await outputFile.exists(), isFalse);
    expect(await File('${outputFile.path}.tmp').exists(), isFalse);

    await service.dispose();
  });

  test('cancels before optimizer work starts', () async {
    final inputFile = File('${directory.path}/input.pdf');
    final outputFile = File('${directory.path}/output.pdf');
    await _writePdf(inputFile, 'Input PDF');
    final cancelToken = CancellationToken()..cancel();
    var wasCalled = false;

    final service = CompressionService(
      optimizer: _TestPdfOptimizer((inputPath, outputPath) async {
        wasCalled = true;
      }),
    );

    await expectLater(
      service.compressPdf(
        filePath: inputFile.path,
        outputPath: outputFile.path,
        options: CompressionOptions.withQuality(75),
        cancelToken: cancelToken,
      ),
      throwsA(isA<CancellationException>()),
    );
    expect(wasCalled, isFalse);
    expect(await outputFile.exists(), isFalse);

    await service.dispose();
  });
}

class _TestPdfOptimizer implements PdfOptimizer {
  final Future<void> Function(String inputPath, String outputPath) _writeFile;

  const _TestPdfOptimizer(this._writeFile);

  @override
  Future<PdfOptimizerResult> optimize({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    CancellationToken? cancelToken,
  }) async {
    await _writeFile(inputPath, outputPath);
    return const PdfOptimizerResult(status: PdfOptimizerStatus.completed);
  }
}

class _UnavailablePdfOptimizer implements PdfOptimizer {
  @override
  Future<PdfOptimizerResult> optimize({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    CancellationToken? cancelToken,
  }) async {
    return const PdfOptimizerResult(
      status: PdfOptimizerStatus.unavailable,
      message: 'PDF optimizer is not installed',
    );
  }
}

Future<void> _writePdf(File file, String text, {int padding = 0}) async {
  final document = pw.Document();
  document.addPage(
    pw.Page(pageFormat: PdfPageFormat.a4, build: (context) => pw.Text(text)),
  );
  final bytes = await document.save();
  final output = Uint8List(bytes.length + padding);
  output.setAll(0, bytes);
  for (var i = bytes.length; i < output.length; i++) {
    output[i] = 32;
  }
  await file.writeAsBytes(output);
}
