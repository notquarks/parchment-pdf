import 'package:flutter/material.dart';
import 'package:m3e_core/m3e_core.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/core/utils/string_utils.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_controls.dart';
import 'package:pdf_tools/features/compression/data/models/compression_options.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_file_list.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_preview_card.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressWorkspace extends StatefulWidget {
  const CompressWorkspace({
    super.key,
    required this.documentRef,
    required this.files,
    required this.selectedIndex,
    required this.selectedPreset,
    required this.advancedQuality,
    required this.advancedDpiTarget,
    required this.advancedGrayscale,
    required this.advancedStripMetadata,
    required this.savePath,
    required this.totalInputSize,
    required this.estimate,
    required this.isEstimating,
    required this.onPresetChanged,
    required this.onAdvancedQualityChanged,
    required this.onAdvancedDpiTargetChanged,
    required this.onAdvancedGrayscaleChanged,
    required this.onAdvancedStripMetadataChanged,
    required this.onAddFiles,
    required this.onCompress,
    required this.onFileSelected,
    required this.onFileRemoved,
    required this.onClearFiles,
    required this.onChangeSaveLocation,
  });

  static const double _compactBreakpoint = 600;
  static const double _expandedBreakpoint = 960;
  static const double _maximumContentWidth = 1600;
  static const double _compactBottomInset = 32;
  static const double _pagePadding = 16;
  static const double _sectionSpacing = 16;
  static const double _mediumSettingsWidth = 360;
  static const double _expandedFilesWidth = 296;
  static const double _expandedSettingsWidth = 392;

  final PdfDocumentRef documentRef;
  final List<PickedPdfInfo> files;
  final int selectedIndex;
  final CompressionPreset selectedPreset;
  final int advancedQuality;
  final int advancedDpiTarget;
  final bool advancedGrayscale;
  final bool advancedStripMetadata;
  final String savePath;
  final int totalInputSize;
  final CompressionEstimate? estimate;
  final bool isEstimating;
  final ValueChanged<CompressionPreset> onPresetChanged;
  final ValueChanged<int> onAdvancedQualityChanged;
  final ValueChanged<int> onAdvancedDpiTargetChanged;
  final ValueChanged<bool> onAdvancedGrayscaleChanged;
  final ValueChanged<bool> onAdvancedStripMetadataChanged;
  final VoidCallback onAddFiles;
  final VoidCallback onCompress;
  final ValueChanged<int> onFileSelected;
  final ValueChanged<int> onFileRemoved;
  final VoidCallback onClearFiles;
  final VoidCallback onChangeSaveLocation;

  @override
  State<CompressWorkspace> createState() => _CompressWorkspaceState();
}

class _CompressWorkspaceState extends State<CompressWorkspace> {
  bool _filesExpanded = true;

  PickedPdfInfo get selectedFile => widget.files[widget.selectedIndex];

  void _handleFilesExpansionChanged(int index, bool expanded) {
    if (index == 0) {
      _filesExpanded = expanded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layout = width < CompressWorkspace._compactBreakpoint
            ? _WorkspaceLayout.compact
            : width < CompressWorkspace._expandedBreakpoint
            ? _WorkspaceLayout.medium
            : _WorkspaceLayout.expanded;

        return Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: CompressWorkspace._maximumContentWidth,
            ),
            child: switch (layout) {
              _WorkspaceLayout.compact => _buildCompact(context),
              _WorkspaceLayout.medium => _buildMedium(context),
              _WorkspaceLayout.expanded => _buildExpanded(context),
            },
          ),
        );
      },
    );
  }

  Widget _buildCompact(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        CompressWorkspace._pagePadding,
        CompressWorkspace._pagePadding,
        CompressWorkspace._pagePadding,
        CompressWorkspace._compactBottomInset,
      ),
      children: [
        _BatchSummary(
          files: widget.files,
          selectedIndex: widget.selectedIndex,
          totalInputSize: widget.totalInputSize,
          estimate: widget.estimate,
          isEstimating: widget.isEstimating,
          fileListAxis: Axis.horizontal,
          initiallyExpanded: _filesExpanded,
          onExpansionChanged: _handleFilesExpansionChanged,
          onAddFiles: widget.onAddFiles,
          onClearFiles: widget.onClearFiles,
          onFileSelected: widget.onFileSelected,
          onFileRemoved: widget.onFileRemoved,
        ),
        const SizedBox(height: CompressWorkspace._sectionSpacing),
        CompressPreviewCard(
          key: ValueKey(selectedFile.file.path),
          documentRef: widget.documentRef,
          file: selectedFile,
          estimate: widget.estimate,
          isEstimating: widget.isEstimating,
          layout: CompressPreviewLayout.compact,
        ),
        const SizedBox(height: CompressWorkspace._sectionSpacing),
        CompressControls(
          selectedPreset: widget.selectedPreset,
          onPresetChanged: widget.onPresetChanged,
          advancedQuality: widget.advancedQuality,
          onAdvancedQualityChanged: widget.onAdvancedQualityChanged,
          advancedDpiTarget: widget.advancedDpiTarget,
          onAdvancedDpiTargetChanged: widget.onAdvancedDpiTargetChanged,
          advancedGrayscale: widget.advancedGrayscale,
          onAdvancedGrayscaleChanged: widget.onAdvancedGrayscaleChanged,
          advancedStripMetadata: widget.advancedStripMetadata,
          onAdvancedStripMetadataChanged: widget.onAdvancedStripMetadataChanged,
        ),
      ],
    );
  }

  Widget _buildMedium(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CompressWorkspace._pagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                _BatchSummary(
                  files: widget.files,
                  selectedIndex: widget.selectedIndex,
                  totalInputSize: widget.totalInputSize,
                  estimate: widget.estimate,
                  isEstimating: widget.isEstimating,
                  fileListAxis: Axis.horizontal,
                  initiallyExpanded: _filesExpanded,
                  onExpansionChanged: _handleFilesExpansionChanged,
                  onAddFiles: widget.onAddFiles,
                  onClearFiles: widget.onClearFiles,
                  onFileSelected: widget.onFileSelected,
                  onFileRemoved: widget.onFileRemoved,
                ),
                const SizedBox(height: CompressWorkspace._sectionSpacing),
                CompressPreviewCard(
                  key: ValueKey(selectedFile.file.path),
                  documentRef: widget.documentRef,
                  file: selectedFile,
                  estimate: widget.estimate,
                  isEstimating: widget.isEstimating,
                  layout: CompressPreviewLayout.medium,
                ),
              ],
            ),
          ),
          const SizedBox(width: CompressWorkspace._sectionSpacing),
          SizedBox(
            width: CompressWorkspace._mediumSettingsWidth,
            child: ListView(
              children: [
                CompressControls(
                  selectedPreset: widget.selectedPreset,
                  onPresetChanged: widget.onPresetChanged,
                  advancedQuality: widget.advancedQuality,
                  onAdvancedQualityChanged: widget.onAdvancedQualityChanged,
                  advancedDpiTarget: widget.advancedDpiTarget,
                  onAdvancedDpiTargetChanged: widget.onAdvancedDpiTargetChanged,
                  advancedGrayscale: widget.advancedGrayscale,
                  onAdvancedGrayscaleChanged: widget.onAdvancedGrayscaleChanged,
                  advancedStripMetadata: widget.advancedStripMetadata,
                  onAdvancedStripMetadataChanged:
                      widget.onAdvancedStripMetadataChanged,
                ),
                const SizedBox(height: CompressWorkspace._sectionSpacing),
                _CompressActionCard(
                  fileCount: widget.files.length,
                  totalInputSize: widget.totalInputSize,
                  onCompress: widget.onCompress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpanded(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(CompressWorkspace._pagePadding),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: CompressWorkspace._expandedFilesWidth,
            child: _BatchSummary(
              files: widget.files,
              selectedIndex: widget.selectedIndex,
              totalInputSize: widget.totalInputSize,
              estimate: widget.estimate,
              isEstimating: widget.isEstimating,
              fileListAxis: Axis.vertical,
              fillsAvailableHeight: true,
              initiallyExpanded: _filesExpanded,
              onExpansionChanged: _handleFilesExpansionChanged,
              onAddFiles: widget.onAddFiles,
              onClearFiles: widget.onClearFiles,
              onFileSelected: widget.onFileSelected,
              onFileRemoved: widget.onFileRemoved,
            ),
          ),
          const SizedBox(width: CompressWorkspace._sectionSpacing),
          Expanded(
            child: CompressPreviewCard(
              key: ValueKey(selectedFile.file.path),
              documentRef: widget.documentRef,
              file: selectedFile,
              estimate: widget.estimate,
              isEstimating: widget.isEstimating,
              layout: CompressPreviewLayout.expanded,
            ),
          ),
          const SizedBox(width: CompressWorkspace._sectionSpacing),
          SizedBox(
            width: CompressWorkspace._expandedSettingsWidth,
            child: ListView(
              children: [
                CompressControls(
                  selectedPreset: widget.selectedPreset,
                  onPresetChanged: widget.onPresetChanged,
                  advancedQuality: widget.advancedQuality,
                  onAdvancedQualityChanged: widget.onAdvancedQualityChanged,
                  advancedDpiTarget: widget.advancedDpiTarget,
                  onAdvancedDpiTargetChanged: widget.onAdvancedDpiTargetChanged,
                  advancedGrayscale: widget.advancedGrayscale,
                  onAdvancedGrayscaleChanged: widget.onAdvancedGrayscaleChanged,
                  advancedStripMetadata: widget.advancedStripMetadata,
                  onAdvancedStripMetadataChanged:
                      widget.onAdvancedStripMetadataChanged,
                ),
                const SizedBox(height: CompressWorkspace._sectionSpacing),
                _CompressActionCard(
                  fileCount: widget.files.length,
                  totalInputSize: widget.totalInputSize,
                  onCompress: widget.onCompress,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _WorkspaceLayout { compact, medium, expanded }

class _BatchSummary extends StatelessWidget {
  const _BatchSummary({
    required this.files,
    required this.selectedIndex,
    required this.totalInputSize,
    required this.estimate,
    required this.isEstimating,
    required this.fileListAxis,
    required this.initiallyExpanded,
    required this.onExpansionChanged,
    required this.onAddFiles,
    required this.onClearFiles,
    required this.onFileSelected,
    required this.onFileRemoved,
    this.fillsAvailableHeight = false,
  });

  static const double _actionSpacing = 4;

  final List<PickedPdfInfo> files;
  final int selectedIndex;
  final int totalInputSize;
  final CompressionEstimate? estimate;
  final bool isEstimating;
  final Axis fileListAxis;
  final bool initiallyExpanded;
  final void Function(int index, bool expanded) onExpansionChanged;
  final VoidCallback onAddFiles;
  final VoidCallback onClearFiles;
  final ValueChanged<int> onFileSelected;
  final ValueChanged<int> onFileRemoved;
  final bool fillsAvailableHeight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fileCount = files.length;

    return M3EExpandableCardList(
      shrinkWrap: !fillsAvailableHeight,
      physics: fillsAvailableHeight
          ? null
          : const NeverScrollableScrollPhysics(),
      initiallyExpanded: initiallyExpanded ? const {0} : const {},
      onExpansionChanged: onExpansionChanged,
      style: M3EExpandableStyle(
        titleSubtitleGap: 18,
        headerAlignment: .center,
        margin: EdgeInsets.zero,
        color: colorScheme.surfaceContainerLow,
        tapBodyToExpand: false,
        tapBodyToCollapse: false,
        expandTooltip: 'Show selected PDF files',
        collapseTooltip: 'Hide selected PDF files',
      ),
      data: [
        M3EExpandableData(
          leading: Icon(
            Icons.picture_as_pdf_outlined,
            color: colorScheme.primary,
          ),
          title:
              '$fileCount ${fileCount == 1 ? 'PDF selected' : 'PDFs selected'}',
          subtitle: '${formatBytes(totalInputSize, 2)} total',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Add PDF files',
                onPressed: onAddFiles,
                icon: const Icon(Icons.add),
              ),
              const SizedBox(width: _actionSpacing),
              IconButton(
                tooltip: 'Remove all files',
                onPressed: onClearFiles,
                icon: const Icon(Symbols.delete_sweep),
              ),
            ],
          ),
          bodyBuilder: (context) => CompressFileList(
            files: files,
            selectedIndex: selectedIndex,
            axis: fileListAxis,
            shrinkWrap: fileListAxis == Axis.vertical,
            physics: fileListAxis == Axis.vertical
                ? const NeverScrollableScrollPhysics()
                : null,
            selectedEstimate: estimate,
            isEstimatingSelected: isEstimating,
            onSelected: onFileSelected,
            onRemoved: onFileRemoved,
          ),
        ),
      ],
    );
  }
}

class _CompressActionCard extends StatelessWidget {
  const _CompressActionCard({
    required this.fileCount,
    required this.totalInputSize,
    required this.onCompress,
  });

  static const double _padding = 16;
  static const double _spacing = 12;

  final int fileCount;
  final int totalInputSize;
  final VoidCallback onCompress;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(_padding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Ready to compress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '$fileCount ${fileCount == 1 ? 'file' : 'files'} • ${formatBytes(totalInputSize, 2)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: _spacing),
            FilledButton.icon(
              onPressed: onCompress,
              icon: const Icon(Icons.compress),
              label: Text(
                fileCount == 1 ? 'Compress PDF' : 'Compress $fileCount PDFs',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
