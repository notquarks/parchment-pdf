import 'package:flutter/material.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/features/compression/data/models/compression_options.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_controls.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_file_info.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/compress_preview_card.dart';
import 'package:pdf_tools/features/compression/presentation/widgets/file_preview_navigator.dart';
import 'package:pdfrx/pdfrx.dart';

class CompressNarrowLayout extends StatelessWidget {
  const CompressNarrowLayout({
    super.key,
    required this.documentRef,
    required this.files,
    required this.selectedIndex,
    required this.selectedPreset,
    required this.advancedQuality,
    required this.advancedDpiTarget,
    required this.advancedGrayscale,
    required this.advancedStripMetadata,
    required this.onPresetChanged,
    required this.onAdvancedQualityChanged,
    required this.onAdvancedDpiTargetChanged,
    required this.onAdvancedGrayscaleChanged,
    required this.onAdvancedStripMetadataChanged,
    required this.onFileSelected,
  });

  final PdfDocumentRef documentRef;
  final List<PickedPdfInfo> files;
  final int selectedIndex;
  final CompressionPreset selectedPreset;
  final int advancedQuality;
  final int advancedDpiTarget;
  final bool advancedGrayscale;
  final bool advancedStripMetadata;
  final ValueChanged<CompressionPreset> onPresetChanged;
  final ValueChanged<int> onAdvancedQualityChanged;
  final ValueChanged<int> onAdvancedDpiTargetChanged;
  final ValueChanged<bool> onAdvancedGrayscaleChanged;
  final ValueChanged<bool> onAdvancedStripMetadataChanged;
  final ValueChanged<int> onFileSelected;

  @override
  Widget build(BuildContext context) {
    if (files.isEmpty || selectedIndex < 0 || selectedIndex >= files.length) {
      return const SizedBox.shrink();
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 24,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: FilePreviewNavigator(
              documentRef: documentRef,
              file: files[selectedIndex],
              selectedIndex: selectedIndex,
              totalFiles: files.length,
              onPrevious: () => onFileSelected(selectedIndex - 1),
              onNext: () => onFileSelected(selectedIndex + 1),
              layout: CompressPreviewLayout.compact,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: CompressFileInfo(
              documentRef: documentRef,
              files: files,
              isWide: false,
            ),
          ),
          CompressControls(
            selectedPreset: selectedPreset,
            onPresetChanged: onPresetChanged,
            advancedQuality: advancedQuality,
            onAdvancedQualityChanged: onAdvancedQualityChanged,
            advancedDpiTarget: advancedDpiTarget,
            onAdvancedDpiTargetChanged: onAdvancedDpiTargetChanged,
            advancedGrayscale: advancedGrayscale,
            onAdvancedGrayscaleChanged: onAdvancedGrayscaleChanged,
            advancedStripMetadata: advancedStripMetadata,
            onAdvancedStripMetadataChanged: onAdvancedStripMetadataChanged,
          ),
        ],
      ),
    );
  }
}
