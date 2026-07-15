import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import '../models/compression_options.dart';
import 'image_processor.dart';

enum _WorkerMessageType { process, shutdown }

class _WorkerMessage {
  final _WorkerMessageType type;
  final int id;
  final Uint8List? imageBytes;
  final CompressionOptions? options;
  final int sourceDpi;
  final bool convertToGrayscale;

  const _WorkerMessage({
    required this.type,
    required this.id,
    this.imageBytes,
    this.options,
    this.sourceDpi = 72,
    this.convertToGrayscale = false,
  });
}

class _WorkerResult {
  final int id;
  final ProcessedImage? result;
  final String? error;

  const _WorkerResult({required this.id, this.result, this.error});
}

void _workerEntryPoint(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message is! _WorkerMessage) return;

    if (message.type == _WorkerMessageType.shutdown) {
      receivePort.close();
      return;
    }

    try {
      final processed = await ImageProcessor.processImage(
        imageBytes: message.imageBytes!,
        options: message.options!,
        sourceDpi: message.sourceDpi,
        convertToGrayscale: message.convertToGrayscale,
      );
      sendPort.send(_WorkerResult(id: message.id, result: processed));
    } catch (error) {
      sendPort.send(
        _WorkerResult(id: message.id, error: error.toString()),
      );
    }
  });
}

typedef ProgressCallback = void Function(int processed, int total);

class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }
}

class CancellationException implements Exception {
  @override
  String toString() => 'Compression cancelled';
}

class ImageProcessingBatchResult {
  final List<ProcessedImage?> images;
  final List<String?> errors;

  const ImageProcessingBatchResult({
    required this.images,
    required this.errors,
  });

  int get failedCount => errors.where((error) => error != null).length;
}

class CompressionWorker {
  final int _maxWorkers;
  final List<_WorkerPool> _workers = [];
  bool _isDisposed = false;
  Future<void>? _initializing;

  CompressionWorker({int? maxWorkers})
    : _maxWorkers = (maxWorkers ?? _defaultWorkerCount).clamp(1, 8).toInt();

  static int get _defaultWorkerCount {
    final processors = Platform.numberOfProcessors;
    if (processors <= 1) return 1;
    return processors < 4 ? processors : 4;
  }

  Future<void> initialize() async {
    if (_isDisposed) {
      throw StateError('Worker has been disposed');
    }
    if (_workers.isNotEmpty) return;

    final currentInitialization = _initializing;
    if (currentInitialization != null) {
      await currentInitialization;
      return;
    }

    final completer = Completer<void>();
    _initializing = completer.future;

    try {
      for (var i = 0; i < _maxWorkers; i++) {
        if (_isDisposed) {
          throw StateError('Worker has been disposed');
        }
        final worker = _WorkerPool();
        await worker.initialize();
        _workers.add(worker);
      }
      completer.complete();
    } catch (error, stackTrace) {
      for (final worker in _workers) {
        await worker.dispose();
      }
      _workers.clear();
      completer.completeError(error, stackTrace);
    } finally {
      _initializing = null;
    }

    await completer.future;
  }

  Future<List<ProcessedImage?>> processImages({
    required List<Uint8List> imageBytesList,
    required CompressionOptions options,
    int sourceDpi = 72,
    bool convertToGrayscale = false,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    final detailed = await processImagesDetailed(
      imageBytesList: imageBytesList,
      options: options,
      sourceDpi: sourceDpi,
      convertToGrayscale: convertToGrayscale,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );
    return detailed.images;
  }

  Future<ImageProcessingBatchResult> processImagesDetailed({
    required List<Uint8List> imageBytesList,
    required CompressionOptions options,
    int sourceDpi = 72,
    bool convertToGrayscale = false,
    ProgressCallback? onProgress,
    CancellationToken? cancelToken,
  }) async {
    if (_isDisposed) {
      throw StateError('Worker has been disposed');
    }
    if (cancelToken?.isCancelled == true) {
      throw CancellationException();
    }
    if (imageBytesList.isEmpty) {
      return const ImageProcessingBatchResult(images: [], errors: []);
    }

    await initialize();

    final results = List<ProcessedImage?>.filled(imageBytesList.length, null);
    final errors = List<String?>.filled(imageBytesList.length, null);
    var processedCount = 0;

    final batchSize = _workers.length * 2;
    for (var i = 0; i < imageBytesList.length; i += batchSize) {
      if (cancelToken?.isCancelled == true) {
        throw CancellationException();
      }

      final end = (i + batchSize).clamp(0, imageBytesList.length);
      final batchFutures = <Future<_WorkerResult>>[];

      for (var index = i; index < end; index++) {
        final worker = _workers[index % _workers.length];
        batchFutures.add(
          worker.process(
            itemId: index,
            imageBytes: imageBytesList[index],
            options: options,
            sourceDpi: sourceDpi,
            convertToGrayscale: convertToGrayscale,
          ),
        );
      }

      final batchResults = await Future.wait(batchFutures);
      for (final result in batchResults) {
        results[result.id] = result.result;
        errors[result.id] = result.error;
        processedCount++;
        onProgress?.call(processedCount, imageBytesList.length);
      }
    }

    return ImageProcessingBatchResult(images: results, errors: errors);
  }

  Future<ProcessedImage?> processImage({
    required Uint8List imageBytes,
    required CompressionOptions options,
    int sourceDpi = 72,
    bool convertToGrayscale = false,
  }) async {
    if (_isDisposed) {
      throw StateError('Worker has been disposed');
    }

    await initialize();
    final result = await _workers.first.process(
      itemId: 0,
      imageBytes: imageBytes,
      options: options,
      sourceDpi: sourceDpi,
      convertToGrayscale: convertToGrayscale,
    );

    return result.result;
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    final initializing = _initializing;
    if (initializing != null) {
      try {
        await initializing;
      } catch (_) {}
    }

    for (final worker in _workers) {
      await worker.dispose();
    }
    _workers.clear();
  }
}

class _WorkerPool {
  Isolate? _isolate;
  SendPort? _sendPort;
  final _receivePort = ReceivePort();
  final _pending = <int, Completer<_WorkerResult>>{};
  bool _isInitialized = false;
  bool _isDisposed = false;
  int _nextRequestId = 0;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isDisposed) {
      throw StateError('Worker pool has been disposed');
    }

    final ready = Completer<SendPort>();
    _receivePort.listen((dynamic message) {
      if (message is SendPort && !_isInitialized) {
        _isInitialized = true;
        if (!ready.isCompleted) ready.complete(message);
      } else if (message is _WorkerResult) {
        final pending = _pending.remove(message.id);
        if (pending != null && !pending.isCompleted) {
          pending.complete(message);
        }
      }
    });

    try {
      _isolate = await Isolate.spawn(
        _workerEntryPoint,
        _receivePort.sendPort,
      );
      _sendPort = await ready.future.timeout(const Duration(seconds: 15));
    } catch (_) {
      _receivePort.close();
      _isolate?.kill(priority: Isolate.immediate);
      rethrow;
    }
  }

  Future<_WorkerResult> process({
    required int itemId,
    required Uint8List imageBytes,
    required CompressionOptions options,
    required int sourceDpi,
    required bool convertToGrayscale,
  }) async {
    if (!_isInitialized || _isDisposed) {
      return _WorkerResult(id: itemId, error: 'Worker is not available');
    }

    final requestId = _nextRequestId++;
    final completer = Completer<_WorkerResult>();
    _pending[requestId] = completer;

    _sendPort!.send(
      _WorkerMessage(
        type: _WorkerMessageType.process,
        id: requestId,
        imageBytes: imageBytes,
        options: options,
        sourceDpi: sourceDpi,
        convertToGrayscale: convertToGrayscale,
      ),
    );

    try {
      final result = await completer.future.timeout(
        const Duration(minutes: 2),
        onTimeout: () {
          _pending.remove(requestId);
          return _WorkerResult(id: requestId, error: 'Worker timeout');
        },
      );
      return _WorkerResult(
        id: itemId,
        result: result.result,
        error: result.error,
      );
    } catch (error) {
      _pending.remove(requestId);
      return _WorkerResult(id: itemId, error: error.toString());
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    for (final pending in _pending.values) {
      if (!pending.isCompleted) {
        pending.complete(
          const _WorkerResult(id: -1, error: 'Worker disposed'),
        );
      }
    }
    _pending.clear();

    if (_isInitialized) {
      _sendPort?.send(
        const _WorkerMessage(type: _WorkerMessageType.shutdown, id: -1),
      );
    }
    _receivePort.close();
    _isolate?.kill(priority: Isolate.immediate);
  }
}
