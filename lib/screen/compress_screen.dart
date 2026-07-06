import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
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
  VoidCallback? _removeDocListener;
  int _qualitySize = 75;
  late final _controller = PdfPickController(
    isMounted: () => mounted,
    onEvent: _applyEvent,
    onError: (msg) => showErrorSnackBar(context, msg),
  );

  void _applyEvent(PdfFileEvent event) {
    switch (event) {
      case PdfFileAdded(:final info):
        setState(() => _pickedFiles.add(info));
        _preloadDocument(info.file.path);
      case PdfFileResolved(:final info):
        setState(() => _updateResolved(info));
      case PdfFileFailed(:final error):
        showErrorSnackBar(context, '${error.fileName}: ${error.error}');
    }
  }

  void _preloadDocument(String path) {
    _removeDocListener?.call();
    _documentRef = PdfDocumentRefFile(path);
    final listenable = _documentRef!.resolveListenable();
    _removeDocListener = listenable.addListener(() {});
    listenable.load();
  }

  void _updateResolved(PickedPdfInfo info) {
    final index = _pickedFiles.indexWhere((f) => f.file.path == info.file.path);
    if (index != -1) _pickedFiles[index] = info;
  }

  Future<void> _pickFile() => _controller.pickAndProcess(
    allowMultiple: true,
    failurePrefix: 'Failed to load file',
  );

  @override
  void dispose() {
    _removeDocListener?.call();
    super.dispose();
  }

  Future<String> _doCompress(
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

    final compressFuture = _doCompress(
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

  PickedPdfInfo? _currentFile(String? sourceName) {
    if (_pickedFiles.isEmpty) return null;
    return _pickedFiles.firstWhere(
      (f) => f.file.path == sourceName,
      orElse: () => _pickedFiles.first,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compress')),
      body: _pickedFiles.isNotEmpty && _documentRef != null
          ? LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                if (isWide) return _buildWideLayout(constraints);
                return _buildNarrowLayout();
              },
            )
          : Center(child: _noDocs(context)),
      bottomNavigationBar: _pickedFiles.isNotEmpty && _isWide(context)
          ? null
          : _bottomBar(),
    );
  }

  Widget _buildNarrowLayout() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 24,
        children: [_buildPreviewCard(), _buildFileInfo(), _buildControls()],
      ),
    );
  }

  bool _isWide(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  Widget _buildWideLayout(BoxConstraints constraints) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        mainAxisSize: .max,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 24,
        children: [
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: PdfDocumentViewBuilder(
                documentRef: _documentRef!,
                builder: (context, document) {
                  if (document == null) {
                    return Center(
                      child: Icon(
                        Icons.description_outlined,
                        size: 32,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    );
                  }
                  return AspectRatio(
                    aspectRatio: 0.65,
                    child: PdfPageView(
                      document: document,
                      pageNumber: 1,
                      alignment: Alignment.center,
                    ),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: Column(
              spacing: 16,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFileInfo(isWide: true),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildControls(),
                    const Spacer(),
                    _buildInlineActions(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final shortest = MediaQuery.of(context).size.shortestSide;
    return PdfDocumentViewBuilder(
      documentRef: _documentRef!,
      builder: (context, document) {
        if (document == null) {
          return Card(
            child: SizedBox(
              width: shortest * 0.6,
              child: AspectRatio(
                aspectRatio: 0.65,
                child: Center(
                  child: _loadingSpinner(context, shortest: shortest),
                ),
              ),
            ),
          );
        }
        return Card(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: MediaQuery.of(context).size.shortestSide * 0.6,
            child: AspectRatio(
              aspectRatio: 0.65,
              child: PdfPageView(
                document: document,
                pageNumber: 1,
                alignment: Alignment.center,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFileInfo({bool isWide = false}) {
    return PdfDocumentViewBuilder(
      documentRef: _documentRef!,
      builder: (context, document) {
        if (document == null) return const SizedBox.shrink();
        final file = _currentFile(document.sourceName);
        final name = Text(
          p.basename(document.sourceName),
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: isWide ? TextAlign.start : TextAlign.center,
        );
        final chip = (file != null)
            ? Chip(
                shape: const StadiumBorder(),
                label: Text(
                  '${formatBytes(file.sizeBytes, 2)} • ${document.pages.length} pages',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : null;
        if (isWide && chip != null) {
          return Row(
            spacing: 12,
            children: [
              Expanded(child: name),
              chip,
            ],
          );
        }
        return Column(children: [name, ?chip]);
      },
    );
  }

  Widget _buildControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 12,
      children: [
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _qualitySize.toDouble(),
                min: 10,
                max: 100,
                divisions: 18,
                onChanged: (v) => setState(() => _qualitySize = v.round()),
              ),
            ),
            FilterChip(
              onSelected: null,
              showCheckmark: false,
              selected: true,
              shape: const StadiumBorder(),
              label: Text('$_qualitySize'),
            ),
          ],
        ),
        Text('Preset', style: Theme.of(context).textTheme.titleMedium),
        Row(
          spacing: 8,
          children: [
            _qualityButton(90, 'Minimal'),
            _qualityButton(75, 'Medium'),
            _qualityButton(50, 'Full'),
          ],
        ),
      ],
    );
  }

  Widget _qualityButton(int quality, String label) {
    final selected = _qualitySize == quality;
    return Expanded(
      child: selected
          ? M3EFilledButton(
              onPressed: () => setState(() => _qualitySize = quality),
              child: Text(label),
            )
          : M3EFilledButton.tonal(
              onPressed: () => setState(() => _qualitySize = quality),
              child: Text(label),
            ),
    );
  }

  Widget _buildInlineActions() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        spacing: 8,
        children: [
          M3EFilledButton.tonal(
            shape: .square,
            onPressed: _pickFile,
            child: const Icon(Icons.add),
          ),
          Expanded(
            child: M3EButton.icon(
              onPressed: () => _startCompress(_qualitySize),
              icon: const Icon(Icons.compress),
              label: const Text('Compress'),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _bottomBar() {
    if (_pickedFiles.isEmpty) return null;
    final file = _pickedFiles.last;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('File Size', style: Theme.of(context).textTheme.titleSmall),
              Text(
                formatBytes(file.sizeBytes, 2),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          Row(
            spacing: 8,
            children: [
              M3EFilledButton.tonal(
                shape: .square,
                onPressed: _pickFile,
                child: const Icon(Icons.add),
              ),
              M3EButton.icon(
                onPressed: () => _startCompress(_qualitySize),
                icon: const Icon(Icons.compress),
                label: const Text('Compress'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _noDocs(BuildContext context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    final containerSize = shortest * 0.5;
    final pillSize = containerSize * 0.6;
    final iconSize = pillSize * 0.4;
    return Column(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: containerSize,
          height: containerSize,
          child: InkWell(
            onTap: _pickFile,
            borderRadius: BorderRadius.circular(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              spacing: 12,
              children: [
                Text(
                  'Select a Document',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                M3EContainer.pill(
                  width: pillSize,
                  height: pillSize,
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Icon(Icons.insert_drive_file, size: iconSize),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _loadingSpinner(BuildContext context, {required double shortest}) {
    return SizedBox(
      width: shortest * 0.4,
      height: shortest * 0.4,
      child: LoadingIndicatorM3E(variant: LoadingIndicatorM3EVariant.contained),
    );
  }
}
