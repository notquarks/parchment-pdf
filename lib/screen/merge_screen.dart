import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/screen/result_screen.dart';
import 'package:pdf_tools/services/settings_provider.dart';
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdf_tools/util/string_util.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

import '../components/item_card.dart';

class SelectedFile {
  SelectedFile(this.file, this.pageCount, this.sizeBytes);
  final File file;
  final int pageCount;
  final int sizeBytes;
}

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<SelectedFile> _selectedFiles = [];
  bool _loading = false;

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null) return;
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final picked = await Future.wait(
        result.files.map((f) async {
          final fileInst = File(f.path!);
          final bytes = await fileInst.readAsBytes();
          final pages = await compute(getPageCount, bytes);
          return SelectedFile(fileInst, pages, bytes.length);
        }),
      );
      if (!mounted) return;
      setState(() {
        _selectedFiles.addAll(picked);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load files: $e'),
          duration: const Duration(seconds: 4),
        ),
      );
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

  Widget? _floatingBtn() => _selectedFiles.isEmpty
      ? M3EButton.icon(
          onPressed: _pickFiles,
          icon: Icon(Icons.add),
          label: Text('Add Documents'),
        )
      : null;

  Widget? _bottomBar(BuildContext context) {
    if (_selectedFiles.isEmpty) return null;
    return BottomAppBar(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Estimated Size',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Text(
                '~ ${formatBytes(_estimatedSize, 2)}',
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
                onPressed: _pickFiles,
                child: Icon(Icons.add),
              ),
              M3EButton.icon(
                onPressed: _startMerge,
                icon: Icon(Icons.merge),
                label: Text("Merge Documents"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text("Merge"),
            bottom: _loading
                ? PreferredSize(
                    preferredSize: const Size.fromHeight(4),
                    child: const LinearProgressIndicatorM3E(
                      size: .s,
                      shape: .wavy,
                      inset: 2.0,
                    ),
                  )
                : null,
          ),
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
        ],
      ),
      floatingActionButton: _floatingBtn(),
      bottomNavigationBar: _bottomBar(context),
    );
  }
}
