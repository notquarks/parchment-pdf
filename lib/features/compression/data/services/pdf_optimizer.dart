import 'package:flutter/foundation.dart';
import 'package:qpdf_optimizer/qpdf_optimizer.dart' as qpdf;

import '../models/compression_options.dart';
import 'compression_worker.dart';

enum PdfOptimizerStatus { completed, unavailable, cancelled }

class PdfOptimizerResult {
  final PdfOptimizerStatus status;
  final String? message;
  final int originalSize;
  final int compressedSize;
  final int imagesFound;
  final int imagesReplaced;
  final int imagesSkipped;
  final int imagesFailed;

  const PdfOptimizerResult({
    required this.status,
    this.message,
    this.originalSize = 0,
    this.compressedSize = 0,
    this.imagesFound = 0,
    this.imagesReplaced = 0,
    this.imagesSkipped = 0,
    this.imagesFailed = 0,
  });

  bool get wasCompleted => status == PdfOptimizerStatus.completed;
}

abstract class PdfOptimizer {
  Future<PdfOptimizerResult> optimize({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    CancellationToken? cancelToken,
  });
}

PdfOptimizer createPdfOptimizer() {
  return _QpdfFfiOptimizer();
}

class _QpdfFfiOptimizer implements PdfOptimizer {
  const _QpdfFfiOptimizer();

  @override
  Future<PdfOptimizerResult> optimize({
    required String inputPath,
    required String outputPath,
    required CompressionOptions options,
    CancellationToken? cancelToken,
  }) async {
    final nativeMode = switch (options.mode) {
      PdfCompressionMode.structural => qpdf.QpdfCompressionMode.structural,
      PdfCompressionMode.imageOptimized =>
        qpdf.QpdfCompressionMode.imageOptimized,
      PdfCompressionMode.extremeRaster =>
        qpdf.QpdfCompressionMode.extremeRaster,
    };

    final nativeOptions = qpdf.QpdfOptimizerOptions(
      mode: nativeMode,
      jpegQuality: options.quality.clamp(1, 100),
      targetDpi: options.dpiTarget > 0 ? options.dpiTarget : 144,
      dpiThreshold: options.dpiThreshold > 0 ? options.dpiThreshold : 180,
      downsampleImages: options.downscale,
      recompressJpeg: options.recompressJpeg,
      convertToGrayscale: options.convertToGrayscale,
      deduplicateImages: false,
      preserveTransparency: true,
    );

    debugPrint('[PDF-COMPRESS] nativeBuild=${const qpdf.QpdfOptimizer().buildId}');

    debugPrint(
      '[PDF-COMPRESS] START '
      'input=$inputPath '
      'output=$outputPath '
      'mode=${nativeOptions.mode.name} '
      'quality=${nativeOptions.jpegQuality} '
      'targetDpi=${nativeOptions.targetDpi} '
      'dpiThreshold=${nativeOptions.dpiThreshold} '
      'downsample=${nativeOptions.downsampleImages} '
      'recompressJpeg=${nativeOptions.recompressJpeg}',
    );

    final result = await const qpdf.QpdfOptimizer().optimizeV2(
      inputPath: inputPath,
      outputPath: outputPath,
      options: nativeOptions,
      isCancelled: () => cancelToken?.isCancelled ?? false,
    );

    debugPrint(
      '[PDF-COMPRESS] RESULT '
      'status=${result.status.name} '
      'pages=${result.pagesProcessed} '
      'imagesFound=${result.imagesFound} '
      'imagesReplaced=${result.imagesReplaced} '
      'imagesSkipped=${result.imagesSkipped} '
      'imagesFailed=${result.imagesFailed} '
      'imageBytes=${result.imageBytesBefore}->${result.imageBytesAfter} '
      'pdfBytes=${result.originalBytes}->${result.outputBytes} '
      'message=${result.message}',
    );

    switch (result.status) {
      case qpdf.QpdfOptimizerStatus.completed:
        return PdfOptimizerResult(
          status: PdfOptimizerStatus.completed,
          message: result.message,
          originalSize: result.originalBytes,
          compressedSize: result.outputBytes,
          imagesFound: result.imagesFound,
          imagesReplaced: result.imagesReplaced,
          imagesSkipped: result.imagesSkipped,
          imagesFailed: result.imagesFailed,
        );
      case qpdf.QpdfOptimizerStatus.unavailable:
        return PdfOptimizerResult(
          status: PdfOptimizerStatus.unavailable,
          message: result.message,
        );
      case qpdf.QpdfOptimizerStatus.cancelled:
        throw CancellationException();
      case qpdf.QpdfOptimizerStatus.failed:
        throw PdfOptimizerException(result.message ?? 'PDF optimizer failed');
    }
  }
}

class PdfOptimizerException implements Exception {
  final String message;

  const PdfOptimizerException(this.message);

  @override
  String toString() => message;
}
