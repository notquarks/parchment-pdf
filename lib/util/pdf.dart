// lib/utils/pdf_utils.dart
import 'package:flutter/foundation.dart';
import 'package:pdf_manipulator/pdf_manipulator.dart';

Future<int> getPageCount(Uint8List bytes) async {
  final pdf = Pdf();
  final doc = await pdf.open(MemorySource(bytes));
  final count = doc.pageCount;
  await doc.dispose();
  return count;
}
