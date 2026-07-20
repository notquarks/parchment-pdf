import 'dart:io';

import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:pdf_manipulator/io.dart';
import 'package:pdf_tools/features/settings/data/services/settings_service.dart';

class PdfOutput {
  PdfOutput(this.file, this._temporaryFile, this.sink);

  final File file;
  final File _temporaryFile;
  final FileSink sink;
  bool _closed = false;
  bool _committed = false;

  Future<void> commit() async {
    if (_committed) return;

    await _close();
    await _replaceFile(_temporaryFile, file);
    _committed = true;
  }

  Future<void> discard() async {
    try {
      await _close();
    } finally {
      if (await _temporaryFile.exists()) {
        await _temporaryFile.delete();
      }
    }
  }

  Future<void> _close() async {
    if (_closed) return;
    try {
      await sink.close();
    } finally {
      _closed = true;
    }
  }
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
  final operationId = '${pid}_${DateTime.now().microsecondsSinceEpoch}';
  final temporaryFile = File('${file.path}.$operationId.tmp');
  final sink = await FileSink.create(temporaryFile);
  return PdfOutput(file, temporaryFile, sink);
}

Future<void> _replaceFile(File source, File destination) async {
  File? backupFile;
  final operationId = '${pid}_${DateTime.now().microsecondsSinceEpoch}';

  try {
    if (await destination.exists()) {
      backupFile = File('${destination.path}.$operationId.backup');
      await backupFile.delete();
      await destination.rename(backupFile.path);
    }

    await source.rename(destination.path);
    if (backupFile != null && await backupFile.exists()) {
      await backupFile.delete();
    }
  } catch (_) {
    if (backupFile != null && await backupFile.exists()) {
      if (await destination.exists()) {
        await destination.delete();
      }
      await backupFile.rename(destination.path);
    }
    rethrow;
  }
}
