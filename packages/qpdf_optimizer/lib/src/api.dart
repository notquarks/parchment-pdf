import 'optimizer_stub.dart'
    if (dart.library.io) 'optimizer_native.dart'
    if (dart.library.js_interop) 'optimizer_stub.dart'
    as implementation;

// ─── Status enum (shared by v1 and v2) ─────────────────────────────────────

enum QpdfOptimizerStatus { completed, unavailable, cancelled, failed }

// ─── Compression mode ───────────────────────────────────────────────────────

enum QpdfCompressionMode {
  /// Lossless structural optimization only (Flate recompression,
  /// object streams, deduplication). No image resampling.
  structural,

  /// Content-preserving image optimization: downsample high-DPI images,
  /// recompress JPEG, convert color spaces where safe. Text, links,
  /// forms, and vectors remain intact.
  imageOptimized,

  /// Full-page raster mode: render each page to a bitmap and replace
  /// content. Maximum compression but destroys text selectability and
  /// forms.
  extremeRaster,
}

// ─── V1 result (backward-compatible) ────────────────────────────────────────

class QpdfOptimizerResult {
  final QpdfOptimizerStatus status;
  final String? message;

  const QpdfOptimizerResult({required this.status, this.message});

  bool get wasCompleted => status == QpdfOptimizerStatus.completed;
}

// ─── V2 options ─────────────────────────────────────────────────────────────

class QpdfOptimizerOptions {
  final QpdfCompressionMode mode;
  final int jpegQuality;
  final int targetDpi;
  final int dpiThreshold;
  final int minimumWidth;
  final int minimumHeight;
  final int minimumArea;
  final int minimumStreamBytes;
  final bool downsampleImages;
  final bool recompressJpeg;
  final bool convertToGrayscale;
  final bool stripMetadata;
  final bool stripDocumentInfo;
  final bool removeUnusedResources;
  final bool deduplicateImages;
  final bool preserveTransparency;
  final int maximumDecodedPixels;
  final int memoryBudgetBytes;

  const QpdfOptimizerOptions({
    this.mode = QpdfCompressionMode.structural,
    this.jpegQuality = 75,
    this.targetDpi = 144,
    this.dpiThreshold = 180,
    this.minimumWidth = 64,
    this.minimumHeight = 64,
    this.minimumArea = 4096,
    this.minimumStreamBytes = 1024,
    this.downsampleImages = false,
    this.recompressJpeg = true,
    this.convertToGrayscale = false,
    this.stripMetadata = false,
    this.stripDocumentInfo = false,
    this.removeUnusedResources = false,
    this.deduplicateImages = true,
    this.preserveTransparency = true,
    this.maximumDecodedPixels = 150000000,
    this.memoryBudgetBytes = 512000000,
  });

  /// Create options from a quality value, preserving v1 behavior.
  factory QpdfOptimizerOptions.fromQuality(int quality) {
    final safeQuality = quality.clamp(1, 100);
    return QpdfOptimizerOptions(
      mode: QpdfCompressionMode.structural,
      jpegQuality: safeQuality,
      targetDpi: 144,
      dpiThreshold: 180,
      downsampleImages: false,
      recompressJpeg: true,
      deduplicateImages: true,
    );
  }

  /// Create balanced image-optimized options from a quality value.
  factory QpdfOptimizerOptions.imageOptimized(int quality) {
    final safeQuality = quality.clamp(1, 100);
    final (dpi, threshold) = switch (safeQuality) {
      >= 85 => (180, 225),
      >= 65 => (144, 180),
      >= 45 => (110, 140),
      _ => (96, 120),
    };
    return QpdfOptimizerOptions(
      mode: QpdfCompressionMode.imageOptimized,
      jpegQuality: safeQuality,
      targetDpi: dpi,
      dpiThreshold: threshold,
      downsampleImages: true,
      recompressJpeg: true,
      deduplicateImages: true,
      preserveTransparency: true,
    );
  }

  QpdfOptimizerOptions copyWith({
    QpdfCompressionMode? mode,
    int? jpegQuality,
    int? targetDpi,
    int? dpiThreshold,
    bool? downsampleImages,
    bool? recompressJpeg,
    bool? convertToGrayscale,
    bool? stripMetadata,
    bool? stripDocumentInfo,
    bool? removeUnusedResources,
    bool? deduplicateImages,
    bool? preserveTransparency,
  }) {
    return QpdfOptimizerOptions(
      mode: mode ?? this.mode,
      jpegQuality: (jpegQuality ?? this.jpegQuality).clamp(1, 100),
      targetDpi: targetDpi ?? this.targetDpi,
      dpiThreshold: dpiThreshold ?? this.dpiThreshold,
      minimumWidth: minimumWidth,
      minimumHeight: minimumHeight,
      minimumArea: minimumArea,
      minimumStreamBytes: minimumStreamBytes,
      downsampleImages: downsampleImages ?? this.downsampleImages,
      recompressJpeg: recompressJpeg ?? this.recompressJpeg,
      convertToGrayscale: convertToGrayscale ?? this.convertToGrayscale,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      stripDocumentInfo: stripDocumentInfo ?? this.stripDocumentInfo,
      removeUnusedResources:
          removeUnusedResources ?? this.removeUnusedResources,
      deduplicateImages: deduplicateImages ?? this.deduplicateImages,
      preserveTransparency:
          preserveTransparency ?? this.preserveTransparency,
      maximumDecodedPixels: maximumDecodedPixels,
      memoryBudgetBytes: memoryBudgetBytes,
    );
  }

  @override
  String toString() =>
      'QpdfOptimizerOptions('
      'mode: ${mode.name}, '
      'quality: $jpegQuality, '
      'dpi: $targetDpi/$dpiThreshold, '
      'downsample: $downsampleImages, '
      'grayscale: $convertToGrayscale, '
      'strip: $stripMetadata'
      ')';
}

// ─── V2 result ──────────────────────────────────────────────────────────────

class QpdfOptimizerResultV2 {
  final QpdfOptimizerStatus status;
  final String? message;

  final int pagesProcessed;
  final int imagesFound;
  final int imagesReplaced;
  final int imagesSkipped;
  final int imagesFailed;

  final int originalBytes;
  final int outputBytes;
  final int imageBytesBefore;
  final int imageBytesAfter;

  const QpdfOptimizerResultV2({
    required this.status,
    this.message,
    this.pagesProcessed = 0,
    this.imagesFound = 0,
    this.imagesReplaced = 0,
    this.imagesSkipped = 0,
    this.imagesFailed = 0,
    this.originalBytes = 0,
    this.outputBytes = 0,
    this.imageBytesBefore = 0,
    this.imageBytesAfter = 0,
  });

  bool get wasCompleted => status == QpdfOptimizerStatus.completed;

  int get bytesReduced => originalBytes - outputBytes;

  double get reductionPercent =>
      originalBytes > 0 ? (bytesReduced / originalBytes) * 100 : 0;

  @override
  String toString() =>
      'QpdfOptimizerResultV2('
      'status: ${status.name}, '
      'pages: $pagesProcessed, '
      'images: $imagesFound/$imagesReplaced/$imagesSkipped/$imagesFailed, '
      'size: ${_formatSize(originalBytes)} → ${_formatSize(outputBytes)} '
      '(${reductionPercent.toStringAsFixed(1)}%)'
      ')';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

// ─── Analysis results ──────────────────────────────────────────────────────

class QpdfImageInfo {
  final int objectNumber;
  final int width;
  final int height;
  final double maxDpi;
  final int encodedBytes;
  final bool processable;
  final String colorSpace;
  final String filter;
  final bool hasSmask;

  const QpdfImageInfo({
    required this.objectNumber,
    required this.width,
    required this.height,
    required this.maxDpi,
    required this.encodedBytes,
    required this.processable,
    required this.colorSpace,
    required this.filter,
    required this.hasSmask,
  });

  @override
  String toString() =>
      'QpdfImageInfo(obj:$objectNumber, ${width}x${height}, '
      'dpi:${maxDpi.toStringAsFixed(0)}, $filter/$colorSpace, '
      'processable:$processable)';
}

class QpdfAnalysisResult {
  final int pageCount;
  final int imageCount;
  final int highDpiCount;
  final int totalImageBytes;
  final bool isEncrypted;
  final bool hasSignatures;
  final List<QpdfImageInfo> images;

  const QpdfAnalysisResult({
    required this.pageCount,
    required this.imageCount,
    required this.highDpiCount,
    required this.totalImageBytes,
    required this.isEncrypted,
    required this.hasSignatures,
    required this.images,
  });

  int get processableCount => images.where((i) => i.processable).length;

  @override
  String toString() =>
      'QpdfAnalysisResult('
      'pages: $pageCount, images: $imageCount '
      '(processable: $processableCount, high-dpi: $highDpiCount), '
      'imgBytes: ${_fmt(totalImageBytes)}, '
      'encrypted: $isEncrypted, signed: $hasSignatures)';

  String _fmt(int b) {
    if (b < 1024) return '$b B';
    if (b < 1024 * 1024) return '${(b / 1024).toStringAsFixed(1)} KB';
    return '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

// ─── V1 Optimizer (backward-compatible wrapper) ─────────────────────────────

/// Optimizes PDFs through qpdf on Windows and Android.
///
/// This is the v1 interface. New code should use [optimizeV2] with
/// [QpdfOptimizerOptions] for full control over compression modes,
/// DPI targets, and feature flags.
class QpdfOptimizer {
  const QpdfOptimizer();

  /// V1 optimization — structural only, single quality parameter.
  Future<QpdfOptimizerResult> optimize({
    required String inputPath,
    required String outputPath,
    required int quality,
    bool Function()? isCancelled,
  }) {
    return implementation.optimizeV1(
      inputPath: inputPath,
      outputPath: outputPath,
      quality: quality,
      isCancelled: isCancelled,
    );
  }

  /// V2 optimization — full options control.
  Future<QpdfOptimizerResultV2> optimizeV2({
    required String inputPath,
    required String outputPath,
    required QpdfOptimizerOptions options,
    bool Function()? isCancelled,
  }) {
    return implementation.optimizeV2(
      inputPath: inputPath,
      outputPath: outputPath,
      options: options,
      isCancelled: isCancelled,
    );
  }

  /// Analyze a PDF and return image metadata, DPI info, and processability.
  Future<QpdfAnalysisResult> analyzePdf(
    String inputPath, {
    int dpiThreshold = 180,
  }) {
    return implementation.analyzePdfAsync(inputPath, dpiThreshold: dpiThreshold);
  }
}
