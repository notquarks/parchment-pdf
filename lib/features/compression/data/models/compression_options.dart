import 'dart:typed_data';

import 'package:flutter/material.dart';

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

enum PdfCompressionMode { structural, imageOptimized, extremeRaster }

enum CompressionPreset {
  preserveDetail(
    title: 'Preserve detail',
    description: 'Best quality, moderate size reduction',
    icon: Icons.hd_outlined,
    mode: PdfCompressionMode.imageOptimized,
    quality: 85,
    dpiTarget: 180,
    dpiThreshold: 225,
  ),
  balanced(
    title: 'Balanced',
    description: 'Good balance of quality and size',
    icon: Icons.balance_outlined,
    mode: PdfCompressionMode.imageOptimized,
    quality: 70,
    dpiTarget: 140,
    dpiThreshold: 175,
  ),
  smallerFile(
    title: 'Smaller file',
    description: 'Stronger compression, some quality loss',
    icon: Icons.compress,
    mode: PdfCompressionMode.imageOptimized,
    quality: 60,
    dpiTarget: 110,
    dpiThreshold: 140,
  ),
  extreme(
    title: 'Extreme',
    description: 'Maximum compression (destroys text selection)',
    icon: Icons.speed,
    mode: PdfCompressionMode.extremeRaster,
    quality: 55,
    dpiTarget: 96,
    dpiThreshold: 0,
  ),
  structuralOnly(
    title: 'Structural only',
    description: 'Lossless optimization, no image changes',
    icon: Icons.lock_outline,
    mode: PdfCompressionMode.structural,
    quality: 80,
    dpiTarget: 0,
    dpiThreshold: 0,
  );

  const CompressionPreset({
    required this.title,
    required this.description,
    required this.icon,
    required this.mode,
    required this.quality,
    required this.dpiTarget,
    required this.dpiThreshold,
  });

  final String title;
  final String description;
  final IconData icon;
  final PdfCompressionMode mode;
  final int quality;
  final int dpiTarget;
  final int dpiThreshold;
}

class CompressionOptions {
  final int quality;
  final int dpiTarget;
  final int dpiThreshold;
  final int minSize;
  final bool recompressJpeg;
  final bool downscale;
  final bool convertToGrayscale;
  final bool stripMetadata;
  final PdfCompressionMode mode;

  const CompressionOptions({
    required this.quality,
    required this.dpiTarget,
    required this.dpiThreshold,
    this.minSize = 128,
    this.recompressJpeg = true,
    this.downscale = true,
    this.convertToGrayscale = false,
    this.stripMetadata = false,
    this.mode = PdfCompressionMode.structural,
  });

  factory CompressionOptions.fromPreset(CompressionPreset preset) {
    return CompressionOptions(
      quality: preset.quality,
      dpiTarget: preset.dpiTarget,
      dpiThreshold: preset.dpiThreshold,
      mode: preset.mode,
      downscale: preset.dpiTarget > 0,
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
    bool? stripMetadata,
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
      stripMetadata: stripMetadata ?? this.stripMetadata,
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
      'stripMetadata: $stripMetadata, '
      'mode: $mode'
      ')';
}

class CompressionEstimate {
  final int originalSize;
  final int estimatedSize;

  const CompressionEstimate({
    required this.originalSize,
    required this.estimatedSize,
  });

  int get estimatedBytesReduced => originalSize - estimatedSize;

  double get estimatedReductionPercent => originalSize > 0
      ? (estimatedBytesReduced / originalSize) * 100
      : 0;

  bool get hasMeaningfulReduction => estimatedSize < originalSize;
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
