import 'optimizer_stub.dart'
    if (dart.library.io) 'optimizer_native.dart'
    if (dart.library.js_interop) 'optimizer_stub.dart'
    as implementation;

enum QpdfOptimizerStatus { completed, unavailable, cancelled, failed }

class QpdfOptimizerResult {
  final QpdfOptimizerStatus status;
  final String? message;

  const QpdfOptimizerResult({required this.status, this.message});

  bool get wasCompleted => status == QpdfOptimizerStatus.completed;
}

/// Optimizes PDFs through qpdf on Windows and Android.
///
/// Cancellation is checked before and after native work. qpdf itself cannot be
/// forcefully interrupted; callers must discard a temporary output on cancel.
class QpdfOptimizer {
  const QpdfOptimizer();

  Future<QpdfOptimizerResult> optimize({
    required String inputPath,
    required String outputPath,
    required int quality,
    bool Function()? isCancelled,
  }) {
    return implementation.optimize(
      inputPath: inputPath,
      outputPath: outputPath,
      quality: quality,
      isCancelled: isCancelled,
    );
  }
}
