import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_tools/core/widgets/loading_spinner.dart';
import 'package:pdf_tools/features/trim/presentation/logic/trim_operations.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:pdf_tools/core/widgets/page_small_preview.dart';

import 'package:pdf_tools/core/widgets/action_bottom_bar.dart';
import 'package:pdf_tools/core/utils/pdf_confirmation.dart';
import 'package:pdf_tools/core/utils/pdf_output.dart';
import 'package:pdf_tools/core/utils/pdf_pick_controller.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/core/utils/snackbar_utils.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';
import 'package:pdf_tools/features/trim/trim.dart';

class TrimPageScreen extends StatefulWidget {
  const TrimPageScreen({super.key});

  @override
  State<TrimPageScreen> createState() => _TrimPageScreenState();
}

class _TrimPageScreenState extends State<TrimPageScreen> {
  File? _filePicked;
  final List<int> _selectedPage = <int>[];
  int? _pageCount;
  String _savePath = '';
  bool _settingsLoaded = false;
  PdfDocumentRef? _documentRef;
  VoidCallback? _removeDocListener;
  late final _controller = PdfPickController(
    isMounted: () => mounted,
    onEvent: _applyEvent,
    onError: (msg) => showErrorSnackBar(context, msg),
  );

  void _applyEvent(PdfFileEvent event) {
    switch (event) {
      case PdfFileAdded(:final info):
        setState(() {
          _filePicked = info.file;
          _pageCount = null;
          _selectedPage.clear();
        });
        _preloadDocument(info.file.path);
      case PdfFileResolved(:final info):
        setState(() => _pageCount = info.pageCount);
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

  @override
  void dispose() {
    _removeDocListener?.call();
    super.dispose();
  }

  Future<void> _pickFile() => _controller.pickAndProcess(
    allowMultiple: false,
    failurePrefix: 'Failed to load file',
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    _loadSavePath();
  }

  Future<void> _loadSavePath() async {
    final settingsService = SettingsProvider.of(context).settingsService;
    final path = await settingsService.getSavePath();
    if (!mounted) return;
    setState(() => _savePath = path);
  }

  void _togglePage(int page) {
    setState(() {
      if (_selectedPage.contains(page)) {
        _selectedPage.remove(page);
      } else {
        _selectedPage.add(page);
      }
      _selectedPage.sort();
    });
  }

  bool get _allSelected =>
      _pageCount != null &&
      _selectedPage.length == _pageCount &&
      _pageCount! > 0;

  void _toggleSelectAll() {
    if (_pageCount == null) return;
    setState(() {
      if (_allSelected) {
        _selectedPage.clear();
      } else {
        _selectedPage
          ..clear()
          ..addAll(List.generate(_pageCount!, (i) => i + 1));
      }
    });
  }

  void _invertSelection() {
    if (_pageCount == null) return;
    setState(() {
      final inverted = List.generate(
        _pageCount!,
        (i) => i + 1,
      ).where((p) => !_selectedPage.contains(p)).toList();
      _selectedPage
        ..clear()
        ..addAll(inverted);
    });
  }

  Future<void> _inputPageRange() async {
    if (_pageCount == null) return;
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
              final pages = _parsePageRange(controller.text, _pageCount!);
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
    final result = <int>{};
    for (final part in input.split(',')) {
      result.addAll(_parsePageRangePart(part.trim(), max));
    }
    return result.toList()..sort();
  }

  List<int> _parsePageRangePart(String part, int max) {
    if (part.isEmpty) return [];

    if (part.contains('-')) {
      final bounds = part.split('-');
      if (bounds.length != 2) return [];
      final start = int.tryParse(bounds[0].trim());
      final end = int.tryParse(bounds[1].trim());
      if (start == null || end == null) return [];

      final result = <int>[];
      for (var i = start.clamp(1, max); i <= end.clamp(1, max); i++) {
        result.add(i);
      }
      return result;
    }

    final n = int.tryParse(part);
    if (n != null && n >= 1 && n <= max) return [n];
    return [];
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
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Center(
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
              ),
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

  Future<void> _confirmAndStartDeletingPage() async {
    if (_filePicked == null || _selectedPage.isEmpty) return;

    final savedName = pdfOutputName(
      sourcePath: _filePicked!.path,
      suffix: 'trim_',
    );
    final confirmed = await showPdfConfirmation(
      context: context,
      title: 'Trim this PDF?',
      rows: [
        PdfConfirmationRow(label: 'File', value: p.basename(_filePicked!.path)),
        PdfConfirmationRow(
          label: 'Pages',
          value:
              '${_selectedPage.length} of $_pageCount selected to be deleted',
        ),
        PdfConfirmationRow(label: 'Output', value: savedName),
        PdfConfirmationRow(
          label: 'Save to',
          value: _savePath.isEmpty ? 'Configured save folder' : _savePath,
        ),
      ],
      message: 'Original file will remain unchanged.',
      actionIcon: Symbols.scan_delete,
      actionLabel: 'Trim',
    );

    if (!confirmed || !mounted) return;
    _doTrim();
  }

  Future<void> _doTrim() async {
    await TrimOperations.performTrim(
      context: context,
      filePicked: _filePicked,
      selectedPages: _selectedPage,
    );
  }

  Widget? _bottomBar(BuildContext context) {
    if (_filePicked == null) return null;
    return ActionBottomBar(
      label: 'Selected Pages',
      value: _pageCount != null
          ? '${_selectedPage.length} of $_pageCount'
          : 'Loading…',
      actions: [
        M3EFilledButton.tonal(
          shape: M3EButtonShape.square,
          onPressed: _pageCount != null ? _showShortcut : null,
          child: const Icon(Icons.handyman),
        ),
        M3EButton.icon(
          onPressed: _selectedPage.isNotEmpty
              ? _confirmAndStartDeletingPage
              : null,
          icon: const Icon(Symbols.scan_delete),
          label: const Text('Trim'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        scrollCacheExtent: ScrollCacheExtent.pixels(600),
        slivers: [
          SliverAppBar(
            floating: true,
            title: const Text("Trim"),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          if (_filePicked != null && _pageCount != null)
            SliverPadding(
              padding: const EdgeInsets.all(8),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 160,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _pageCount,
                itemBuilder: (context, index) {
                  final pageNumber = index + 1;
                  final isSelected = _selectedPage.contains(pageNumber);
                  return InkWell(
                    onTap: () => _togglePage(pageNumber),
                    borderRadius: BorderRadius.circular(8),
                    child: Column(
                      spacing: 4,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: PageSmallPreview(
                            documentRef: _documentRef!,
                            pageNumber: pageNumber,
                            isSelected: isSelected,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2.0),
                          child: Text(
                            'Page $pageNumber',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isSelected
                                      ? Theme.of(context).colorScheme.primary
                                      : null,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : null,
                                ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else if (_filePicked != null)
            SliverFillRemaining(child: Center(child: LoadingSpinner(size: 0.4)))
          else
            SliverFillRemaining(child: TrimEmptyState(onPickFile: _pickFile)),
        ],
      ),
      bottomNavigationBar: _bottomBar(context),
    );
  }
}
