import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/util/pdf.dart';
import 'package:pdf_tools/util/string_util.dart';

import '../components/ItemCard.dart';

class MergeScreen extends StatefulWidget {
  const MergeScreen({super.key});
  @override
  State<MergeScreen> createState() => _MergeScreenState();
}

class _MergeScreenState extends State<MergeScreen> {
  final List<MapEntry<File, int>> _selectedFiles = [];

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
        setState(() => _selectedFiles.add(MapEntry(fileInst, pages)));
      }
    }
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
          SliverList.builder(
            itemCount: _selectedFiles.length,
            itemBuilder: (context, index) {
              if (_selectedFiles.isEmpty) {
                return Center(child: Text("No files selected"));
              }
              return ItemCard(
                title: p.basename(_selectedFiles[index].key.path),
                icon: const Icon(Icons.insert_drive_file),
                subtitle:
                    "${formatBytes(_selectedFiles[index].key.lengthSync(), 2)} • ${_selectedFiles[index].value.toString()} pages",
                onTap: () {},
              );
            },
          ),
        ],
      ),
    );
  }
}
