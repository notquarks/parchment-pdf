import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import '../models/compression_options.dart';
import 'compression_worker.dart';
import 'image_processor.dart';
import 'pdf_optimizer.dart';

class CompressionService {
  final CompressionWorker _worker;
  final PdfOptimizer _optimizer;
  final Future<int> Function(String path) _pageCount;
  bool _isDisposed = false;
  bool _workerInitialized = false;

  CompressionService({
    int? maxWorkers,
    PdfOptimizer? optimizer,
    Future<int> Function(String path)? pageCount,
  }) : _worker = CompressionWorker(maxWorkers: maxWorkers),
       _optimizer = optimizer ?? createPdfOptimizer(),
       _pageCount = pageCount ?? _openPdfPageCount;

  Future<void> initialize() async {
    _ensureNotDisposed();
  }

  Future<CompressionAnalysis> analyzePdf({
    required DataSource source,
    required CompressionOptions options,
  }) async {
    _ensureNotDisposed();

    final pdf = Pdf();
    try {
      final doc = await pdf.open(source);
      try {
        final pageCount = doc.pageCount;
        final images = <ImageMetadata>[];
        var totalOriginalSize = 0;

        for (var page = 0; page < pageCount; page++) {
          final imageStream = doc.extractImages(pages: PdfPages.single(page));
          await for (final image in imageStream) {
            final metadata = ImageMetadata(
              width: image.width,
              height: image.height,
              format: image.format,
              colorSpace: image.colorSpace,
              bitsPerComponent: image.bitsPerComponent,
              dataSize: image.data.length,
            );
            images.add(metadata);
            totalOriginalSize += image.data.length;
          }
        }

        var estimatedCompressedSize = 0;
        for (final image in images) {
          if (!image.shouldProcess(options)) {
            estimatedCompressedSize += image.dataSize;
            continue;
          }

          final ratio = ImageProcessor.estimateCompressionRatio(
            width: image.width,
            height: image.height,
            currentSize: image.dataSize,
            options: options,
            sourceDpi: image.estimatedDpi,
          );
          estimatedCompressedSize += (image.dataSize * ratio).round();
        }

        return CompressionAnalysis(
          totalPages: pageCount,
          totalImages: images.length,
          imagesToProcess: images.where((i) => i.shouldProcess(options)).length,
          totalOriginalSize: totalOriginalSize,
          estimatedCompressedSize: estimatedCompressedSize,
          images: images,
        );
      } finally {
        await doc.dispose();
      }
    } finally {
      await pdf.dispose();
    }
  }

  Future<CompressedPdfResult> compressPdf({
    required String filePath,
    required CompressionOptions options,
    required String outputPath,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    _ensureNotDisposed();

    final inputFile = File(filePath);
    final outputFile = File(outputPath);

    if (!await inputFile.exists()) {
      throw FileSystemException('Input PDF does not exist', filePath);
    }
    if (_samePath(inputFile, outputFile)) {
      throw ArgumentError('Input and output paths must be different');
    }

    final outputDirectory = outputFile.parent;
    if (!await outputDirectory.exists()) {
      await outputDirectory.create(recursive: true);
    }

    final operationId = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
    final temporaryFile = File('$outputPath.$operationId.tmp');
    final originalSize = await inputFile.length();

    try {
      await _deleteFileIfExists(temporaryFile);
      _throwIfCancelled(cancelToken);
      final totalPages = await _pageCount(filePath);

      if (options.mode != PdfCompressionMode.structural) {
        throw const PdfOptimizerException(
          'This compression mode is not available yet',
        );
      }

      final result = await _optimizer.optimize(
        inputPath: filePath,
        outputPath: temporaryFile.path,
        options: options,
        cancelToken: cancelToken,
      );
      if (!result.wasCompleted) {
        throw PdfOptimizerException(
          result.message ?? 'PDF optimizer is not installed',
        );
      }

      if (!await temporaryFile.exists() || await temporaryFile.length() == 0) {
        throw const PdfOptimizerException(
          'PDF optimizer produced an empty output file',
        );
      }

      _throwIfCancelled(cancelToken);

      final attemptedSize = await temporaryFile.length();
      final bytesSaved = originalSize - attemptedSize;
      final minimumUsefulSaving = _minimumUsefulPdfSaving(originalSize);

      if (bytesSaved < minimumUsefulSaving) {
        onProgress?.call(1, 1);
        return CompressedPdfResult(
          originalSize: originalSize,
          compressedSize: originalSize,
          attemptedSize: attemptedSize,
        );
      }

      await _validateOutput(
        path: temporaryFile.path,
        expectedPageCount: totalPages,
      );
      _throwIfCancelled(cancelToken);

      await _commitOutput(
        temporaryFile: temporaryFile,
        outputFile: outputFile,
        operationId: operationId,
      );
      onProgress?.call(1, 1);

      return CompressedPdfResult(
        outputPath: outputPath,
        originalSize: originalSize,
        compressedSize: attemptedSize,
        attemptedSize: attemptedSize,
      );
    } finally {
      await _deleteFileIfExists(temporaryFile);
    }
  }

  static Future<int> _openPdfPageCount(String path) async {
    final document = await pdfrx.PdfDocument.openFile(path);
    try {
      return document.pages.length;
    } finally {
      await document.dispose();
    }
  }

  Future<void> _validateOutput({
    required String path,
    required int expectedPageCount,
  }) async {
    if (await _pageCount(path) != expectedPageCount) {
      throw const PdfOptimizerException(
        'Output PDF page count does not match the input',
      );
    }
  }

  Future<void> _commitOutput({
    required File temporaryFile,
    required File outputFile,
    required String operationId,
  }) async {
    File? backupFile;

    try {
      if (await outputFile.exists()) {
        backupFile = File('${outputFile.path}.$operationId.backup');
        await _deleteFileIfExists(backupFile);
        await outputFile.rename(backupFile.path);
      }

      await temporaryFile.rename(outputFile.path);
      if (backupFile != null) {
        await _deleteFileIfExists(backupFile);
      }
    } catch (_) {
      await _deleteFileIfExists(outputFile);
      if (backupFile != null && await backupFile.exists()) {
        await backupFile.rename(outputFile.path);
      }
      rethrow;
    }
  }

  static int _minimumUsefulPdfSaving(int originalSize) {
    if (originalSize <= 0) return 1;
    final percentageSaving = (originalSize * 0.001).round();
    return percentageSaving > 1024 ? percentageSaving : 1024;
  }

  static bool _samePath(File first, File second) {
    final firstPath = first.absolute.path;
    final secondPath = second.absolute.path;
    if (Platform.isWindows) {
      return firstPath.toLowerCase() == secondPath.toLowerCase();
    }
    return firstPath == secondPath;
  }

  static void _throwIfCancelled(CancellationToken? cancelToken) {
    if (cancelToken?.isCancelled == true) {
      throw CancellationException();
    }
  }

  static Future<void> _deleteFileIfExists(File file) async {
    try {
      if (await file.exists()) {
        await file.delete();
      }
    } on FileSystemException {
      return;
    }
  }

  Future<CompressionResult> compressImages({
    required DataSource source,
    required CompressionOptions options,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    _ensureNotDisposed();

    if (!_workerInitialized) {
      await _worker.initialize();
      _workerInitialized = true;
    }

    final stopwatch = Stopwatch()..start();
    final pdf = Pdf();

    try {
      final doc = await pdf.open(source);
      try {
        final pageCount = doc.pageCount;
        final allImages = <Uint8List>[];
        final originalSizes = <int>[];

        for (var page = 0; page < pageCount; page++) {
          _throwIfCancelled(cancelToken);

          final imageStream = doc.extractImages(pages: PdfPages.single(page));
          await for (final image in imageStream) {
            allImages.add(image.data);
            originalSizes.add(image.data.length);
          }
        }

        if (allImages.isEmpty) {
          stopwatch.stop();
          return CompressionResult(processingTime: stopwatch.elapsed);
        }

        final batchResult = await _worker.processImagesDetailed(
          imageBytesList: allImages,
          options: options,
          convertToGrayscale: options.convertToGrayscale,
          onProgress: onProgress,
          cancelToken: cancelToken,
        );

        var totalOriginalSize = 0;
        var totalCompressedSize = 0;
        var imagesProcessed = 0;
        var imagesSkipped = 0;
        var imagesFailed = 0;
        final compressedImages = <ProcessedImage>[];

        for (var i = 0; i < batchResult.images.length; i++) {
          final originalImageSize = originalSizes[i];
          totalOriginalSize += originalImageSize;

          if (batchResult.errors[i] != null) {
            imagesFailed++;
            totalCompressedSize += originalImageSize;
            continue;
          }

          final processed = batchResult.images[i];
          if (processed == null) {
            imagesSkipped++;
            totalCompressedSize += originalImageSize;
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
        await doc.dispose();
      }
    } finally {
      stopwatch.stop();
      await pdf.dispose();
    }
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw StateError('CompressionService has been disposed');
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _worker.dispose();
  }
}

class CompressedPdfResult {
  final String? outputPath;
  final int originalSize;
  final int compressedSize;

  final int? attemptedSize;

  const CompressedPdfResult({
    this.outputPath,
    required this.originalSize,
    required this.compressedSize,
    this.attemptedSize,
  });

  bool get wasCompressed => outputPath != null;

  int get bytesReduced => originalSize - compressedSize;

  double get reductionPercent =>
      originalSize > 0 ? (bytesReduced / originalSize) * 100 : 0;
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
  String toString() =>
      'CompressionAnalysis('
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
