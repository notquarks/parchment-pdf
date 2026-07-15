import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_tools/features/compression/data/models/task_messages.dart';
import 'package:pdf_tools/core/utils/pdf_output.dart';
import 'package:pdf_tools/features/result/presentation/screens/result_screen.dart';
import 'package:pdf_tools/features/settings/presentation/widgets/settings_provider.dart';
import 'package:pdf_tools/core/utils/snackbar_utils.dart';

class SplitOperations {
  SplitOperations._();

  static Future<void> performSplit({
    required BuildContext context,
    required File? filePicked,
    required List<int> selectedPages,
  }) async {
    if (filePicked == null || selectedPages.isEmpty) return;

    final settingsService = SettingsProvider.of(context).settingsService;
    final pdf = Pdf();

    final savedName = pdfOutputName(
      sourcePath: filePicked.path,
      suffix: 'split_',
    );
    final pdfOutput = await createPdfOutput(
      settingsService: settingsService,
      fileName: savedName,
    );
    final saveFile = pdfOutput.file;
    final output = pdfOutput.sink;
    final source = FileSource(filePicked);

    try {
      final mergeFuture = pdf
          .extractPages(
            source,
            output,
            pages: selectedPages.map((p) => p - 1).toList(),
          )
          .then((_) => saveFile.path)
          .whenComplete(() async {
            await output.close();
            await pdf.dispose();
          });

      if (!context.mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(
            messages: TaskMessages.split,
            fileCount: selectedPages.length,
            mergeFuture: mergeFuture,
          ),
        ),
      );
    } catch (e) {
      await output.close();
      await pdf.dispose();
      if (context.mounted) {
        showErrorSnackBar(context, 'Split failed: $e');
      }
    }
  }
}
