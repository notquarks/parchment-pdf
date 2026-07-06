import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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

import '../components/action_bottom_bar.dart';
import '../components/item_card.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<PickedPdfInfo> _selectedFiles = [];
  late final _controller = PdfPickController(
    isMounted: () => mounted,
    onEvent: _applyEvent,
    onError: (msg) => showErrorSnackBar(context, msg),
  );

  void _applyEvent(PdfFileEvent event) {
    switch (event) {
      case PdfFileAdded(:final info):
        setState(() => _selectedFiles.add(info));
      case PdfFileResolved(:final info):
        setState(() => _updateResolved(info));
      case PdfFileFailed(:final error):
        showErrorSnackBar(context, '${error.fileName}: ${error.error}');
    }
  }

  Future<void> _pickFiles() => _controller.pickAndProcess(allowMultiple: true);

  void _updateResolved(PickedPdfInfo info) {
    final index = _selectedFiles.indexWhere(
      (f) => f.file.path == info.file.path,
    );
    if (index != -1) _selectedFiles[index] = info;
  }

  int get _estimatedSize =>
      _selectedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);

  Future<String> _doMerge(
    Pdf pdf, {
    void Function(PdfTask<void>)? onTaskCreated,
  }) async {
    final settingsService = SettingsProvider.of(context).settingsService;

    final sources = _selectedFiles.map((f) => FileSource(f.file)).toList();

    final savedName =
        '${p.basenameWithoutExtension(_selectedFiles.first.file.path)}_merged_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    final downloadPath = await settingsService.getSavePath();

    final saveDir = Directory(downloadPath);
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final saveFile = File('${saveDir.path}/$savedName');
    final output = await FileSink.create(saveFile);
    final totalSize = _selectedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final sw = Stopwatch()..start();
    final task = pdf.merge(sources, output);
    onTaskCreated?.call(task);
    try {
      await task;
      sw.stop();
      debugPrint('PDF merge: ${sw.elapsedMilliseconds}ms | ${_selectedFiles.length} files, ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB total');
    } on PdfCancelled {
      await output.close();
      if (await saveFile.exists()) {
        await saveFile.delete();
      }
      rethrow;
    } finally {
      await output.close();
    }
    return saveFile.path;
  }

  void _startMerge() {
    final pdf = Pdf();
    PdfTask<void>? mergeTask;

    final mergeFuture = _doMerge(
      pdf,
      onTaskCreated: (t) => mergeTask = t,
    ).whenComplete(() => pdf.dispose());

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          messages: TaskMessages.merge,
          fileCount: _selectedFiles.length,
          mergeFuture: mergeFuture,
          onCancel: () async {
            final task = mergeTask;
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

  Widget _sortableFileItem(BuildContext context, int index) {
    final file = _selectedFiles[index];
    return Card(
      key: ValueKey(file),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.only(left: 8.0),
              child: Icon(
                Icons.drag_indicator,
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: ItemCard(
              key: ValueKey(file),
              title: p.basename(file.file.path),
              icon: const Icon(Icons.insert_drive_file),
              subtitle: file.pageCount != null
                  ? "${formatBytes(file.sizeBytes, 2)} • ${file.pageCount} pages"
                  : "${formatBytes(file.sizeBytes, 2)} • Loading…",
              onTap: () {},
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _selectedFiles.removeAt(index)),
            icon: Icon(
              Icons.close,
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _noDocs(context) {
    final shortest = MediaQuery.of(context).size.shortestSide;
    return Column(
      mainAxisSize: .max,
      crossAxisAlignment: .center,
      mainAxisAlignment: .center,
      children: [
        SizedBox(
          width: shortest * 0.6,
          height: shortest * 0.6,
          child: AspectRatio(
            aspectRatio: 1,
            child: InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(16),
              child: Column(
                mainAxisAlignment: .center,
                mainAxisSize: .max,
                spacing: 12,
                children: [
                  Text(
                    'Select Documents',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  M3EContainer.pill(
                    width: shortest * 0.4,
                    height: shortest * 0.4,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(Icons.playlist_add, size: shortest * 0.2),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _bottomBar(BuildContext context) {
    if (_selectedFiles.isEmpty) return null;
    return ActionBottomBar(
      label: 'Estimated Size',
      value: '~ ${formatBytes(_estimatedSize, 2)}',
      actions: [
        M3EFilledButton.tonal(
          shape: .square,
          onPressed: _pickFiles,
          child: const Icon(Icons.add),
        ),
        M3EButton.icon(
          onPressed: _startMerge,
          icon: const Icon(Icons.merge),
          label: const Text('Merge'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            title: Text("Merge"),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          if (_selectedFiles.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: ListTile(
                title: Text("${_selectedFiles.length} files selected"),
              ),
            ),
            SliverReorderableList(
              itemCount: _selectedFiles.length,
              onReorderItem: (oldIndex, newIndex) {
                setState(() {
                  final element = _selectedFiles.removeAt(oldIndex);
                  _selectedFiles.insert(newIndex, element);
                });
              },
              itemBuilder: _sortableFileItem,
            ),
          ] else
            SliverFillRemaining(child: _noDocs(context)),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }
}
