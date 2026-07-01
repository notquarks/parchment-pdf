import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdf_tools/util/string_util.dart';

import '../components/ItemCard.dart';

class SelectedFile {
  SelectedFile(this.file, this.pageCount);
  final File file;
  final int pageCount;
}

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<SelectedFile> _selectedFiles = [];

  Future<void> _pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null) {
      for (final file in result.files) {
        final fileInst = File(file.path!);
        final bytes = await fileInst.readAsBytes();
        final pages = await getPageCount(bytes);
        setState(() => _selectedFiles.add(SelectedFile(fileInst, pages)));
      }
    }
  }

  int get _estimatedSize {
    return _selectedFiles.fold<int>(0, (sum, f) => sum + f.file.lengthSync());
  }

  Future<void> _mergeFiles() async {
    final pdf = Pdf();
    final output = MemorySink();
    final data = _selectedFiles
        .map((element) => MemorySource(element.file.readAsBytesSync()))
        .toList();
    await pdf.merge(data, output);

    final mergedBytes = output.takeBytes();
    final savePath = await FilePicker.saveFile(
      fileName: 'merged.pdf',
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: mergedBytes,
    );

    if (!mounted) return;

    if (savePath != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PDF merged successfully!')));
    }
    setState(() => _selectedFiles.clear());
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(title: Text("Merge")),
          SliverToBoxAdapter(
            child: ListTile(
              title: Text("${_selectedFiles.length} files selected"),
              trailing: TextButton(
                onPressed: _pickFiles,
                child: Text('Add Documents'),
              ),
            ),
          ),
          SliverReorderableList(
            itemCount: _selectedFiles.length,
            onReorderItem: ((oldIndex, newIndex) {
              setState(() {
                final element = _selectedFiles.removeAt(oldIndex);
                _selectedFiles.insert(newIndex, element);
              });
            }),
            itemBuilder: (context, index) {
              if (_selectedFiles.isEmpty) {
                return Center(child: Text("No files selected"));
              }
              return Card(
                key: ValueKey(_selectedFiles[index]),
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
                        key: ValueKey(_selectedFiles[index]),
                        title: p.basename(_selectedFiles[index].file.path),
                        icon: const Icon(Icons.insert_drive_file),
                        subtitle:
                            "${formatBytes(_selectedFiles[index].file.lengthSync(), 2)} • ${_selectedFiles[index].pageCount.toString()} pages",
                        onTap: () {},
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _selectedFiles.removeAt(index);
                        });
                      },
                      icon: Icon(
                        Icons.close,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: _selectedFiles.isNotEmpty
          ? (BottomAppBar(
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
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _mergeFiles,
                    icon: Icon(Icons.merge),
                    label: Text("Merge Documents"),
                  ),
                ],
              ),
            ))
          : null,
    );
  }
}
