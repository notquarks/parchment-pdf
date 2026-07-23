import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pdf_tools/core/utils/pdf_confirmation.dart';
import 'package:pdf_tools/core/utils/string_utils.dart';
import 'package:pdf_tools/core/widgets/action_bottom_bar.dart';
import 'package:pdf_tools/features/compression/application/compression_controller.dart';
import 'package:pdf_tools/features/compression/data/models/task_messages.dart';
import 'package:pdf_tools/features/compression/data/services/compression_worker.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_empty_state.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_workspace.dart';
import 'package:pdf_tools/features/result/presentation/screens/result_screen.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';

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

  CompressionController? _ctrl;
  bool _initialized = false;

  CompressionController get _c => _ctrl!;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _ctrl = CompressionController(
      settingsService: SettingsProvider.of(context).settingsService,
      onError: (message) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      },
      isMounted: () => mounted,
    );
    _ctrl!.init();
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  Future<void> _openSaveSettings() async {
    await Navigator.pushNamed(context, '/settings');
    if (!mounted) return;
    await _c.refreshSavePath();
  }

  Future<void> _confirmAndStartCompression() async {
    if (_c.pickedFiles.isEmpty) return;

    final confirmed = await showPdfConfirmation(
      context: context,
      title: _c.pickedFiles.length == 1
          ? 'Compress this PDF?'
          : 'Compress ${_c.pickedFiles.length} PDFs?',
      rows: [
        PdfConfirmationRow(
          label: 'Input',
          value:
              '${_c.pickedFiles.length} ${_c.pickedFiles.length == 1 ? 'file' : 'files'} • ${formatBytes(_c.totalInputSize, 2)}',
        ),
        PdfConfirmationRow(
          label: 'Compression',
          value: '${_c.compressionLabel} • ${_c.quality}% quality',
        ),
        PdfConfirmationRow(
          label: 'Save to',
          value: _c.savePath.isEmpty ? 'Configured save folder' : _c.savePath,
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
    final cancelToken = CancellationToken();
    final compressFuture = _c.compressFiles(cancelToken: cancelToken);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          messages: TaskMessages.compress,
          fileCount: _c.pickedFiles.length,
          mergeMultiFuture: compressFuture,
          onCancel: () async => cancelToken.cancel(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final isCompact = MediaQuery.sizeOf(context).width < _compactBreakpoint;
        final hasFiles = _c.hasFiles;

        return CallbackShortcuts(
          bindings: {
            const SingleActivator(LogicalKeyboardKey.keyO, control: true):
                _c.pickFiles,
            const SingleActivator(LogicalKeyboardKey.enter, control: true):
                _confirmAndStartCompression,
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              appBar: AppBar(
                title: const Text('Compress PDFs'),
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHigh,
              ),
              body: hasFiles
                  ? CompressWorkspace(
                      documentRef: _c.documentRef!,
                      files: _c.pickedFiles,
                      selectedIndex: _c.selectedIndex,
                      selectedPreset: _c.selectedPreset,
                      advancedQuality: _c.advancedQuality,
                      advancedDpiTarget: _c.advancedDpiTarget,
                      advancedGrayscale: _c.advancedGrayscale,
                      advancedStripMetadata: _c.advancedStripMetadata,
                      savePath: _c.savePath,
                      totalInputSize: _c.totalInputSize,
                      estimate: _c.selectedEstimate,
                      isEstimating: _c.isEstimatingSelected,
                      onPresetChanged: _c.setPreset,
                      onAdvancedQualityChanged: _c.setAdvancedQuality,
                      onAdvancedDpiTargetChanged: _c.setAdvancedDpiTarget,
                      onAdvancedGrayscaleChanged: _c.setAdvancedGrayscale,
                      onAdvancedStripMetadataChanged:
                          _c.setAdvancedStripMetadata,
                      onAddFiles: _c.pickFiles,
                      onCompress: _confirmAndStartCompression,
                      onFileSelected: _c.selectFile,
                      onFileRemoved: _c.removeFile,
                      onClearFiles: () async {
                        if (_c.pickedFiles.length == 1) {
                          await _c.clearFiles();
                          return;
                        }
                        final shouldClear =
                            await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Remove all files?'),
                                content: Text(
                                  '${_c.pickedFiles.length} selected PDFs will be removed from this compression task.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Remove all'),
                                  ),
                                ],
                              ),
                            ) ??
                            false;
                        if (shouldClear && mounted) {
                          await _c.clearFiles();
                        }
                      },
                      onChangeSaveLocation: _openSaveSettings,
                    )
                  : CompressEmptyState(onPick: _c.pickFiles),
              bottomNavigationBar: hasFiles && isCompact
                  ? ActionBottomBar(
                      label:
                          '${_c.pickedFiles.length} ${_c.pickedFiles.length == 1 ? 'file' : 'files'}',
                      value: formatBytes(_c.totalInputSize, 2),
                      actions: [
                        FilledButton.icon(
                          onPressed: _confirmAndStartCompression,
                          icon: const Icon(Icons.compress),
                          label: Text(
                            _c.pickedFiles.length == 1
                                ? 'Compress'
                                : 'Compress ${_c.pickedFiles.length}',
                          ),
                        ),
                      ],
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }
}
