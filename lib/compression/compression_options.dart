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

  const ProcessedImage({
    required this.bytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.newWidth,
    required this.newHeight,
    required this.originalSize,
    required this.newSize,
    required this.wasModified,
  });

  double get reductionPercent =>
      originalSize > 0 ? (1 - newSize / originalSize) * 100 : 0;

  int get bytesReduced => originalSize - newSize;
}

enum CompressionPreset {
  light,
  balanced,
  aggressive,
  extreme,
}

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

  const CompressionOptions({
    required this.quality,
    required this.dpiTarget,
    required this.dpiThreshold,
    this.minSize = 128,
    this.recompressJpeg = true,
    this.downscale = true,
    this.convertToGrayscale = false,
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
    final config = _presetConfigs[CompressionPreset.balanced]!;
    return CompressionOptions(
      quality: quality,
      dpiTarget: config.dpiTarget,
      dpiThreshold: config.dpiThreshold,
    );
  }

  int targetWidth(int sourceWidth, int sourceDpi) {
    if (!downscale || sourceDpi <= dpiThreshold) {
      return sourceWidth;
    }
    return (sourceWidth * dpiTarget / sourceDpi).round().clamp(1, sourceWidth);
  }

  int targetHeight(int sourceHeight, int sourceDpi) {
    if (!downscale || sourceDpi <= dpiThreshold) {
      return sourceHeight;
    }
    return (sourceHeight * dpiTarget / sourceDpi)
        .round()
        .clamp(1, sourceHeight);
  }

  bool shouldProcess(int width, int height) {
    return width >= minSize || height >= minSize;
  }

  @override
  String toString() => 'CompressionOptions('
      'quality: $quality, '
      'dpiTarget: $dpiTarget, '
      'dpiThreshold: $dpiThreshold, '
      'minSize: $minSize, '
      'recompressJpeg: $recompressJpeg, '
      'downscale: $downscale'
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

  double get reductionPercent => originalSize > 0
      ? (1 - compressedSize / originalSize) * 100
      : 0;

  int get bytesReduced => originalSize - compressedSize;

  @override
  String toString() => 'CompressionResult('
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
    return (
      options.targetWidth(width, estimatedDpi),
      options.targetHeight(height, estimatedDpi),
    );
  }

  @override
  String toString() => 'ImageMetadata('
      'xref: $xref, '
      '${width}x$height, '
      '$format, '
      '${(dataSize / 1024).toStringAsFixed(1)}KB'
      ')';
}
