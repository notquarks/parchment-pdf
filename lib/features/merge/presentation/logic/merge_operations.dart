import 'package:flutter/material.dart';
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/core/utils/pdf_output.dart';
import 'package:pdf_tools/core/utils/pdf_utils.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';

class MergeOperations {
  MergeOperations._();

  static Future<String> performMerge({
    required BuildContext context,
    required List<PickedPdfInfo> selectedFiles,
    required Pdf pdf,
    void Function(PdfTask<void>)? onTaskCreated,
  }) async {
    final settingsService = SettingsProvider.of(context).settingsService;

    final sources = selectedFiles.map((f) => FileSource(f.file)).toList();

    final savedName = pdfOutputName(
      sourcePath: selectedFiles.first.file.path,
      suffix: 'merged_',
    );
    final pdfOutput = await createPdfOutput(
      settingsService: settingsService,
      fileName: savedName,
    );
    final saveFile = pdfOutput.file;
    final output = pdfOutput.sink;
    final totalSize = selectedFiles.fold<int>(0, (sum, f) => sum + f.sizeBytes);
    final sw = Stopwatch()..start();
    final task = pdf.merge(sources, output);
    onTaskCreated?.call(task);
    try {
      await task;
      await pdfOutput.commit();
      sw.stop();
      debugPrint(
        'PDF merge: ${sw.elapsedMilliseconds}ms | ${selectedFiles.length} files, ${(totalSize / 1024 / 1024).toStringAsFixed(1)}MB total',
      );
    } catch (_) {
      await pdfOutput.discard();
      rethrow;
    }
    return saveFile.path;
  }
}
