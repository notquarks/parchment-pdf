import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:pdf_tools/core/utils/pdf_output.dart';
import 'package:pdf_tools/core/utils/pdf_pick_controller.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/features/compression/data/models/compression_options.dart';
import 'package:pdf_tools/features/compression/data/services/compression_service.dart';
import 'package:pdf_tools/features/compression/data/services/compression_worker.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressionController extends ChangeNotifier {
  CompressionController({
    required this.settingsService,
    required this.onError,
    bool Function()? isMounted,
  }) : _isMounted = isMounted ?? (() => true);

  final SettingsService settingsService;
  final void Function(String message) onError;
  final bool Function() _isMounted;

  final List<PickedPdfInfo> _pickedFiles = [];
  PdfDocumentRef? _documentRef;
  VoidCallback? _removeDocumentListener;
  CompressionPreset _selectedPreset = CompressionPreset.balanced;
  int _advancedQuality = 75;
  int _advancedDpiTarget = 144;
  bool _advancedGrayscale = false;
  bool _advancedStripMetadata = false;
  int _selectedIndex = 0;
  String _savePath = '';
  bool _initialized = false;
  final Map<String, CompressionEstimate> _estimateCache = {};
  Timer? _estimateTimer;
  int _estimateGeneration = 0;
  bool _estimateRunning = false;
  bool _estimatePending = false;
  CancellationToken? _estimateCancelToken;

  List<PickedPdfInfo> get pickedFiles => List.unmodifiable(_pickedFiles);
  PdfDocumentRef? get documentRef => _documentRef;
  CompressionPreset get selectedPreset => _selectedPreset;
  int get advancedQuality => _advancedQuality;
  int get advancedDpiTarget => _advancedDpiTarget;
  bool get advancedGrayscale => _advancedGrayscale;
  bool get advancedStripMetadata => _advancedStripMetadata;
  int get selectedIndex => _selectedIndex;
  String get savePath => _savePath;
  bool get hasFiles => _pickedFiles.isNotEmpty && _documentRef != null;

  CompressionEstimate? get selectedEstimate {
    if (_pickedFiles.isEmpty) return null;
    return _estimateCache[_estimateKey(_pickedFiles[_selectedIndex])];
  }

  bool get isEstimatingSelected => _estimateRunning && selectedEstimate == null;

  int get totalInputSize =>
      _pickedFiles.fold<int>(0, (total, file) => total + file.sizeBytes);

    int get quality => _advancedQuality;

    PdfCompressionMode get mode => _selectedPreset.mode;

  String get compressionLabel => _selectedPreset.title;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final savePath = await settingsService.getSavePath();
    if (!_isMounted()) return;
    _savePath = savePath;
    notifyListeners();
  }

  late final PdfPickController _pickController = PdfPickController(
    isMounted: _isMounted,
    onEvent: _handleEvent,
    onError: onError,
  );

  Future<void> pickFiles() {
    return _pickController.pickAndProcess(
      allowMultiple: true,
      failurePrefix: 'Failed to load file',
    );
  }

  void selectFile(int index) {
    if (index < 0 || index >= _pickedFiles.length) return;
    if (_selectedIndex != index) {
      _selectedIndex = index;
    }
    _loadDocument(_pickedFiles[index].file.path);
    _scheduleEstimate();
    notifyListeners();
  }

  void removeFile(int index) {
    if (index < 0 || index >= _pickedFiles.length) return;

    _pickedFiles.removeAt(index);
    if (_pickedFiles.isEmpty) {
      _removeDocumentListener?.call();
      _removeDocumentListener = null;
      _selectedIndex = 0;
      _documentRef = null;
      _cancelEstimate();
      notifyListeners();
      return;
    }

    var nextIndex = _selectedIndex;
    if (index < nextIndex) {
      nextIndex--;
    } else if (nextIndex >= _pickedFiles.length) {
      nextIndex = _pickedFiles.length - 1;
    }

    _selectedIndex = nextIndex;
    _loadDocument(_pickedFiles[nextIndex].file.path);
    _scheduleEstimate();
    notifyListeners();
  }

  Future<bool> clearFiles() async {
    if (_pickedFiles.isEmpty) return true;
    _removeDocumentListener?.call();
    _removeDocumentListener = null;
    _pickedFiles.clear();
    _selectedIndex = 0;
    _documentRef = null;
    _cancelEstimate();
    notifyListeners();
    return true;
  }

  void setPreset(CompressionPreset preset) {
    if (_selectedPreset == preset) return;
    _selectedPreset = preset;
    _advancedQuality = preset.quality;
    _advancedDpiTarget = preset.dpiTarget;
    _scheduleEstimate();
    notifyListeners();
  }

  void setAdvancedQuality(int value) {
    if (_advancedQuality == value) return;
    _advancedQuality = value.clamp(10, 100).toInt();
    _scheduleEstimate();
    notifyListeners();
  }

  void setAdvancedDpiTarget(int value) {
    if (_advancedDpiTarget == value) return;
    _advancedDpiTarget = value.clamp(72, 300).toInt();
    _scheduleEstimate();
    notifyListeners();
  }

  void setAdvancedGrayscale(bool value) {
    if (_advancedGrayscale == value) return;
    _advancedGrayscale = value;
    _scheduleEstimate();
    notifyListeners();
  }

  void setAdvancedStripMetadata(bool value) {
    if (_advancedStripMetadata == value) return;
    _advancedStripMetadata = value;
    _scheduleEstimate();
    notifyListeners();
  }

  Future<List<String>> compressFiles({
    required CancellationToken cancelToken,
  }) async {
    final options = _activeOptions;
    final savedPaths = <String>[];
    final files = _pickedFiles;

    for (var index = 0; index < files.length; index++) {
      if (cancelToken.isCancelled) break;
      final picked = files[index];
      final savedName = pdfOutputName(
        sourcePath: picked.file.path,
        suffix: 'min_',
        ending: '_$index',
      );
      final saveFile = await createPdfFile(
        settingsService: settingsService,
        fileName: savedName,
      );
      final service = CompressionService();
      await service.initialize();
      try {
        final result = await service.compressPdf(
          filePath: picked.file.path,
          options: options,
          outputPath: saveFile.path,
          cancelToken: cancelToken,
        );
        if (result.wasCompressed) {
          savedPaths.add(result.outputPath!);
        }
      } finally {
        await service.dispose();
      }
    }

    return savedPaths;
  }

  void _handleEvent(PdfFileEvent event) {
    switch (event) {
      case PdfFileAdded(:final info):
        final existingIndex = _pickedFiles.indexWhere(
          (file) => file.file.absolute.path == info.file.absolute.path,
        );
        if (existingIndex >= 0) {
          selectFile(existingIndex);
          return;
        }
        _pickedFiles.add(info);
        _selectedIndex = _pickedFiles.length - 1;
        _loadDocument(info.file.path);
        _scheduleEstimate();
        notifyListeners();
      case PdfFileResolved(:final info):
        _updateFile(info);
      case PdfFileFailed(:final error):
        onError('${error.fileName}: ${error.error}');
    }
  }

  void _loadDocument(String path) {
    _removeDocumentListener?.call();
    final documentRef = PdfDocumentRefFile(path);
    final listenable = documentRef.resolveListenable();
    _removeDocumentListener = listenable.addListener(() {});
    _documentRef = documentRef;
    listenable.load();
    notifyListeners();
  }

  void _updateFile(PickedPdfInfo info) {
    final index = _pickedFiles.indexWhere(
      (file) => file.file.absolute.path == info.file.absolute.path,
    );
    if (index < 0) return;
    _pickedFiles[index] = info;
    _scheduleEstimate();
    notifyListeners();
  }

  CompressionOptions get _activeOptions => CompressionOptions(
    quality: _advancedQuality,
    dpiTarget: _advancedDpiTarget,
    dpiThreshold: _selectedPreset.dpiThreshold,
    mode: _selectedPreset.mode,
    downscale: _advancedDpiTarget > 0,
    convertToGrayscale: _advancedGrayscale,
    stripMetadata: _advancedStripMetadata,
  );

  String _estimateKey(PickedPdfInfo file) {
    final options = _activeOptions;
    var modifiedAt = 0;
    try {
      modifiedAt = file.file.lastModifiedSync().millisecondsSinceEpoch;
    } on FileSystemException {
          }
    return '${file.file.absolute.path}|${file.sizeBytes}|$modifiedAt|'
        '${options.mode.name}|${options.quality}|${options.dpiTarget}|'
        '${options.dpiThreshold}|${options.convertToGrayscale}|'
        '${options.stripMetadata}';
  }

  void _cancelEstimate() {
    _estimateGeneration++;
    _estimateTimer?.cancel();
    _estimateTimer = null;
    _estimateCancelToken?.cancel();
    _estimateCancelToken = null;
    _estimatePending = false;
  }

  void _scheduleEstimate() {
    _estimateGeneration++;
    _estimateTimer?.cancel();
    _estimateCancelToken?.cancel();
    if (_pickedFiles.isEmpty) return;
    final generation = _estimateGeneration;
    _estimateTimer = Timer(
      const Duration(milliseconds: 350),
      () => _estimateSelectedFile(generation),
    );
  }

  Future<void> _estimateSelectedFile(int generation) async {
    if (!_isMounted() || _pickedFiles.isEmpty ||
        generation != _estimateGeneration) {
      return;
    }
    if (_estimateRunning) {
      _estimatePending = true;
      return;
    }

    final file = _pickedFiles[_selectedIndex];
    final key = _estimateKey(file);
    if (_estimateCache.containsKey(key)) {
      notifyListeners();
      return;
    }

    _estimateRunning = true;
    _estimatePending = false;
    final estimateCancelToken = CancellationToken();
    _estimateCancelToken = estimateCancelToken;
    notifyListeners();
    final service = CompressionService();
    try {
      await service.initialize();
      final estimate = await service.estimatePdf(
        filePath: file.file.path,
        options: _activeOptions,
        cancelToken: estimateCancelToken,
      );
      if (_isMounted() && generation == _estimateGeneration) {
        _estimateCache[key] = estimate;
      }
    } on CancellationException {
          } catch (_) {
          } finally {
      await service.dispose();
      if (identical(_estimateCancelToken, estimateCancelToken)) {
        _estimateCancelToken = null;
      }
      _estimateRunning = false;
      if (_isMounted()) notifyListeners();
      if (_estimatePending && _isMounted()) {
        _estimatePending = false;
        _scheduleEstimate();
      }
    }
  }

  Future<void> refreshSavePath() async {
    final savePath = await settingsService.getSavePath();
    if (!_isMounted()) return;
    _savePath = savePath;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelEstimate();
    _removeDocumentListener?.call();
    super.dispose();
  }
}
