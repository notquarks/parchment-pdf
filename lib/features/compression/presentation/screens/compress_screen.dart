import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_tools/core/utils/pdf_confirmation.dart';
import 'package:pdf_tools/core/utils/pdf_output.dart';
import 'package:pdf_tools/core/utils/pdf_pick_controller.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/core/utils/snackbar_utils.dart';
import 'package:pdf_tools/core/utils/string_utils.dart';
import 'package:pdf_tools/features/compression/data/models/compression_options.dart';
import 'package:pdf_tools/features/compression/data/models/task_messages.dart';
import 'package:pdf_tools/features/compression/data/services/compression_service.dart';
import 'package:pdf_tools/features/compression/data/services/compression_worker.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_empty_state.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_workspace.dart';
import 'package:pdf_tools/features/result/presentation/screens/result_screen.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressScreen extends StatefulWidget {
  const CompressScreen({super.key});

  @override
  State<CompressScreen> createState() => _CompressScreenState();
}

class _CompressScreenState extends State<CompressScreen> {
  static const double _compactBreakpoint = 600;
  static const double _bottomBarHorizontalPadding = 16;
  static const double _bottomBarVerticalPadding = 12;
  static const double _bottomBarSpacing = 12;
  static const int _defaultQuality = 75;

  final List<PickedPdfInfo> _pickedFiles = [];
  PdfDocumentRef? _documentRef;
  VoidCallback? _removeDocumentListener;
  int _quality = _defaultQuality;
  int _selectedIndex = 0;
  String _savePath = '';
  bool _settingsLoaded = false;

  late final PdfPickController _controller = PdfPickController(
    isMounted: () => mounted,
    onEvent: _handleEvent,
    onError: (message) => showErrorSnackBar(context, message),
  );

  int get _totalInputSize {
    return _pickedFiles.fold<int>(0, (total, file) => total + file.sizeBytes);
  }

  String get _compressionLabel {
    if (_quality >= 85) return 'Smaller loss';
    if (_quality >= 65) return 'Recommended';
    return 'Smallest size';
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_settingsLoaded) return;
    _settingsLoaded = true;
    _loadSavePath();
  }

  Future<void> _loadSavePath() async {
    final settingsService = SettingsProvider.of(context).settingsService;
    final savePath = await settingsService.getSavePath();
    if (!mounted) return;
    setState(() => _savePath = savePath);
  }

  void _handleEvent(PdfFileEvent event) {
    switch (event) {
      case PdfFileAdded(:final info):
        final existingIndex = _pickedFiles.indexWhere(
          (file) => file.file.absolute.path == info.file.absolute.path,
        );
        if (existingIndex >= 0) {
          _selectFile(existingIndex);
          return;
        }
        setState(() {
          _pickedFiles.add(info);
          _selectedIndex = _pickedFiles.length - 1;
        });
        _loadDocument(info.file.path);
      case PdfFileResolved(:final info):
        _updateFile(info);
      case PdfFileFailed(:final error):
        showErrorSnackBar(context, '${error.fileName}: ${error.error}');
    }
  }

  void _loadDocument(String path) {
    _removeDocumentListener?.call();
    final documentRef = PdfDocumentRefFile(path);
    final listenable = documentRef.resolveListenable();
    _removeDocumentListener = listenable.addListener(() {});
    setState(() => _documentRef = documentRef);
    listenable.load();
  }

  void _selectFile(int index) {
    if (index < 0 || index >= _pickedFiles.length) return;
    if (_selectedIndex != index) {
      setState(() => _selectedIndex = index);
    }
    _loadDocument(_pickedFiles[index].file.path);
  }

  void _updateFile(PickedPdfInfo info) {
    final index = _pickedFiles.indexWhere(
      (file) => file.file.absolute.path == info.file.absolute.path,
    );
    if (index < 0) return;
    setState(() => _pickedFiles[index] = info);
  }

  void _removeFile(int index) {
    if (index < 0 || index >= _pickedFiles.length) return;

    setState(() => _pickedFiles.removeAt(index));
    if (_pickedFiles.isEmpty) {
      _removeDocumentListener?.call();
      _removeDocumentListener = null;
      setState(() {
        _selectedIndex = 0;
        _documentRef = null;
      });
      return;
    }

    var nextIndex = _selectedIndex;
    if (index < nextIndex) {
      nextIndex--;
    } else if (nextIndex >= _pickedFiles.length) {
      nextIndex = _pickedFiles.length - 1;
    }

    setState(() => _selectedIndex = nextIndex);
    _loadDocument(_pickedFiles[nextIndex].file.path);
  }

  Future<void> _clearFiles() async {
    if (_pickedFiles.isEmpty) return;
    final shouldClear = _pickedFiles.length == 1
        ? true
        : await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Remove all files?'),
                  content: Text(
                    '${_pickedFiles.length} selected PDFs will be removed from this compression task.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Remove all'),
                    ),
                  ],
                ),
              ) ??
              false;
    if (!shouldClear || !mounted) return;

    _removeDocumentListener?.call();
    _removeDocumentListener = null;
    setState(() {
      _pickedFiles.clear();
      _selectedIndex = 0;
      _documentRef = null;
    });
  }

  Future<void> _pickFiles() {
    return _controller.pickAndProcess(
      allowMultiple: true,
      failurePrefix: 'Failed to load file',
    );
  }

  Future<void> _openSaveSettings() async {
    await Navigator.pushNamed(context, '/settings');
    if (!mounted) return;
    await _loadSavePath();
  }

  Future<List<String>> _compressFiles({
    required List<PickedPdfInfo> files,
    required int imageQuality,
    required CancellationToken cancelToken,
  }) async {
    final settingsService = SettingsProvider.of(context).settingsService;
    final options = CompressionOptions.withQuality(imageQuality);
    final savedPaths = <String>[];

    for (var index = 0; index < files.length; index++) {
      if (cancelToken.isCancelled) break;
      final picked = files[index];
      final savedName = pdfOutputName(
        sourcePath: picked.file.path,
        suffix: 'min_',
        ending: '_$index',
      );
      final saveFile = await createPdfFile(
        settingsService: settingsService,
        fileName: savedName,
      );
      final service = CompressionService();
      await service.initialize();
      try {
        final result = await service.compressPdf(
          filePath: picked.file.path,
          options: options,
          outputPath: saveFile.path,
          cancelToken: cancelToken,
        );
        if (result.wasCompressed) {
          savedPaths.add(result.outputPath!);
        }
      } finally {
        await service.dispose();
      }
    }

    return savedPaths;
  }

  Future<void> _confirmAndStartCompression() async {
    if (_pickedFiles.isEmpty) return;

    final confirmed = await showPdfConfirmation(
      context: context,
      title: _pickedFiles.length == 1
          ? 'Compress this PDF?'
          : 'Compress ${_pickedFiles.length} PDFs?',
      rows: [
        PdfConfirmationRow(
          label: 'Input',
          value:
              '${_pickedFiles.length} ${_pickedFiles.length == 1 ? 'file' : 'files'} • ${formatBytes(_totalInputSize, 2)}',
        ),
        PdfConfirmationRow(
          label: 'Compression',
          value: '$_compressionLabel • $_quality% quality',
        ),
        PdfConfirmationRow(
          label: 'Save to',
          value: _savePath.isEmpty ? 'Configured save folder' : _savePath,
        ),
      ],
      message: 'Original files will remain unchanged.',
      actionIcon: Icons.compress,
      actionLabel: 'Compress',
    );

    if (!confirmed || !mounted) return;
    _startCompression();
  }

  void _startCompression() {
    final files = List<PickedPdfInfo>.unmodifiable(_pickedFiles);
    final cancelToken = CancellationToken();
    final compressFuture = _compressFiles(
      files: files,
      imageQuality: _quality,
      cancelToken: cancelToken,
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          messages: TaskMessages.compress,
          fileCount: files.length,
          mergeMultiFuture: compressFuture,
          onCancel: () async => cancelToken.cancel(),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _removeDocumentListener?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < _compactBreakpoint;
    final hasFiles = _pickedFiles.isNotEmpty && _documentRef != null;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyO, control: true):
            _pickFiles,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            _confirmAndStartCompression,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Compress PDFs'),
            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
          ),
          body: hasFiles
              ? CompressWorkspace(
                  documentRef: _documentRef!,
                  files: _pickedFiles,
                  selectedIndex: _selectedIndex,
                  quality: _quality,
                  savePath: _savePath,
                  totalInputSize: _totalInputSize,
                  onQualityChanged: (value) => setState(() => _quality = value),
                  onAddFiles: _pickFiles,
                  onCompress: _confirmAndStartCompression,
                  onFileSelected: _selectFile,
                  onFileRemoved: _removeFile,
                  onClearFiles: _clearFiles,
                  onChangeSaveLocation: _openSaveSettings,
                )
              : CompressEmptyState(onPick: _pickFiles),
          bottomNavigationBar: hasFiles && isCompact
              ? SafeArea(
                  top: false,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        top: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: _bottomBarHorizontalPadding,
                        vertical: _bottomBarVerticalPadding,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_pickedFiles.length} ${_pickedFiles.length == 1 ? 'file' : 'files'}',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                                Text(
                                  formatBytes(_totalInputSize, 2),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: _bottomBarSpacing),
                          FilledButton.icon(
                            onPressed: _confirmAndStartCompression,
                            icon: const Icon(Icons.compress),
                            label: Text(
                              _pickedFiles.length == 1
                                  ? 'Compress'
                                  : 'Compress ${_pickedFiles.length}',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              : null,
        ),
      ),
    );
  }
}
