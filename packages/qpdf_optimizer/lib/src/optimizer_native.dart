import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

import 'api.dart';

const _assetId = 'package:qpdf_optimizer/src/qpdf_optimizer_bindings.dart';

final class _NativeOptimizerOptions extends Struct {
  @Uint32()
  external int structSize;
  @Uint32()
  external int abiVersion;
  @Int32()
  external int mode;
  @Int32()
  external int jpegQuality;
  @Int32()
  external int targetDpi;
  @Int32()
  external int dpiThreshold;
  @Int32()
  external int minimumWidth;
  @Int32()
  external int minimumHeight;
  @Int64()
  external int minimumArea;
  @Int64()
  external int minimumStreamBytes;
  @Int32()
  external int downsampleImages;
  @Int32()
  external int recompressJpeg;
  @Int32()
  external int convertToGrayscale;
  @Int32()
  external int stripMetadata;
  @Int32()
  external int stripDocumentInfo;
  @Int32()
  external int removeUnusedResources;
  @Int32()
  external int preserveTransparency;
  @Int64()
  external int maximumDecodedPixels;
  @Int64()
  external int memoryBudgetBytes;
}

final class _NativeOptimizerResult extends Struct {
  @Uint32()
  external int structSize;
  @Uint32()
  external int abiVersion;
  @Int32()
  external int status;
  @Int32()
  external int warningCount;
  @Int32()
  external int pagesProcessed;
  @Int32()
  external int imagesFound;
  @Int32()
  external int imagesReplaced;
  @Int32()
  external int imagesSkipped;
  @Int32()
  external int imagesFailed;
  @Int64()
  external int originalBytes;
  @Int64()
  external int outputBytes;
  @Int64()
  external int imageBytesBefore;
  @Int64()
  external int imageBytesAfter;
  external Pointer<Utf8> message;
}

final class _Job extends Opaque {}

@Native<
  Pointer<_Job> Function(
    Pointer<Utf8>,
    Pointer<Utf8>,
    Pointer<_NativeOptimizerOptions>,
  )
>(assetId: _assetId, symbol: 'qpdf_optimizer_create_job')
external Pointer<_Job> _createJobNative(
  Pointer<Utf8> inputPath,
  Pointer<Utf8> outputPath,
  Pointer<_NativeOptimizerOptions> options,
);

@Native<Pointer<_NativeOptimizerResult> Function(Pointer<_Job>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_run',
)
external Pointer<_NativeOptimizerResult> _runNative(Pointer<_Job> job);

@Native<Void Function(Pointer<_Job>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_cancel',
)
external void _cancelNative(Pointer<_Job> job);

@Native<Int32 Function(Pointer<_Job>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_is_cancelled',
)
external int _isCancelledNative(Pointer<_Job> job);

@Native<Void Function(Pointer<_Job>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_destroy_job',
)
external void _destroyJobNative(Pointer<_Job> job);

@Native<Pointer<Utf8> Function()>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_build_id',
)
external Pointer<Utf8> _buildIdNative();

@Native<Void Function(Pointer<Utf8>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_free_string',
)
external void _freeNativeString(Pointer<Utf8> value);

const int _abiVersion = 3;

Pointer<_Job> createJob(
  String inputPath,
  String outputPath,
  QpdfOptimizerOptions options,
) {
  final input = inputPath.toNativeUtf8();
  final output = outputPath.toNativeUtf8();
  final opts = calloc<_NativeOptimizerOptions>();
  try {
    opts.ref.structSize = sizeOf<_NativeOptimizerOptions>();
    opts.ref.abiVersion = _abiVersion;
    opts.ref.mode = options.mode.index;
    opts.ref.jpegQuality = options.jpegQuality;
    opts.ref.targetDpi = options.targetDpi;
    opts.ref.dpiThreshold = options.dpiThreshold;
    opts.ref.minimumWidth = options.minimumWidth;
    opts.ref.minimumHeight = options.minimumHeight;
    opts.ref.minimumArea = options.minimumArea;
    opts.ref.minimumStreamBytes = options.minimumStreamBytes;
    opts.ref.downsampleImages = options.downsampleImages ? 1 : 0;
    opts.ref.recompressJpeg = options.recompressJpeg ? 1 : 0;
    opts.ref.convertToGrayscale = options.convertToGrayscale ? 1 : 0;
    opts.ref.stripMetadata = options.stripMetadata ? 1 : 0;
    opts.ref.stripDocumentInfo = options.stripDocumentInfo ? 1 : 0;
    opts.ref.removeUnusedResources = options.removeUnusedResources ? 1 : 0;
    opts.ref.preserveTransparency = options.preserveTransparency ? 1 : 0;
    opts.ref.maximumDecodedPixels = options.maximumDecodedPixels;
    opts.ref.memoryBudgetBytes = options.memoryBudgetBytes;

    return _createJobNative(input, output, opts);
  } finally {
    calloc.free(input);
    calloc.free(output);
    calloc.free(opts);
  }
}

QpdfOptimizerResult runJob(Pointer<_Job> job) {
  final resultPtr = _runNative(job);
  if (resultPtr == nullptr) {
    return const QpdfOptimizerResult(
      status: QpdfOptimizerStatus.failed,
      message: 'PDF optimizer returned no result',
    );
  }
  return _parseResult(resultPtr.ref);
}

void cancelJob(Pointer<_Job> job) {
  _cancelNative(job);
}

bool isJobCancelled(Pointer<_Job> job) {
  return _isCancelledNative(job) != 0;
}

void destroyJob(Pointer<_Job> job) {
  _destroyJobNative(job);
}

String buildId() {
  final ptr = _buildIdNative();
  return ptr == nullptr ? 'unknown' : ptr.toDartString();
}

Future<QpdfOptimizerResult> optimize({
  required String inputPath,
  required String outputPath,
  required QpdfOptimizerOptions options,
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

  Pointer<_Job> job;
  try {
    job = createJob(inputPath, outputPath, options);
  } on ArgumentError {
    return const QpdfOptimizerResult(
      status: QpdfOptimizerStatus.unavailable,
      message: 'PDF optimizer native library is not installed',
    );
  }
  if (job == nullptr) {
    return const QpdfOptimizerResult(
      status: QpdfOptimizerStatus.failed,
      message: 'Failed to create PDF optimizer job',
    );
  }

  Timer? cancellationTimer;
  if (isCancelled != null) {
    cancellationTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (isCancelled() && !isJobCancelled(job)) {
        cancelJob(job);
      }
    });
  }

  try {
    final address = job.address;
    return await Isolate.run(() => runJob(Pointer<_Job>.fromAddress(address)));
  } finally {
    cancellationTimer?.cancel();
    destroyJob(job);
  }
}

final class _Analysis extends Opaque {}

@Native<
  Pointer<_Analysis> Function(Pointer<Utf8>, Int32, Pointer<Pointer<Utf8>>)
>(assetId: _assetId, symbol: 'qpdf_optimizer_analyze')
external Pointer<_Analysis> _analyzeNative(
  Pointer<Utf8> inputPath,
  int dpiThreshold,
  Pointer<Pointer<Utf8>> errorMessage,
);

@Native<Int32 Function(Pointer<_Analysis>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_page_count',
)
external int _analysisPageCountNative(Pointer<_Analysis> a);

@Native<Int32 Function(Pointer<_Analysis>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_count',
)
external int _analysisImageCountNative(Pointer<_Analysis> a);

@Native<Int32 Function(Pointer<_Analysis>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_high_dpi_count',
)
external int _analysisHighDpiCountNative(Pointer<_Analysis> a);

@Native<Int64 Function(Pointer<_Analysis>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_total_image_bytes',
)
external int _analysisTotalImageBytesNative(Pointer<_Analysis> a);

@Native<Int32 Function(Pointer<_Analysis>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_is_encrypted',
)
external int _analysisIsEncryptedNative(Pointer<_Analysis> a);

@Native<Int32 Function(Pointer<_Analysis>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_has_signatures',
)
external int _analysisHasSignaturesNative(Pointer<_Analysis> a);

@Native<Int32 Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_object_number',
)
external int _analysisImageObjectNumberNative(Pointer<_Analysis> a, int index);

@Native<Int32 Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_width',
)
external int _analysisImageWidthNative(Pointer<_Analysis> a, int index);

@Native<Int32 Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_height',
)
external int _analysisImageHeightNative(Pointer<_Analysis> a, int index);

@Native<Double Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_max_dpi',
)
external double _analysisImageMaxDpiNative(Pointer<_Analysis> a, int index);

@Native<Int64 Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_encoded_bytes',
)
external int _analysisImageEncodedBytesNative(Pointer<_Analysis> a, int index);

@Native<Int32 Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_processable',
)
external int _analysisImageProcessableNative(Pointer<_Analysis> a, int index);

@Native<Pointer<Utf8> Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_color_space',
)
external Pointer<Utf8> _analysisImageColorSpaceNative(
  Pointer<_Analysis> a,
  int index,
);

@Native<Pointer<Utf8> Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_filter',
)
external Pointer<Utf8> _analysisImageFilterNative(
  Pointer<_Analysis> a,
  int index,
);

@Native<Int32 Function(Pointer<_Analysis>, Int32)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_analysis_image_has_smask',
)
external int _analysisImageHasSmaskNative(Pointer<_Analysis> a, int index);

@Native<Void Function(Pointer<_Analysis>)>(
  assetId: _assetId,
  symbol: 'qpdf_optimizer_destroy_analysis',
)
external void _destroyAnalysisNative(Pointer<_Analysis> a);

Pointer<_Analysis> _createNativeAnalysis(String inputPath, int dpiThreshold) {
  final input = inputPath.toNativeUtf8();
  final errorMessage = calloc<Pointer<Utf8>>();
  try {
    final result = _analyzeNative(input, dpiThreshold, errorMessage);
    if (result == nullptr) {
      final msg = errorMessage.value == nullptr
          ? null
          : errorMessage.value.toDartString();
      if (errorMessage.value != nullptr) _freeNativeString(errorMessage.value);
      throw Exception(msg ?? 'Analysis failed');
    }
    return result;
  } finally {
    calloc.free(input);
    calloc.free(errorMessage);
  }
}

QpdfAnalysisResult _readNativeAnalysis(Pointer<_Analysis> analysis) {
  final imageCount = _analysisImageCountNative(analysis);
  final images = <QpdfImageInfo>[];
  for (var i = 0; i < imageCount; i++) {
    images.add(
      QpdfImageInfo(
        objectNumber: _analysisImageObjectNumberNative(analysis, i),
        width: _analysisImageWidthNative(analysis, i),
        height: _analysisImageHeightNative(analysis, i),
        maxDpi: _analysisImageMaxDpiNative(analysis, i),
        encodedBytes: _analysisImageEncodedBytesNative(analysis, i),
        processable: _analysisImageProcessableNative(analysis, i) != 0,
        colorSpace: _analysisImageColorSpaceNative(analysis, i).toDartString(),
        filter: _analysisImageFilterNative(analysis, i).toDartString(),
        hasSmask: _analysisImageHasSmaskNative(analysis, i) != 0,
      ),
    );
  }

  return QpdfAnalysisResult(
    pageCount: _analysisPageCountNative(analysis),
    imageCount: imageCount,
    highDpiCount: _analysisHighDpiCountNative(analysis),
    totalImageBytes: _analysisTotalImageBytesNative(analysis),
    isEncrypted: _analysisIsEncryptedNative(analysis) != 0,
    hasSignatures: _analysisHasSignaturesNative(analysis) != 0,
    images: images,
  );
}

void _destroyNativeAnalysis(Pointer<_Analysis> analysis) {
  _destroyAnalysisNative(analysis);
}

Future<QpdfAnalysisResult> analyzePdf(
  String inputPath, {
  int dpiThreshold = 180,
}) async {
  if (!Platform.isWindows && !Platform.isAndroid) {
    throw UnsupportedError('PDF analysis is not available on this platform');
  }
  return Isolate.run(() {
    final analysis = _createNativeAnalysis(inputPath, dpiThreshold);
    try {
      return _readNativeAnalysis(analysis);
    } finally {
      _destroyNativeAnalysis(analysis);
    }
  });
}

QpdfOptimizerResult _parseResult(_NativeOptimizerResult native) {
  final message = native.message == nullptr
      ? null
      : native.message.toDartString();

  final status = switch (native.status) {
    0 => QpdfOptimizerStatus.completed,
    1 => QpdfOptimizerStatus.failed,
    2 => QpdfOptimizerStatus.failed,
    3 => QpdfOptimizerStatus.cancelled,
    4 => QpdfOptimizerStatus.failed,
    _ => QpdfOptimizerStatus.failed,
  };

  return QpdfOptimizerResult(
    status: status,
    message: message,
    warningCount: native.warningCount,
    pagesProcessed: native.pagesProcessed,
    imagesFound: native.imagesFound,
    imagesReplaced: native.imagesReplaced,
    imagesSkipped: native.imagesSkipped,
    imagesFailed: native.imagesFailed,
    originalBytes: native.originalBytes,
    outputBytes: native.outputBytes,
    imageBytesBefore: native.imageBytesBefore,
    imageBytesAfter: native.imageBytesAfter,
  );
}
