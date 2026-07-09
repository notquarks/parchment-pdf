import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/compression/compression.dart';
import 'package:pdf_tools/components/action_bottom_bar.dart';
import 'package:pdf_tools/components/compress/compress_empty_state.dart';
import 'package:pdf_tools/components/compress/compress_narrow_layout.dart';
import 'package:pdf_tools/components/compress/compress_wide_layout.dart';
import 'package:pdf_tools/model/task_messages.dart';
import 'package:pdf_tools/screen/result_screen.dart';
import 'package:pdf_tools/services/settings_provider.dart';
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdf_tools/util/pdf_pick_controller.dart';
import 'package:pdf_tools/util/snackbar.dart';
import 'package:pdf_tools/util/string_util.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  final List<PickedPdfInfo> _pickedFiles = [];
  PdfDocumentRef? _documentRef;
  VoidCallback? _removeListener;
  int _quality = 75;
  bool _unembedFonts = false;
  int _selectedIndex = 0;

  late final _controller = PdfPickController(
    isMounted: () => mounted,
    onEvent: _handleEvent,
    onError: (msg) => showErrorSnackBar(context, msg),
  );

  void _handleEvent(PdfFileEvent event) {
    switch (event) {
      case PdfFileAdded(:final info):
        setState(() {
          _pickedFiles.add(info);
          _selectedIndex = _pickedFiles.length - 1;
        });
        _loadDocument(info.file.path);
      case PdfFileResolved(:final info):
        setState(() => _updateFile(info));
      case PdfFileFailed(:final error):
        showErrorSnackBar(context, '${error.fileName}: ${error.error}');
    }
  }

  void _loadDocument(String path) {
    _removeListener?.call();
    _documentRef = PdfDocumentRefFile(path);
    final listenable = _documentRef!.resolveListenable();
    _removeListener = listenable.addListener(() {});
    listenable.load();
  }

  void _selectFile(int index) {
    if (index < 0 || index >= _pickedFiles.length) return;
    setState(() => _selectedIndex = index);
    _loadDocument(_pickedFiles[index].file.path);
  }

  void _updateFile(PickedPdfInfo info) {
    final index = _pickedFiles.indexWhere((f) => f.file.path == info.file.path);
    if (index != -1) _pickedFiles[index] = info;
  }

  Future<void> _pickFile() => _controller.pickAndProcess(
    allowMultiple: true,
    failurePrefix: 'Failed to load file',
  );

  @override
  void dispose() {
    _removeListener?.call();
    super.dispose();
  }

  Future<List<String>> _compressFiles({
    required int imageQuality,
    required bool unembedFonts,
    required CancellationToken cancelToken,
  }) async {
    final settingsService = SettingsProvider.of(context).settingsService;
    final downloadPath = await settingsService.getSavePath();
    final saveDir = Directory(downloadPath);
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final options = CompressionOptions.withQuality(imageQuality);
    final savedPaths = <String>[];

    var index = 0;
    for (final picked in _pickedFiles) {
      if (cancelToken.isCancelled) break;

      final savedName =
          '${p.basenameWithoutExtension(picked.file.path)}_min_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}_$index.pdf';
      final saveFile = File('${saveDir.path}/$savedName');

      final service = CompressionService();
      await service.initialize();
      try {
        await service.compressPdf(
          filePath: picked.file.path,
          options: options,
          outputPath: saveFile.path,
          cancelToken: cancelToken,
        );
      } finally {
        await service.dispose();
      }

      index++;
      savedPaths.add(saveFile.path);
    }
    return savedPaths;
  }

  void _startCompress(int quality) {
    final cancelToken = CancellationToken();

    final compressFuture = _compressFiles(
      imageQuality: quality,
      unembedFonts: _unembedFonts,
      cancelToken: cancelToken,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          messages: TaskMessages.compress,
          fileCount: _pickedFiles.length,
          mergeMultiFuture: compressFuture,
          onCancel: () async {
            cancelToken.cancel();
          },
        ),
      ),
    );
  }

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Compress'),
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      ),
      body: _pickedFiles.isNotEmpty && _documentRef != null
          ? LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                if (isWide) {
                  return CompressWideLayout(
                    documentRef: _documentRef!,
                    files: _pickedFiles,
                    selectedIndex: _selectedIndex,
                    quality: _quality,
                    unembedFonts: _unembedFonts,
                    onQualityChanged: (v) => setState(() => _quality = v),
                    onUnembedFontsChanged: (v) =>
                        setState(() => _unembedFonts = v),
                    onAddFile: _pickFile,
                    onCompress: () => _startCompress(_quality),
                    onFileSelected: _selectFile,
                  );
                }
                return CompressNarrowLayout(
                  documentRef: _documentRef!,
                  files: _pickedFiles,
                  selectedIndex: _selectedIndex,
                  quality: _quality,
                  unembedFonts: _unembedFonts,
                  onQualityChanged: (v) => setState(() => _quality = v),
                  onUnembedFontsChanged: (v) =>
                      setState(() => _unembedFonts = v),
                  onFileSelected: _selectFile,
                );
              },
            )
          : Center(child: CompressEmptyState(onPick: _pickFile)),
      bottomNavigationBar: _pickedFiles.isNotEmpty && !_isWide(context)
          ? ActionBottomBar(
              label: 'File Size',
              value: formatBytes(_pickedFiles.last.sizeBytes, 2),
              actions: [
                M3EFilledButton.tonal(
                  shape: .square,
                  onPressed: _pickFile,
                  child: const Icon(Icons.add),
                ),
                M3EButton.icon(
                  onPressed: () => _startCompress(_quality),
                  icon: const Icon(Icons.compress),
                  label: const Text('Compress'),
                ),
              ],
            )
          : null,
    );
  }
}
