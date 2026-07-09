import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'compression_options.dart';
import 'image_processor.dart';

enum _WorkerMessageType {
  process,
  shutdown,
}

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

  const _WorkerResult({
    required this.id,
    this.result,
    this.error,
  });
}

void _workerEntryPoint(SendPort sendPort) {
  final receivePort = ReceivePort();

  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) {
    if (message is _WorkerMessage) {
      if (message.type == _WorkerMessageType.shutdown) {
        receivePort.close();
        return;
      }

      try {
        final result = ImageProcessor.processImage(
          imageBytes: message.imageBytes!,
          options: message.options!,
          sourceDpi: message.sourceDpi,
          convertToGrayscale: message.convertToGrayscale,
        );

        result.then((processed) {
          sendPort.send(_WorkerResult(
            id: message.id,
            result: processed,
          ));
        }).catchError((error) {
          sendPort.send(_WorkerResult(
            id: message.id,
            error: error.toString(),
          ));
        });
      } catch (e) {
        sendPort.send(_WorkerResult(
          id: message.id,
          error: e.toString(),
        ));
      }
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

class CompressionWorker {
  final int _maxWorkers;
  final List<_WorkerPool> _workers = [];
  bool _isDisposed = false;

  CompressionWorker({int? maxWorkers})
      : _maxWorkers = maxWorkers ?? _defaultWorkerCount;

  static int get _defaultWorkerCount {
    final processors = Platform.numberOfProcessors;
    return processors < 4 ? processors : 4;
  }

  Future<void> initialize() async {
    for (var i = 0; i < _maxWorkers; i++) {
      final worker = _WorkerPool();
      await worker.initialize();
      _workers.add(worker);
    }
  }

  Future<List<ProcessedImage?>> processImages({
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

    final results = List<ProcessedImage?>.filled(imageBytesList.length, null);
    var processedCount = 0;

    final batchSize = _workers.length * 2;
    for (var i = 0; i < imageBytesList.length; i += batchSize) {
      if (cancelToken?.isCancelled == true) {
        break;
      }

      final end = (i + batchSize).clamp(0, imageBytesList.length);
      final batch = imageBytesList.sublist(i, end);

      final batchFutures = <Future<_WorkerResult>>[];

      for (var j = 0; j < batch.length; j++) {
        final workerIndex = (i + j) % _workers.length;
        final worker = _workers[workerIndex];

        final future = worker.process(
          id: i + j,
          imageBytes: batch[j],
          options: options,
          sourceDpi: sourceDpi,
          convertToGrayscale: convertToGrayscale,
        );
        batchFutures.add(future);
      }

      final batchResults = await Future.wait(batchFutures);

      for (final result in batchResults) {
        results[result.id] = result.result;
        processedCount++;
        onProgress?.call(processedCount, imageBytesList.length);
      }
    }

    return results;
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

    final worker = _workers.first;
    final result = await worker.process(
      id: 0,
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

    for (final worker in _workers) {
      await worker.dispose();
    }
    _workers.clear();
  }
}

class _WorkerPool {
  late Isolate _isolate;
  late SendPort _sendPort;
  final _receivePort = ReceivePort();
  final _pending = <int, Completer<_WorkerResult>>{};
  bool _isInitialized = false;

  Future<void> initialize() async {
    _isolate = await Isolate.spawn(
      _workerEntryPoint,
      _receivePort.sendPort,
    );

    final completer = Completer<SendPort>();
    _receivePort.listen((dynamic message) {
      if (message is SendPort && !_isInitialized) {
        _isInitialized = true;
        completer.complete(message);
      } else if (message is _WorkerResult) {
        final pending = _pending.remove(message.id);
        if (pending != null && !pending.isCompleted) {
          pending.complete(message);
        }
      }
    });

    _sendPort = await completer.future;
  }

  Future<_WorkerResult> process({
    required int id,
    required Uint8List imageBytes,
    required CompressionOptions options,
    required int sourceDpi,
    required bool convertToGrayscale,
  }) async {
    final completer = Completer<_WorkerResult>();
    _pending[id] = completer;

    _sendPort.send(_WorkerMessage(
      type: _WorkerMessageType.process,
      id: id,
      imageBytes: imageBytes,
      options: options,
      sourceDpi: sourceDpi,
      convertToGrayscale: convertToGrayscale,
    ));

    try {
      return await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          _pending.remove(id);
          return _WorkerResult(
            id: id,
            error: 'Worker timeout',
          );
        },
      );
    } catch (e) {
      _pending.remove(id);
      return _WorkerResult(
        id: id,
        error: e.toString(),
      );
    }
  }

  Future<void> dispose() async {
    _receivePort.close();
    _isolate.kill();
  }
}
