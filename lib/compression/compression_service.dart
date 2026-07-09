import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import 'compression_options.dart';
import 'compression_worker.dart';
import 'image_processor.dart';

class CompressionService {
  final CompressionWorker _worker;
  bool _isDisposed = false;

  CompressionService({int? maxWorkers})
      : _worker = CompressionWorker(maxWorkers: maxWorkers);

  Future<void> initialize() async {
    await _worker.initialize();
  }

  Future<CompressionAnalysis> analyzePdf({
    required DataSource source,
    required CompressionOptions options,
  }) async {
    final pdf = Pdf();
    try {
      final doc = await pdf.open(source);
      final pageCount = doc.pageCount;

      final images = <ImageMetadata>[];
      var totalOriginalSize = 0;

      for (var page = 0; page < pageCount; page++) {
        final imageStream =
            doc.extractImages(pages: PdfPages.single(page));
        await for (final img in imageStream) {
          final metadata = ImageMetadata(
            width: img.width,
            height: img.height,
            format: img.format,
            colorSpace: img.colorSpace,
            bitsPerComponent: img.bitsPerComponent,
            dataSize: img.data.length,
          );
          images.add(metadata);
          totalOriginalSize += img.data.length;
        }
      }

      var estimatedCompressedSize = 0;
      for (final img in images) {
        if (img.shouldProcess(options)) {
          final ratio = ImageProcessor.estimateCompressionRatio(
            width: img.width,
            height: img.height,
            currentSize: img.dataSize,
            options: options,
            sourceDpi: img.estimatedDpi,
          );
          estimatedCompressedSize += (img.dataSize * ratio).round();
        } else {
          estimatedCompressedSize += img.dataSize;
        }
      }

      await doc.dispose();

      return CompressionAnalysis(
        totalPages: pageCount,
        totalImages: images.length,
        imagesToProcess: images.where((i) => i.shouldProcess(options)).length,
        totalOriginalSize: totalOriginalSize,
        estimatedCompressedSize: estimatedCompressedSize,
        images: images,
      );
    } finally {
      await pdf.dispose();
    }
  }

  Future<String> compressPdf({
    required String filePath,
    required CompressionOptions options,
    required String outputPath,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    final document = await pdfrx.PdfDocument.openFile(filePath);
    final outputFile = File(outputPath);

    try {
      final pdfDoc = pw.Document();
      final pages = document.pages;
      final totalPages = pages.length;

      for (var i = 0; i < totalPages; i++) {
        if (cancelToken?.isCancelled == true) {
          throw CancellationException();
        }

        final page = pages[i];
        final pageWidth = page.width;
        final pageHeight = page.height;

        if (pageWidth <= 0 || pageHeight <= 0) {
          continue;
        }

        final renderWidth = (pageWidth * options.dpiTarget / 72).round();
        final renderHeight = (pageHeight * options.dpiTarget / 72).round();

        if (renderWidth <= 0 || renderHeight <= 0) {
          continue;
        }

        final rendered = await page.render(
          fullWidth: renderWidth.toDouble(),
          fullHeight: renderHeight.toDouble(),
        );

        if (rendered == null) {
          continue;
        }

        try {
          final width = rendered.width;
          final height = rendered.height;
          final pixels = rendered.pixels;

          final rgb = Uint8List(width * height * 3);
          for (var j = 0; j < width * height; j++) {
            rgb[j * 3 + 0] = pixels[j * 4 + 2];
            rgb[j * 3 + 1] = pixels[j * 4 + 1];
            rgb[j * 3 + 2] = pixels[j * 4 + 0];
          }

          final decoded = img.Image.fromBytes(
            width: width,
            height: height,
            bytes: rgb.buffer,
            numChannels: 3,
          );
          final jpegBytes = img.encodeJpg(decoded, quality: options.quality);

          final image = pw.MemoryImage(Uint8List.fromList(jpegBytes));
          pdfDoc.addPage(pw.Page(
            pageFormat: PdfPageFormat(
              pageWidth,
              pageHeight,
            ),
            build: (context) => pw.Center(
              child: pw.Image(image, width: pageWidth, height: pageHeight),
            ),
          ));
        } finally {
          rendered.dispose();
        }

        onProgress?.call(i + 1, totalPages);
      }

      final bytes = await pdfDoc.save();
      if (bytes.isEmpty) {
        throw Exception('Generated PDF is empty');
      }

      await outputFile.writeAsBytes(bytes);

      if (!await outputFile.exists() || await outputFile.length() == 0) {
        throw Exception('Output file is missing or empty');
      }

      return outputPath;
    } catch (e) {
      _deleteFileIfExists(outputFile);
      rethrow;
    } finally {
      await document.dispose();
    }
  }

  static void _deleteFileIfExists(File file) {
    try {
      if (file.existsSync()) {
        file.deleteSync();
      }
    } catch (_) {}
  }

  Future<CompressionResult> compressImages({
    required DataSource source,
    required CompressionOptions options,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    final stopwatch = Stopwatch()..start();

    final pdf = Pdf();
    try {
      final doc = await pdf.open(source);
      final pageCount = doc.pageCount;

      final allImages = <Uint8List>[];
      final originalSizes = <int>[];

      for (var page = 0; page < pageCount; page++) {
        if (cancelToken?.isCancelled == true) {
          throw CancellationException();
        }

        final imageStream =
            doc.extractImages(pages: PdfPages.single(page));
        await for (final img in imageStream) {
          allImages.add(img.data);
          originalSizes.add(img.data.length);
        }
      }

      if (allImages.isEmpty) {
        return CompressionResult(
          originalSize: 0,
          compressedSize: 0,
        );
      }

      final processedImages = await _worker.processImages(
        imageBytesList: allImages,
        options: options,
        onProgress: onProgress,
        cancelToken: cancelToken,
      );

      var totalOriginalSize = 0;
      var totalCompressedSize = 0;
      var imagesProcessed = 0;
      var imagesSkipped = 0;
      var imagesFailed = 0;
      final compressedImages = <ProcessedImage>[];

      for (var i = 0; i < processedImages.length; i++) {
        totalOriginalSize += originalSizes[i];

        final processed = processedImages[i];
        if (processed == null) {
          imagesSkipped++;
          totalCompressedSize += originalSizes[i];
        } else {
          imagesProcessed++;
          totalCompressedSize += processed.newSize;
          compressedImages.add(processed);
        }
      }

      stopwatch.stop();

      return CompressionResult(
        imagesProcessed: imagesProcessed,
        imagesSkipped: imagesSkipped,
        imagesFailed: imagesFailed,
        originalSize: totalOriginalSize,
        compressedSize: totalCompressedSize,
        processingTime: stopwatch.elapsed,
        processedImages: compressedImages,
      );
    } finally {
      await pdf.dispose();
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _worker.dispose();
  }
}

class CompressionAnalysis {
  final int totalPages;
  final int totalImages;
  final int imagesToProcess;
  final int totalOriginalSize;
  final int estimatedCompressedSize;
  final List<ImageMetadata> images;

  const CompressionAnalysis({
    required this.totalPages,
    required this.totalImages,
    required this.imagesToProcess,
    required this.totalOriginalSize,
    required this.estimatedCompressedSize,
    required this.images,
  });

  double get estimatedReductionPercent => totalOriginalSize > 0
      ? (1 - estimatedCompressedSize / totalOriginalSize) * 100
      : 0;

  int get estimatedBytesReduced => totalOriginalSize - estimatedCompressedSize;

  @override
  String toString() => 'CompressionAnalysis('
      'pages: $totalPages, '
      'images: $totalImages, '
      'toProcess: $imagesToProcess, '
      'original: ${_formatSize(totalOriginalSize)}, '
      'estimated: ${_formatSize(estimatedCompressedSize)}, '
      'reduction: ${estimatedReductionPercent.toStringAsFixed(1)}%'
      ')';

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}

class CancellationException implements Exception {
  @override
  String toString() => 'Compression cancelled';
}
