import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';

Future<int> getPageCount(Uint8List bytes) async {
  final pdf = Pdf();
  final doc = await pdf.open(MemorySource(bytes));
  final count = doc.pageCount;
  await doc.dispose();
  return count;
}

Future<int> getPageCountIsolate(Uint8List bytes) =>
    compute(getPageCount, bytes);

class PickedPdfInfo {
  PickedPdfInfo(this.file, this.pageCount, this.sizeBytes);
  final File file;
  final int pageCount;
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

Future<List<PickedPdfInfo>> processPdfFiles(List<PlatformFile> files) {
  return Future.wait(files.map((f) async {
    final file = File(f.path!);
    final bytes = await file.readAsBytes();
    final pages = await getPageCountIsolate(bytes);
    return PickedPdfInfo(file, pages, bytes.length);
  }));
}
