import 'package:qpdf_optimizer/qpdf_optimizer.dart' as qpdf;

import '../models/compression_options.dart';
import 'compression_worker.dart';

enum PdfOptimizerStatus { completed, unavailable, cancelled }

class PdfOptimizerResult {
  final PdfOptimizerStatus status;
  final String? message;
  final int originalSize;
  final int compressedSize;

  const PdfOptimizerResult({
    required this.status,
    this.message,
    this.originalSize = 0,
    this.compressedSize = 0,
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
    /* Map the existing CompressionOptions to v2 native options.
       Phase 2+ will make this richer; for now structural mode is
       the only supported path and imageOptimized is blocked at
       the service layer. */
    final nativeOptions = qpdf.QpdfOptimizerOptions(
      mode: qpdf.QpdfCompressionMode.structural,
      jpegQuality: options.quality,
      targetDpi: options.dpiTarget,
      dpiThreshold: options.dpiThreshold,
      downsampleImages: options.downscale,
      recompressJpeg: options.recompressJpeg,
      convertToGrayscale: options.convertToGrayscale,
      deduplicateImages: true,
      preserveTransparency: true,
    );

    final result = await const qpdf.QpdfOptimizer().optimizeV2(
      inputPath: inputPath,
      outputPath: outputPath,
      options: nativeOptions,
      isCancelled: () => cancelToken?.isCancelled ?? false,
    );

    switch (result.status) {
      case qpdf.QpdfOptimizerStatus.completed:
        return PdfOptimizerResult(
          status: PdfOptimizerStatus.completed,
          message: result.message,
          originalSize: result.originalBytes,
          compressedSize: result.outputBytes,
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
