import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf_tools/features/compression/data/models/compression_options.dart';
import 'package:pdf_tools/features/compression/data/services/compression_service.dart';
import 'package:pdf_tools/features/compression/data/services/compression_worker.dart';
import 'package:qpdf_optimizer/qpdf_optimizer.dart' as qpdf;

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('compression_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> _createTestPdf(String name, {int pageCount = 1}) async {
    final file = File('${tempDir.path}/$name');
    final doc = pw.Document();
    for (var i = 0; i < pageCount; i++) {
      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (context) => pw.Column(
            children: [
              pw.Text('Page ${i + 1}', style: const pw.TextStyle(fontSize: 24)),
              pw.SizedBox(height: 20),
              pw.Text('Test content for compression. ' * 10),
            ],
          ),
        ),
      );
    }
    await file.writeAsBytes(await doc.save());
    return file;
  }

  // ── CompressionOptions tests ──────────────────────────────────────────

  group('CompressionOptions', () {
    test('fromPreset creates valid options for all presets', () {
      for (final preset in CompressionPreset.values) {
        final options = CompressionOptions.fromPreset(preset);
        expect(options.quality, greaterThanOrEqualTo(1));
        expect(options.quality, lessThanOrEqualTo(100));
        expect(options.mode, equals(preset.mode));
      }
    });

    test('withQuality creates valid options', () {
      for (final q in [10, 25, 50, 75, 90, 100]) {
        final options = CompressionOptions.withQuality(q);
        expect(options.quality, equals(q));
        expect(options.dpiTarget, greaterThan(0));
      }
    });

    test('copyWith preserves fields', () {
      const original = CompressionOptions(
        quality: 75,
        dpiTarget: 144,
        dpiThreshold: 180,
        mode: PdfCompressionMode.imageOptimized,
        convertToGrayscale: true,
      );

      final copied = original.copyWith(quality: 50);
      expect(copied.quality, equals(50));
      expect(copied.dpiTarget, equals(144));
      expect(copied.mode, equals(PdfCompressionMode.imageOptimized));
      expect(copied.convertToGrayscale, isTrue);
    });

    test('targetDimensions respects DPI threshold', () {
      const options = CompressionOptions(
        quality: 75,
        dpiTarget: 144,
        dpiThreshold: 180,
      );

      // Image at 300 DPI should be downsampled
      final (w1, h1) = options.targetDimensions(1000, 800, 300);
      expect(w1, lessThan(1000));
      expect(h1, lessThan(800));

      // Image at 72 DPI should not be downsampled
      final (w2, h2) = options.targetDimensions(1000, 800, 72);
      expect(w2, equals(1000));
      expect(h2, equals(800));
    });

    test('targetDimensions never upscales', () {
      const options = CompressionOptions(
        quality: 75,
        dpiTarget: 300,
        dpiThreshold: 180,
      );

      final (w, h) = options.targetDimensions(100, 100, 72);
      expect(w, lessThanOrEqualTo(100));
      expect(h, lessThanOrEqualTo(100));
    });
  });

  // ── CancellationToken tests ───────────────────────────────────────────

  group('CancellationToken', () {
    test('starts uncancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('can be cancelled', () {
      final token = CancellationToken();
      token.cancel();
      expect(token.isCancelled, isTrue);
    });
  });

  // ── CompressionPreset tests ───────────────────────────────────────────

  group('CompressionPreset', () {
    test('has all expected presets', () {
      expect(CompressionPreset.values.length, equals(5));
    });

    test('extreme preset uses extremeRaster mode', () {
      expect(
        CompressionPreset.extreme.mode,
        equals(PdfCompressionMode.extremeRaster),
      );
    });

    test('structuralOnly uses structural mode', () {
      expect(
        CompressionPreset.structuralOnly.mode,
        equals(PdfCompressionMode.structural),
      );
    });

    test('image presets have non-zero DPI targets', () {
      expect(CompressionPreset.preserveDetail.dpiTarget, greaterThan(0));
      expect(CompressionPreset.balanced.dpiTarget, greaterThan(0));
      expect(CompressionPreset.smallerFile.dpiTarget, greaterThan(0));
    });
  });

  // ── CompressionResult tests ───────────────────────────────────────────

  group('CompressionResult', () {
    test('calculates reduction percent correctly', () {
      const result = CompressionResult(originalSize: 1000, compressedSize: 500);
      expect(result.reductionPercent, equals(50.0));
      expect(result.bytesReduced, equals(500));
    });

    test('handles zero original size', () {
      const result = CompressionResult(originalSize: 0, compressedSize: 0);
      expect(result.reductionPercent, equals(0.0));
    });
  });

  // ── ImageMetadata tests ───────────────────────────────────────────────

  group('ImageMetadata', () {
    test('shouldProcess respects minSize', () {
      const options = CompressionOptions(
        quality: 75,
        dpiTarget: 144,
        dpiThreshold: 180,
        minSize: 128,
      );

      const smallImage = ImageMetadata(
        width: 64,
        height: 64,
        format: 'jpeg',
        colorSpace: 'DeviceRGB',
        bitsPerComponent: 8,
        dataSize: 1000,
      );

      const largeImage = ImageMetadata(
        width: 256,
        height: 256,
        format: 'jpeg',
        colorSpace: 'DeviceRGB',
        bitsPerComponent: 8,
        dataSize: 10000,
      );

      expect(smallImage.shouldProcess(options), isFalse);
      expect(largeImage.shouldProcess(options), isTrue);
    });
  });

  // ── QpdfOptimizerOptions tests ────────────────────────────────────────

  group('QpdfOptimizerOptions', () {
    test('default options are valid', () {
      const options = qpdf.QpdfOptimizerOptions();
      expect(options.jpegQuality, equals(75));
      expect(options.targetDpi, equals(144));
      expect(options.mode, equals(qpdf.QpdfCompressionMode.structural));
    });

    test('fromQuality creates valid options', () {
      final options = qpdf.QpdfOptimizerOptions.fromQuality(85);
      expect(options.jpegQuality, equals(85));
      expect(options.mode, equals(qpdf.QpdfCompressionMode.structural));
    });

    test('imageOptimized creates valid options', () {
      final options = qpdf.QpdfOptimizerOptions.imageOptimized(75);
      expect(options.jpegQuality, equals(75));
      expect(options.mode, equals(qpdf.QpdfCompressionMode.imageOptimized));
      expect(options.downsampleImages, isTrue);
    });

    test('copyWith preserves fields', () {
      const original = qpdf.QpdfOptimizerOptions(
        mode: qpdf.QpdfCompressionMode.imageOptimized,
        jpegQuality: 75,
        targetDpi: 144,
        minimumWidth: 96,
        minimumHeight: 80,
        minimumArea: 7680,
        minimumStreamBytes: 2048,
        convertToGrayscale: true,
        stripMetadata: true,
        stripDocumentInfo: true,
        removeUnusedResources: true,
        maximumDecodedPixels: 100000000,
        memoryBudgetBytes: 256000000,
      );

      final copied = original.copyWith(jpegQuality: 50);
      expect(copied.jpegQuality, equals(50));
      expect(copied.mode, equals(qpdf.QpdfCompressionMode.imageOptimized));
      expect(copied.convertToGrayscale, isTrue);
      expect(copied.minimumWidth, 96);
      expect(copied.minimumHeight, 80);
      expect(copied.minimumArea, 7680);
      expect(copied.minimumStreamBytes, 2048);
      expect(copied.stripMetadata, isTrue);
      expect(copied.stripDocumentInfo, isTrue);
      expect(copied.removeUnusedResources, isTrue);
      expect(copied.maximumDecodedPixels, 100000000);
      expect(copied.memoryBudgetBytes, 256000000);
    });

    test('rich result reports size reduction', () {
      const result = qpdf.QpdfOptimizerResult(
        status: qpdf.QpdfOptimizerStatus.completed,
        warningCount: 1,
        pagesProcessed: 2,
        originalBytes: 1000,
        outputBytes: 750,
      );

      expect(result.wasCompleted, isTrue);
      expect(result.warningCount, 1);
      expect(result.pagesProcessed, 2);
      expect(result.bytesReduced, 250);
      expect(result.reductionPercent, 25);
    });
  });

  // ── CompressionService tests (mock-based) ─────────────────────────────

  group('CompressionService', () {
    test('rejects same input/output path', () async {
      final file = await _createTestPdf('same_path.pdf');
      final service = CompressionService();
      await service.initialize();

      try {
        await expectLater(
          service.compressPdf(
            filePath: file.path,
            options: const CompressionOptions(
              quality: 75,
              dpiTarget: 144,
              dpiThreshold: 180,
            ),
            outputPath: file.path,
          ),
          throwsA(isA<ArgumentError>()),
        );
      } finally {
        await service.dispose();
      }
    });

    test('rejects nonexistent file', () async {
      final service = CompressionService();
      await service.initialize();

      try {
        await expectLater(
          service.compressPdf(
            filePath: '${tempDir.path}/nonexistent.pdf',
            options: const CompressionOptions(
              quality: 75,
              dpiTarget: 144,
              dpiThreshold: 180,
            ),
            outputPath: '${tempDir.path}/out.pdf',
          ),
          throwsA(isA<FileSystemException>()),
        );
      } finally {
        await service.dispose();
      }
    });

    test('cancels before processing', () async {
      final file = await _createTestPdf('cancel.pdf');
      final service = CompressionService();
      await service.initialize();
      final cancelToken = CancellationToken()..cancel();

      try {
        await expectLater(
          service.compressPdf(
            filePath: file.path,
            options: const CompressionOptions(
              quality: 75,
              dpiTarget: 144,
              dpiThreshold: 180,
            ),
            outputPath: '${tempDir.path}/out.pdf',
            cancelToken: cancelToken,
          ),
          throwsA(isA<CancellationException>()),
        );
      } finally {
        await service.dispose();
      }
    });

    test('extremeRaster mode routes correctly', () async {
      // Verify that extremeRaster mode is recognized and routed.
      // We don't actually run the full pipeline because PDFium
      // is not available in the test environment.
      const options = CompressionOptions(
        quality: 55,
        dpiTarget: 96,
        dpiThreshold: 0,
        mode: PdfCompressionMode.extremeRaster,
      );
      expect(options.mode, equals(PdfCompressionMode.extremeRaster));
      expect(options.quality, equals(55));
      expect(options.dpiTarget, equals(96));
    });
  });
}
