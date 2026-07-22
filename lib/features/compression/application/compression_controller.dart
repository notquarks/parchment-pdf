import 'dart:async';

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
  int _quality = 75;
  int _selectedIndex = 0;
  String _savePath = '';
  bool _initialized = false;

  List<PickedPdfInfo> get pickedFiles => List.unmodifiable(_pickedFiles);
  PdfDocumentRef? get documentRef => _documentRef;
  int get quality => _quality;
  int get selectedIndex => _selectedIndex;
  String get savePath => _savePath;
  bool get hasFiles => _pickedFiles.isNotEmpty && _documentRef != null;

  int get totalInputSize =>
      _pickedFiles.fold<int>(0, (total, file) => total + file.sizeBytes);

  String get compressionLabel {
    if (_quality >= 85) return 'Smaller loss';
    if (_quality >= 65) return 'Recommended';
    return 'Smallest size';
  }

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
    notifyListeners();
  }

  Future<bool> clearFiles() async {
    if (_pickedFiles.isEmpty) return true;
    _removeDocumentListener?.call();
    _removeDocumentListener = null;
    _pickedFiles.clear();
    _selectedIndex = 0;
    _documentRef = null;
    notifyListeners();
    return true;
  }

  void setQuality(int value) {
    if (_quality == value) return;
    _quality = value;
    notifyListeners();
  }

  Future<List<String>> compressFiles({
    required CancellationToken cancelToken,
  }) async {
    final options = CompressionOptions.withQuality(_quality);
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
    notifyListeners();
  }

  Future<void> refreshSavePath() async {
    final savePath = await settingsService.getSavePath();
    if (!_isMounted()) return;
    _savePath = savePath;
    notifyListeners();
  }

  @override
  void dispose() {
    _removeDocumentListener?.call();
    super.dispose();
  }
}
