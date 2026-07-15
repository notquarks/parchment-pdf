import 'dart:typed_data';

class ProcessedImage {
  final Uint8List bytes;
  final int originalWidth;
  final int originalHeight;
  final int newWidth;
  final int newHeight;
  final int originalSize;
  final int newSize;
  final bool wasModified;
  final String outputFormat;

  const ProcessedImage({
    required this.bytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.newWidth,
    required this.newHeight,
    required this.originalSize,
    required this.newSize,
    required this.wasModified,
    this.outputFormat = 'jpeg',
  });

  double get reductionPercent =>
      originalSize > 0 ? (1 - newSize / originalSize) * 100 : 0;

  int get bytesReduced => originalSize - newSize;
}

enum CompressionPreset { light, balanced, aggressive, extreme }

enum PdfCompressionMode { structural, imageOptimized, extremeRaster }

class _PresetConfig {
  final int quality;
  final int dpiTarget;
  final int dpiThreshold;

  const _PresetConfig({
    required this.quality,
    required this.dpiTarget,
    required this.dpiThreshold,
  });
}

const Map<CompressionPreset, _PresetConfig> _presetConfigs = {
  CompressionPreset.light: _PresetConfig(
    quality: 85,
    dpiTarget: 150,
    dpiThreshold: 200,
  ),
  CompressionPreset.balanced: _PresetConfig(
    quality: 75,
    dpiTarget: 120,
    dpiThreshold: 150,
  ),
  CompressionPreset.aggressive: _PresetConfig(
    quality: 60,
    dpiTarget: 96,
    dpiThreshold: 120,
  ),
  CompressionPreset.extreme: _PresetConfig(
    quality: 40,
    dpiTarget: 72,
    dpiThreshold: 96,
  ),
};

class CompressionOptions {
  final int quality;
  final int dpiTarget;
  final int dpiThreshold;
  final int minSize;
  final bool recompressJpeg;
  final bool downscale;
  final bool convertToGrayscale;
  final PdfCompressionMode mode;

  const CompressionOptions({
    required this.quality,
    required this.dpiTarget,
    required this.dpiThreshold,
    this.minSize = 128,
    this.recompressJpeg = true,
    this.downscale = true,
    this.convertToGrayscale = false,
    this.mode = PdfCompressionMode.structural,
  });

  factory CompressionOptions.fromPreset(CompressionPreset preset) {
    final config = _presetConfigs[preset]!;
    return CompressionOptions(
      quality: config.quality,
      dpiTarget: config.dpiTarget,
      dpiThreshold: config.dpiThreshold,
    );
  }

  factory CompressionOptions.withQuality(int quality) {
    final safeQuality = quality.clamp(1, 100).toInt();

    final (dpiTarget, dpiThreshold) = switch (safeQuality) {
      >= 90 => (200, 240),
      >= 80 => (150, 200),
      >= 65 => (120, 150),
      >= 50 => (96, 120),
      _ => (72, 96),
    };

    return CompressionOptions(
      quality: safeQuality,
      dpiTarget: dpiTarget,
      dpiThreshold: dpiThreshold,
    );
  }

  CompressionOptions copyWith({
    int? quality,
    int? dpiTarget,
    int? dpiThreshold,
    int? minSize,
    bool? recompressJpeg,
    bool? downscale,
    bool? convertToGrayscale,
    PdfCompressionMode? mode,
  }) {
    return CompressionOptions(
      quality: (quality ?? this.quality).clamp(1, 100).toInt(),
      dpiTarget: dpiTarget ?? this.dpiTarget,
      dpiThreshold: dpiThreshold ?? this.dpiThreshold,
      minSize: minSize ?? this.minSize,
      recompressJpeg: recompressJpeg ?? this.recompressJpeg,
      downscale: downscale ?? this.downscale,
      convertToGrayscale: convertToGrayscale ?? this.convertToGrayscale,
      mode: mode ?? this.mode,
    );
  }

  (int width, int height) targetDimensions(
    int sourceWidth,
    int sourceHeight,
    int sourceDpi,
  ) {
    if (!downscale ||
        sourceWidth <= 0 ||
        sourceHeight <= 0 ||
        sourceDpi <= dpiThreshold) {
      return (sourceWidth, sourceHeight);
    }

    final scale = (dpiTarget / sourceDpi).clamp(0.0, 1.0);
    return (
      (sourceWidth * scale).round().clamp(1, sourceWidth).toInt(),
      (sourceHeight * scale).round().clamp(1, sourceHeight).toInt(),
    );
  }

  int targetWidth(int sourceWidth, int sourceDpi) {
    return targetDimensions(sourceWidth, 1, sourceDpi).$1;
  }

  int targetHeight(int sourceHeight, int sourceDpi) {
    return targetDimensions(1, sourceHeight, sourceDpi).$2;
  }

  bool shouldProcess(int width, int height) {
    if (width <= 0 || height <= 0) return false;
    return width >= minSize || height >= minSize;
  }

  @override
  String toString() =>
      'CompressionOptions('
      'quality: $quality, '
      'dpiTarget: $dpiTarget, '
      'dpiThreshold: $dpiThreshold, '
      'minSize: $minSize, '
      'recompressJpeg: $recompressJpeg, '
      'downscale: $downscale, '
      'convertToGrayscale: $convertToGrayscale, '
      'mode: $mode'
      ')';
}

class CompressionResult {
  final int imagesProcessed;
  final int imagesSkipped;
  final int imagesFailed;
  final int originalSize;
  final int compressedSize;
  final Duration processingTime;
  final List<ProcessedImage> processedImages;

  const CompressionResult({
    this.imagesProcessed = 0,
    this.imagesSkipped = 0,
    this.imagesFailed = 0,
    this.originalSize = 0,
    this.compressedSize = 0,
    this.processingTime = Duration.zero,
    this.processedImages = const [],
  });

  double get reductionPercent =>
      originalSize > 0 ? (1 - compressedSize / originalSize) * 100 : 0;

  int get bytesReduced => originalSize - compressedSize;

  @override
  String toString() =>
      'CompressionResult('
      'processed: $imagesProcessed, '
      'skipped: $imagesSkipped, '
      'failed: $imagesFailed, '
      'reduction: ${reductionPercent.toStringAsFixed(1)}%, '
      'time: ${processingTime.inMilliseconds}ms'
      ')';
}

class ImageMetadata {
  final int xref;
  final int width;
  final int height;
  final String format;
  final String colorSpace;
  final int bitsPerComponent;
  final int estimatedDpi;
  final int dataSize;

  const ImageMetadata({
    this.xref = 0,
    required this.width,
    required this.height,
    required this.format,
    required this.colorSpace,
    required this.bitsPerComponent,
    this.estimatedDpi = 72,
    required this.dataSize,
  });

  bool shouldProcess(CompressionOptions options) {
    return options.shouldProcess(width, height);
  }

  (int width, int height) targetDimensions(CompressionOptions options) {
    return options.targetDimensions(width, height, estimatedDpi);
  }

  @override
  String toString() =>
      'ImageMetadata('
      'xref: $xref, '
      '${width}x$height, '
      '$format, '
      '${(dataSize / 1024).toStringAsFixed(1)}KB'
      ')';
}
