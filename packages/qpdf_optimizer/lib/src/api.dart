import 'optimizer_stub.dart'
    if (dart.library.io) 'optimizer_native.dart'
    if (dart.library.js_interop) 'optimizer_stub.dart'
    as implementation;

enum QpdfOptimizerStatus { completed, unavailable, cancelled, failed }

enum QpdfCompressionMode { structural, imageOptimized }

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
    this.preserveTransparency = true,
    this.maximumDecodedPixels = 150000000,
    this.memoryBudgetBytes = 512000000,
  });

  factory QpdfOptimizerOptions.fromQuality(int quality) {
    return QpdfOptimizerOptions(jpegQuality: quality.clamp(1, 100).toInt());
  }

  factory QpdfOptimizerOptions.imageOptimized(int quality) {
    final safeQuality = quality.clamp(1, 100).toInt();
    final (dpi, threshold) = switch (safeQuality) {
      >= 85 => (180, 225),
      >= 65 => (140, 175),
      >= 45 => (110, 140),
      _ => (96, 120),
    };
    return QpdfOptimizerOptions(
      mode: QpdfCompressionMode.imageOptimized,
      jpegQuality: safeQuality,
      targetDpi: dpi,
      dpiThreshold: threshold,
      downsampleImages: true,
    );
  }

  QpdfOptimizerOptions copyWith({
    QpdfCompressionMode? mode,
    int? jpegQuality,
    int? targetDpi,
    int? dpiThreshold,
    int? minimumWidth,
    int? minimumHeight,
    int? minimumArea,
    int? minimumStreamBytes,
    bool? downsampleImages,
    bool? recompressJpeg,
    bool? convertToGrayscale,
    bool? stripMetadata,
    bool? stripDocumentInfo,
    bool? removeUnusedResources,
    bool? preserveTransparency,
    int? maximumDecodedPixels,
    int? memoryBudgetBytes,
  }) {
    return QpdfOptimizerOptions(
      mode: mode ?? this.mode,
      jpegQuality: (jpegQuality ?? this.jpegQuality).clamp(1, 100).toInt(),
      targetDpi: targetDpi ?? this.targetDpi,
      dpiThreshold: dpiThreshold ?? this.dpiThreshold,
      minimumWidth: minimumWidth ?? this.minimumWidth,
      minimumHeight: minimumHeight ?? this.minimumHeight,
      minimumArea: minimumArea ?? this.minimumArea,
      minimumStreamBytes: minimumStreamBytes ?? this.minimumStreamBytes,
      downsampleImages: downsampleImages ?? this.downsampleImages,
      recompressJpeg: recompressJpeg ?? this.recompressJpeg,
      convertToGrayscale: convertToGrayscale ?? this.convertToGrayscale,
      stripMetadata: stripMetadata ?? this.stripMetadata,
      stripDocumentInfo: stripDocumentInfo ?? this.stripDocumentInfo,
      removeUnusedResources:
          removeUnusedResources ?? this.removeUnusedResources,
      preserveTransparency: preserveTransparency ?? this.preserveTransparency,
      maximumDecodedPixels: maximumDecodedPixels ?? this.maximumDecodedPixels,
      memoryBudgetBytes: memoryBudgetBytes ?? this.memoryBudgetBytes,
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

class QpdfOptimizerResult {
  final QpdfOptimizerStatus status;
  final String? message;
  final int warningCount;
  final int pagesProcessed;
  final int imagesFound;
  final int imagesReplaced;
  final int imagesSkipped;
  final int imagesFailed;
  final int originalBytes;
  final int outputBytes;
  final int imageBytesBefore;
  final int imageBytesAfter;

  const QpdfOptimizerResult({
    required this.status,
    this.message,
    this.warningCount = 0,
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
      'QpdfOptimizerResult('
      'status: ${status.name}, '
      'pages: $pagesProcessed, '
      'images: $imagesFound/$imagesReplaced/$imagesSkipped/$imagesFailed, '
      'size: ${_formatSize(originalBytes)} → ${_formatSize(outputBytes)} '
      '(${reductionPercent.toStringAsFixed(1)}%)'
      ')';
}

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
      'QpdfImageInfo(obj:$objectNumber, ${width}x$height, '
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

  int get processableCount => images.where((image) => image.processable).length;

  @override
  String toString() =>
      'QpdfAnalysisResult('
      'pages: $pageCount, images: $imageCount '
      '(processable: $processableCount, high-dpi: $highDpiCount), '
      'imgBytes: ${_formatSize(totalImageBytes)}, '
      'encrypted: $isEncrypted, signed: $hasSignatures)';
}

class QpdfOptimizer {
  const QpdfOptimizer();

  String get buildId => implementation.buildId();

  Future<QpdfOptimizerResult> optimize({
    required String inputPath,
    required String outputPath,
    required QpdfOptimizerOptions options,
    bool Function()? isCancelled,
  }) {
    return implementation.optimize(
      inputPath: inputPath,
      outputPath: outputPath,
      options: options,
      isCancelled: isCancelled,
    );
  }

  Future<QpdfAnalysisResult> analyzePdf(
    String inputPath, {
    int dpiThreshold = 180,
  }) {
    return implementation.analyzePdf(inputPath, dpiThreshold: dpiThreshold);
  }
}

String _formatSize(int bytes) {
  if (bytes < 1000) return '$bytes B';
  if (bytes < 1000 * 1000) {
    return '${(bytes / 1000).toStringAsFixed(1)} kB';
  }
  return '${(bytes / 1000000).toStringAsFixed(1)} MB';
}
