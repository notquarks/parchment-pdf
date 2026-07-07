import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
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

  late final _controller = PdfPickController(
    isMounted: () => mounted,
    onEvent: _handleEvent,
    onError: (msg) => showErrorSnackBar(context, msg),
  );

  void _handleEvent(PdfFileEvent event) {
    switch (event) {
      case PdfFileAdded(:final info):
        setState(() => _pickedFiles.add(info));
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

  Future<String> _compressFiles(
    Pdf pdf, {
    required int imageQuality,
    void Function(PdfTask<void>)? onTaskCreated,
  }) async {
    final settingsService = SettingsProvider.of(context).settingsService;
    final downloadPath = await settingsService.getSavePath();
    final saveDir = Directory(downloadPath);
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    String lastPath = '';
    for (final picked in _pickedFiles) {
      final source = FileSource(picked.file);
      final savedName =
          '${p.basenameWithoutExtension(picked.file.path)}_compressed_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      final saveFile = File('${saveDir.path}/$savedName');
      final output = await FileSink.create(saveFile);

      final task = pdf.compress(source, output, imageQuality: imageQuality);
      onTaskCreated?.call(task);
      try {
        await task;
      } on PdfCancelled {
        await output.close();
        if (await saveFile.exists()) {
          await saveFile.delete();
        }
        rethrow;
      } finally {
        await output.close();
      }
      lastPath = saveFile.path;
    }
    return lastPath;
  }

  void _startCompress(int quality) {
    final pdf = Pdf();
    PdfTask<void>? compressTask;

    final compressFuture = _compressFiles(
      pdf,
      imageQuality: quality,
      onTaskCreated: (t) => compressTask = t,
    ).whenComplete(() => pdf.dispose());

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          messages: TaskMessages.compress,
          fileCount: _pickedFiles.length,
          mergeFuture: compressFuture,
          onCancel: () async {
            final task = compressTask;
            if (task != null) {
              task.cancel();
            } else {
              await pdf.dispose();
            }
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
      appBar: AppBar(title: const Text('Compress')),
      body: _pickedFiles.isNotEmpty && _documentRef != null
          ? LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                if (isWide) {
                  return CompressWideLayout(
                    documentRef: _documentRef!,
                    files: _pickedFiles,
                    quality: _quality,
                    onQualityChanged: (v) => setState(() => _quality = v),
                    onAddFile: _pickFile,
                    onCompress: () => _startCompress(_quality),
                  );
                }
                return CompressNarrowLayout(
                  documentRef: _documentRef!,
                  files: _pickedFiles,
                  quality: _quality,
                  onQualityChanged: (v) => setState(() => _quality = v),
                );
              },
            )
          : CompressEmptyState(onPick: _pickFile),
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
