import 'dart:io';

import 'package:flutter/material.dart';
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import 'package:m3e_core/m3e_core.dart';

import '../components/action_bottom_bar.dart';
import '../util/pdf.dart';
import '../util/snackbar.dart';

class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

class _SplitScreenState extends State<SplitScreen> {
  File? _filePicked;
  final List<int> _selectedPage = <int>[];
  int _pageCount = 0;
  bool _loading = false;

  Future<void> _pickFile() async {
    if (!mounted) return;

    try {
      final files = await pickPdfFiles();
      if (!mounted) return;
      if (files.isEmpty) return;

      setState(() => _loading = true);

      final result = await processPdfFiles(files);
      if (!mounted) return;

      setState(() {
        _filePicked = result.first.file;
        _pageCount = result.first.pageCount;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showErrorSnackBar(context, 'Failed to load file: $e');
    }
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
                    onTap: _pickFile,
                    borderRadius: BorderRadius.circular(16),
                    child: Column(
                      mainAxisAlignment: .center,
                      mainAxisSize: .max,
                      spacing: 12,
                      children: [
                        Text(
                          'Select a Document',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        M3EContainer.pill(
                          width: shortest * 0.4,
                          height: shortest * 0.4,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          child: Icon(
                            Icons.insert_drive_file,
                            size: shortest * 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  bool get _allSelected => _selectedPage.length == _pageCount && _pageCount > 0;

  void _toggleSelectAll() {
    setState(() {
      if (_allSelected) {
        _selectedPage.clear();
      } else {
        _selectedPage
          ..clear()
          ..addAll(List.generate(_pageCount, (i) => i + 1));
      }
    });
  }

  void _invertSelection() {
    setState(() {
      final inverted = List.generate(
        _pageCount,
        (i) => i + 1,
      ).where((p) => !_selectedPage.contains(p)).toList();
      _selectedPage
        ..clear()
        ..addAll(inverted);
    });
  }

  Future<void> _inputPageRange() async {
    final controller = TextEditingController();
    final result = await showDialog<List<int>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter page range'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.text,
          decoration: const InputDecoration(hintText: 'e.g. 1-3, 5, 7-9'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final pages = _parsePageRange(controller.text, _pageCount);
              Navigator.pop(context, pages);
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedPage
          ..clear()
          ..addAll(result);
      });
    }
  }

  List<int> _parsePageRange(String input, int max) {
    return input
        .split(',')
        .expand((part) => _parsePageRangePart(part.trim(), max))
        .toSet()
        .toList()
      ..sort();
  }

  Iterable<int> _parsePageRangePart(String part, int max) sync* {
    if (part.isEmpty) return;
    if (part.contains('-')) {
      final bounds = part.split('-');
      if (bounds.length != 2) return;
      final start = int.tryParse(bounds[0].trim());
      final end = int.tryParse(bounds[1].trim());
      if (start == null || end == null) return;
      for (var i = start.clamp(1, max); i <= end.clamp(1, max); i++) {
        yield i;
      }
    } else {
      final n = int.tryParse(part);
      if (n != null && n >= 1 && n <= max) yield n;
    }
  }

  void _showShortcut() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(_allSelected ? Icons.deselect : Icons.select_all),
                title: Text(_allSelected ? 'Deselect All' : 'Select All'),
                onTap: () {
                  _toggleSelectAll();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.flip),
                title: const Text('Invert Selection'),
                onTap: () {
                  _invertSelection();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_note),
                title: const Text('Page Range'),
                onTap: () {
                  Navigator.pop(context);
                  _inputPageRange();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _bottomBar(BuildContext context) {
    if (_filePicked == null) return null;
    return ActionBottomBar(
      label: 'Selected Pages',
      value: '${_selectedPage.length} of $_pageCount',
      actions: [
        M3EFilledButton.tonal(
          shape: .square,
          onPressed: _showShortcut,
          child: const Icon(Icons.handyman),
        ),
        M3EButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.call_split),
          label: const Text('Split'),
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
            title: Text("Split"),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          if (_filePicked != null)
            SliverToBoxAdapter(
              child: ListTile(
                title: Column(children: [Text("Split Documents")]),
              ),
            )
          else
            SliverFillRemaining(child: _noDocs(context)),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }
}
