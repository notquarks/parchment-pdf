import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../models/compression_options.dart';

class ImageProcessor {
  static Future<ProcessedImage?> processImage({
    required Uint8List imageBytes,
    required CompressionOptions options,
    int sourceDpi = 72,
    bool convertToGrayscale = false,
  }) async {
    if (imageBytes.isEmpty) return null;

    final image = img.decodeImage(imageBytes);
    if (image == null) return null;

    final originalWidth = image.width;
    final originalHeight = image.height;
    final originalSize = imageBytes.length;

    if (!options.shouldProcess(originalWidth, originalHeight)) {
      return null;
    }

    final (targetWidth, targetHeight) = options.targetDimensions(
      originalWidth,
      originalHeight,
      sourceDpi,
    );

    final needsResize =
        targetWidth != originalWidth || targetHeight != originalHeight;
    final needsGrayscale =
        (convertToGrayscale || options.convertToGrayscale) &&
        image.numChannels >= 3;
    final canRecompressOriginal =
        options.recompressJpeg && _isJpegBytes(imageBytes);

    if (!needsResize && !needsGrayscale && !canRecompressOriginal) {
      return null;
    }

    img.Image processedImage = image;

    if (needsGrayscale) {
      processedImage = img.grayscale(processedImage);
    }

    if (needsResize) {
      processedImage = img.copyResize(
        processedImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.linear,
      );
    }

    final hasAlpha = processedImage.numChannels == 2 ||
        processedImage.numChannels == 4;
    final Uint8List encodedBytes;
    final String outputFormat;

    if (hasAlpha) {
      encodedBytes = Uint8List.fromList(img.encodePng(processedImage));
      outputFormat = 'png';
    } else {
      encodedBytes = Uint8List.fromList(
        img.encodeJpg(
          processedImage,
          quality: options.quality.clamp(1, 100).toInt(),
        ),
      );
      outputFormat = 'jpeg';
    }

    final newSize = encodedBytes.length;
    final bytesSaved = originalSize - newSize;

    final minimumUsefulSaving = math.max(64, (originalSize * 0.005).round());
    if (bytesSaved < minimumUsefulSaving) {
      return null;
    }

    return ProcessedImage(
      bytes: encodedBytes,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      newWidth: processedImage.width,
      newHeight: processedImage.height,
      originalSize: originalSize,
      newSize: newSize,
      wasModified: true,
      outputFormat: outputFormat,
    );
  }

  static Future<List<ProcessedImage?>> processImages({
    required List<Uint8List> imageBytesList,
    required CompressionOptions options,
    int sourceDpi = 72,
    bool convertToGrayscale = false,
  }) async {
    final results = <ProcessedImage?>[];

    for (final imageBytes in imageBytesList) {
      final result = await processImage(
        imageBytes: imageBytes,
        options: options,
        sourceDpi: sourceDpi,
        convertToGrayscale: convertToGrayscale,
      );
      results.add(result);
    }

    return results;
  }

  static double estimateCompressionRatio({
    required int width,
    required int height,
    required int currentSize,
    required CompressionOptions options,
    int sourceDpi = 72,
  }) {
    if (currentSize <= 0 || !options.shouldProcess(width, height)) {
      return 1.0;
    }

    final (targetWidth, targetHeight) = options.targetDimensions(
      width,
      height,
      sourceDpi,
    );
    final sourcePixels = width * height;
    final targetPixels = targetWidth * targetHeight;
    final pixelRatio = sourcePixels > 0 ? targetPixels / sourcePixels : 1.0;

    final normalizedQuality = options.quality.clamp(1, 100) / 100.0;
    final qualityRatio =
        0.12 + 0.88 * math.pow(normalizedQuality, 1.65).toDouble();
    final estimatedRatio =
        (pixelRatio * qualityRatio).clamp(0.05, 1.0).toDouble();

    final estimatedSize = (currentSize * estimatedRatio).round();
    final minimumUsefulSaving = math.max(64, (currentSize * 0.005).round());
    if (currentSize - estimatedSize < minimumUsefulSaving) {
      return 1.0;
    }

    return estimatedRatio;
  }

  static bool isFormatSupported(String format) {
    final supported = ['jpeg', 'jpg', 'png', 'bmp', 'gif', 'tiff'];
    return supported.contains(format.toLowerCase());
  }

  static bool isJpeg(String format) {
    final lower = format.toLowerCase();
    return lower == 'jpeg' || lower == 'jpg';
  }

  static bool _isJpegBytes(Uint8List bytes) {
    return bytes.length >= 3 &&
        bytes[0] == 0xff &&
        bytes[1] == 0xd8 &&
        bytes[2] == 0xff;
  }
}
