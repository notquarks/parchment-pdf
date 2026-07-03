import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/screen/result_screen.dart';
import 'package:pdf_tools/services/settings_provider.dart';
import 'package:pdf_tools/util/pdf.dart';
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
  bool _loading = false;

  Future<void> _pickFiles() async {
    if (!mounted) return;

    try {
      final files = await pickPdfFiles(allowMultiple: true);
      if (!mounted) return;
      if (files.isEmpty) return;

      setState(() => _loading = true);

      final result = await processPdfFiles(files);
      if (!mounted) return;

      setState(() {
        _selectedFiles.addAll(result);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnackBar(context, 'Failed to load files: $e');
    }
  }

  int get _estimatedSize =>
      _selectedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);

  Future<String> _doMerge() async {
    final settingsService = SettingsProvider.of(context).settingsService;

    final pdf = Pdf();
    final output = MemorySink();
    final sources = await Future.wait(
      _selectedFiles.map((f) async => MemorySource(await f.file.readAsBytes())),
    );
    await pdf.merge(sources, output);

    final mergedBytes = output.takeBytes();

    final savedName =
        '${p.basenameWithoutExtension(_selectedFiles.first.file.path)}_merged_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    final downloadPath = await settingsService.getSavePath();

    final saveDir = Directory(downloadPath);
    if (!await saveDir.exists()) {
      await saveDir.create(recursive: true);
    }

    final saveFile = File('${saveDir.path}/$savedName');
    await saveFile.writeAsBytes(mergedBytes);
    return saveFile.path;
  }

  void _startMerge() {
    final mergeFuture = _doMerge();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          taskTitle: 'Merge',
          fileCount: _selectedFiles.length,
          mergeFuture: mergeFuture,
        ),
      ),
    );
  }

  Widget _buildFileItem(BuildContext context, int index) {
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
              subtitle:
                  "${formatBytes(file.sizeBytes, 2)} • ${file.pageCount} pages",
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
            child: _loading
                ? SizedBox(
                    width: shortest * 0.2,
                    height: shortest * 0.2,
                    child: LoadingIndicatorM3E(
                      variant: LoadingIndicatorM3EVariant.contained,
                    ),
                  )
                : InkWell(
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
              itemBuilder: _buildFileItem,
            ),
          ] else
            SliverFillRemaining(child: _noDocs(context)),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }
}
