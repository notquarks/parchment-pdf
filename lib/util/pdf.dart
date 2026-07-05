import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';
import 'package:pdf_manipulator/io.dart';

class PdfService {
  PdfService._();
  static final PdfService instance = PdfService._();

  Pdf? _pdf;

  static Future<void> ensureInitialized() async {
    instance._pdf ??= Pdf();
  }

  Future<int> getPageCount(String filePath) async {
    final pdf = _pdf ?? Pdf();
    _pdf = pdf;
    final doc = await pdf.open(FileSource(File(filePath)));
    final count = doc.pageCount;
    await doc.dispose();
    return count;
  }

  Future<void> dispose() async {
    final p = _pdf;
    _pdf = null;
    await p?.dispose();
  }
}

class PickedPdfInfo {
  PickedPdfInfo(this.file, this.pageCount, this.sizeBytes);
  final File file;
  final int? pageCount;
  final int sizeBytes;
}

Future<List<PlatformFile>> pickPdfFiles({bool allowMultiple = false}) async {
  if (allowMultiple) {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return [];
    return result.files;
  } else {
    final result = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result == null) return [];
    return [result];
  }
}

class PdfFileError {
  PdfFileError({required this.fileName, required this.error});
  final String fileName;
  final String error;
}

sealed class PdfFileEvent {
  const PdfFileEvent();
}

class PdfFileAdded extends PdfFileEvent {
  const PdfFileAdded(this.info);
  final PickedPdfInfo info;
}

class PdfFileResolved extends PdfFileEvent {
  const PdfFileResolved(this.info);
  final PickedPdfInfo info;
}

class PdfFileFailed extends PdfFileEvent {
  const PdfFileFailed(this.error);
  final PdfFileError error;
}

String _getErrorMessage(Object e) {
  if (e is PdfCorrupted) return 'File is corrupted or not a valid PDF';
  if (e is PdfPasswordRequired) return 'File is password-protected';
  return e.toString();
}

Stream<PdfFileEvent> processPdfFilesStream(List<PlatformFile> files) async* {
  final added = <PickedPdfInfo>[];
  for (final f in files) {
    final file = File(f.path!);
    try {
      final sizeBytes = await file.length();
      final info = PickedPdfInfo(file, null, sizeBytes);
      added.add(info);
      yield PdfFileAdded(info);
    } catch (e) {
      yield PdfFileFailed(PdfFileError(
        fileName: file.path.split(Platform.pathSeparator).last,
        error: _getErrorMessage(e),
      ));
    }
  }
  for (final info in added) {
    try {
      final pages = await PdfService.instance.getPageCount(info.file.path);
      yield PdfFileResolved(PickedPdfInfo(info.file, pages, info.sizeBytes));
    } catch (e) {
      yield PdfFileFailed(PdfFileError(
        fileName: info.file.path.split(Platform.pathSeparator).last,
        error: _getErrorMessage(e),
      ));
    }
  }
}
