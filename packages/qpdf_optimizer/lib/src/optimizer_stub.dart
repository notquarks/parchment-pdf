import 'api.dart';

String buildId() => 'unavailable';

Future<QpdfOptimizerResult> optimize({
  required String inputPath,
  required String outputPath,
  required QpdfOptimizerOptions options,
  bool Function()? isCancelled,
}) async {
  return const QpdfOptimizerResult(
    status: QpdfOptimizerStatus.unavailable,
    message: 'PDF optimization is not available on this platform',
  );
}

Future<QpdfAnalysisResult> analyzePdf(
  String inputPath, {
  int dpiThreshold = 180,
}) async {
  throw UnsupportedError('PDF analysis is not available on this platform');
}
