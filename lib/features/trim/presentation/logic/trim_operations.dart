import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/features/compression/data/models/task_messages.dart';
import 'package:pdf_tools/core/utils/pdf_output.dart';
import 'package:pdf_tools/features/result/presentation/screens/result_screen.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';
import 'package:pdf_tools/core/utils/snackbar_utils.dart';

class TrimOperations {
  TrimOperations._();

  static Future<void> performTrim({
    required BuildContext context,
    required File? filePicked,
    required List<int> selectedPages,
  }) async {
    if (filePicked == null || selectedPages.isEmpty) return;

    final settingsService = SettingsProvider.of(context).settingsService;
    final pdf = Pdf();

    final savedName = pdfOutputName(
      sourcePath: filePicked.path,
      suffix: 'trim_',
    );
    final pdfOutput = await createPdfOutput(
      settingsService: settingsService,
      fileName: savedName,
    );
    final saveFile = pdfOutput.file;
    final output = pdfOutput.sink;
    final source = FileSource(filePicked);

    PdfTask<void>? trimTask;
    try {
      final mergeFuture = () async {
        try {
          trimTask = pdf.deletePages(
            source,
            output,
            pages: selectedPages.map((p) => p - 1).toList(),
          );
          await trimTask;
          await pdfOutput.commit();
          return saveFile.path;
        } catch (_) {
          await pdfOutput.discard();
          rethrow;
        } finally {
          await pdf.dispose();
        }
      }();

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            messages: TaskMessages.trim,
            fileCount: selectedPages.length,
            mergeFuture: mergeFuture,
            onCancel: () async {
              trimTask?.cancel();
              try {
                await mergeFuture;
              } catch (_) {}
            },
          ),
        ),
      );
    } catch (e) {
      await pdfOutput.discard();
      await pdf.dispose();
      if (context.mounted) {
        showErrorSnackBar(context, 'Trim failed: $e');
      }
    }
  }
}
