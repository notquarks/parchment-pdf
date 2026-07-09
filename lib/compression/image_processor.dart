import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'compression_options.dart';

class ImageProcessor {
  static Future<ProcessedImage?> processImage({
    required Uint8List imageBytes,
    required CompressionOptions options,
    int sourceDpi = 72,
    bool convertToGrayscale = false,
  }) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) {
      return null;
    }

    final originalWidth = image.width;
    final originalHeight = image.height;
    final originalSize = imageBytes.length;

    if (!options.shouldProcess(originalWidth, originalHeight)) {
      return null;
    }

    final targetWidth = options.targetWidth(originalWidth, sourceDpi);
    final targetHeight = options.targetHeight(originalHeight, sourceDpi);

    final needsResize =
        targetWidth != originalWidth || targetHeight != originalHeight;

    final needsGrayscale =
        convertToGrayscale && image.numChannels >= 3;

    if (!needsResize && !needsGrayscale && options.recompressJpeg) {
    } else if (!needsResize && !needsGrayscale) {
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

    final jpegBytes = Uint8List.fromList(
      img.encodeJpg(processedImage, quality: options.quality),
    );

    final newSize = jpegBytes.length;

    final wasModified = needsResize || needsGrayscale || newSize < originalSize;

    if (!wasModified) {
      return null;
    }

    return ProcessedImage(
      bytes: jpegBytes,
      originalWidth: originalWidth,
      originalHeight: originalHeight,
      newWidth: processedImage.width,
      newHeight: processedImage.height,
      originalSize: originalSize,
      newSize: newSize,
      wasModified: true,
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
    if (!options.shouldProcess(width, height)) {
      return 1.0;
    }

    final qualityRatio = options.quality / 100.0;

    double dpiRatio = 1.0;
    if (options.downscale && sourceDpi > options.dpiThreshold) {
      dpiRatio = options.dpiTarget / sourceDpi;
    }

    return qualityRatio * dpiRatio * dpiRatio;
  }

  static bool isFormatSupported(String format) {
    final supported = ['jpeg', 'jpg', 'png', 'bmp', 'gif', 'tiff'];
    return supported.contains(format.toLowerCase());
  }

  static bool isJpeg(String format) {
    final lower = format.toLowerCase();
    return lower == 'jpeg' || lower == 'jpg';
  }
}
