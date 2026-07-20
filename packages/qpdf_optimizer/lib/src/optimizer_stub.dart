import 'api.dart';

Future<QpdfOptimizerResult> optimize({
  required String inputPath,
  required String outputPath,
  required int quality,
  bool Function()? isCancelled,
}) async {
  if (isCancelled?.call() == true) {
    return const QpdfOptimizerResult(status: QpdfOptimizerStatus.cancelled);
  }

  return const QpdfOptimizerResult(
    status: QpdfOptimizerStatus.unavailable,
    message: 'PDF optimization is not available on this platform',
  );
}
