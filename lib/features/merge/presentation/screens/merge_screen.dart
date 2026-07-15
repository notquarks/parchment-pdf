import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/features/compression/data/models/task_messages.dart';
import 'package:pdf_tools/features/result/presentation/screens/result_screen.dart';
import 'package:pdf_tools/core/utils/pdf_confirmation.dart';
import 'package:pdf_tools/core/utils/pdf_output.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/core/utils/pdf_pick_controller.dart';
import 'package:pdf_tools/core/utils/snackbar_utils.dart';
import 'package:pdf_tools/core/utils/string_utils.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';

import 'package:pdf_tools/core/widgets/action_bottom_bar.dart';
import 'package:pdf_tools/core/widgets/item_card.dart';
import 'package:pdf_tools/features/merge/merge.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<PickedPdfInfo> _selectedFiles = [];
  String _savePath = '';
  late final _controller = PdfPickController(
    isMounted: () => mounted,
    onEvent: _applyEvent,
    onError: (msg) => showErrorSnackBar(context, msg),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSavePath();
  }

  Future<void> _loadSavePath() async {
    final settingsService = SettingsProvider.of(context).settingsService;
    final path = await settingsService.getSavePath();
    if (!mounted) return;
    setState(() => _savePath = path);
  }

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

  Future<void> _confirmAndStartMerge() async {
    if (_selectedFiles.isEmpty) return;

    final savedName = pdfOutputName(
      sourcePath: _selectedFiles.first.file.path,
      suffix: 'merged_',
    );
    final confirmed = await showPdfConfirmation(
      context: context,
      title: _selectedFiles.length == 1
          ? 'Merge this file?'
          : 'Merge ${_selectedFiles.length} files?',
      rows: [
        PdfConfirmationRow(
          label: 'Input',
          value:
              '${_selectedFiles.length} ${_selectedFiles.length == 1 ? 'file' : 'files'} • ${formatBytes(_estimatedSize, 2)}',
        ),
        PdfConfirmationRow(label: 'Output', value: savedName),
        PdfConfirmationRow(
          label: 'Save to',
          value: _savePath.isEmpty ? 'Configured save folder' : _savePath,
        ),
      ],
      message: 'Original files will remain unchanged.',
      actionIcon: Icons.merge,
      actionLabel: 'Merge',
    );

    if (!confirmed || !mounted) return;
    _startMerge();
  }

  void _startMerge() {
    final pdf = Pdf();
    PdfTask<void>? mergeTask;

    final mergeFuture = MergeOperations.performMerge(
      context: context,
      selectedFiles: _selectedFiles,
      pdf: pdf,
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
          onPressed: _confirmAndStartMerge,
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
            SliverFillRemaining(
              child: MergeEmptyState(onPickFiles: _pickFiles),
            ),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }
}
