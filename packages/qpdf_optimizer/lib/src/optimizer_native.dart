import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'api.dart';

const _assetId = 'package:qpdf_optimizer/src/qpdf_optimizer_bindings.dart';

@Native<
  Int Function(Pointer<Utf8>, Pointer<Utf8>, Int, Pointer<Pointer<Utf8>>)
>(assetId: _assetId, symbol: 'qpdf_optimizer_optimize')
external int _optimizeNative(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputPath,
  int quality,
  Pointer<Pointer<Utf8>> errorMessage,
);

@Native<Void Function(Pointer<Utf8>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_free_string',
)
external void _freeNativeString(Pointer<Utf8> value);

Future<QpdfOptimizerResult> optimize({
  required String inputPath,
  required String outputPath,
  required int quality,
  bool Function()? isCancelled,
}) async {
  if (isCancelled?.call() == true) {
    return const QpdfOptimizerResult(status: QpdfOptimizerStatus.cancelled);
  }
  if (!Platform.isWindows && !Platform.isAndroid) {
    return const QpdfOptimizerResult(
      status: QpdfOptimizerStatus.unavailable,
      message: 'PDF optimization is not available on this platform',
    );
  }
  if (quality < 1 || quality > 100) {
    return const QpdfOptimizerResult(
      status: QpdfOptimizerStatus.failed,
      message: 'JPEG quality must be between 1 and 100',
    );
  }

  final result = await Isolate.run(
    () => _runNativeOptimization(
      inputPath: inputPath,
      outputPath: outputPath,
      quality: quality,
    ),
  );
  if (isCancelled?.call() == true) {
    return const QpdfOptimizerResult(status: QpdfOptimizerStatus.cancelled);
  }
  return result;
}

QpdfOptimizerResult _runNativeOptimization({
  required String inputPath,
  required String outputPath,
  required int quality,
}) {
  final input = inputPath.toNativeUtf8();
  final output = outputPath.toNativeUtf8();
  final errorMessage = calloc<Pointer<Utf8>>();

  try {
    final status = _optimizeNative(input, output, quality, errorMessage);
    final message = errorMessage.value == nullptr
        ? null
        : errorMessage.value.toDartString();
    if (errorMessage.value != nullptr) {
      _freeNativeString(errorMessage.value);
    }

    return switch (status) {
      0 => QpdfOptimizerResult(
        status: QpdfOptimizerStatus.completed,
        message: message,
      ),
      1 => QpdfOptimizerResult(
        status: QpdfOptimizerStatus.failed,
        message: message ?? 'Invalid PDF optimizer arguments',
      ),
      _ => QpdfOptimizerResult(
        status: QpdfOptimizerStatus.failed,
        message: message ?? 'PDF optimizer failed',
      ),
    };
  } on ArgumentError {
    return const QpdfOptimizerResult(
      status: QpdfOptimizerStatus.unavailable,
      message: 'PDF optimizer native library is not installed',
    );
  } finally {
    calloc.free(input);
    calloc.free(output);
    calloc.free(errorMessage);
  }
}
