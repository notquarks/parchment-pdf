import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';

class PdfOutput {
  PdfOutput(this.file, this.sink);

  final File file;
  final FileSink sink;
}

String pdfOutputName({
  required String sourcePath,
  required String suffix,
  String ending = '',
}) {
  final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
  return '${p.basenameWithoutExtension(sourcePath)}_$suffix$timestamp$ending.pdf';
}

Future<File> createPdfFile({
  required SettingsService settingsService,
  required String fileName,
}) async {
  final savePath = await settingsService.getSavePath();
  final saveDirectory = Directory(savePath);
  if (!await saveDirectory.exists()) {
    await saveDirectory.create(recursive: true);
  }

  final file = File(p.join(saveDirectory.path, fileName));
  return file;
}

Future<PdfOutput> createPdfOutput({
  required SettingsService settingsService,
  required String fileName,
}) async {
  final file = await createPdfFile(
    settingsService: settingsService,
    fileName: fileName,
  );
  final sink = await FileSink.create(file);
  return PdfOutput(file, sink);
}
