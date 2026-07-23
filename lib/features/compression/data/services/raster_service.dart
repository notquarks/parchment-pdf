import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfrx/pdfrx.dart' as pdfrx;

import 'compression_worker.dart';

class RasterOptions {
    final int targetDpi;

    final int jpegQuality;

    final bool grayscale;

  const RasterOptions({
    this.targetDpi = 96,
    this.jpegQuality = 55,
    this.grayscale = false,
  });
}

class RasterCompressionService {
        Future<String> rasterizePdf({
    required String inputPath,
    required String outputPath,
    required RasterOptions options,
    CancellationToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    final document = await pdfrx.PdfDocument.openFile(inputPath);
    try {
      final pageCount = document.pages.length;
      final pdfDoc = pw.Document();

      for (var i = 0; i < pageCount; i++) {
        _throwIfCancelled(cancelToken);

        final page = document.pages[i];
        await page.ensureLoaded();

                final pageWidthPts = page.width;
        final pageHeightPts = page.height;

                final pixelWidth =
            (pageWidthPts * options.targetDpi / 72).round().clamp(1, 8192);
        final pixelHeight =
            (pageHeightPts * options.targetDpi / 72).round().clamp(1, 8192);

                final pdfImage = await page.render(
          fullWidth: pixelWidth.toDouble(),
          fullHeight: pixelHeight.toDouble(),
          backgroundColor: 0xffffffff,         );

        if (pdfImage == null) {
          throw StateError(
            'Failed to render page ${i + 1} of $inputPath',
          );
        }

        try {
                    final rgba = _bgraToRgba(pdfImage.pixels);
          var image = img.Image.fromBytes(
            width: pdfImage.width,
            height: pdfImage.height,
            bytes: rgba.buffer,
            numChannels: 4,
          );

          if (options.grayscale) {
            image = img.grayscale(image);
          }

                    final jpegBytes = Uint8List.fromList(
            img.encodeJpg(image, quality: options.jpegQuality),
          );

                              pdfDoc.addPage(
            pw.Page(
              pageFormat: PdfPageFormat(
                pageWidthPts,
                pageHeightPts,
                marginTop: 0,
                marginBottom: 0,
                marginLeft: 0,
                marginRight: 0,
              ),
              build: (context) => pw.Expanded(
                child: pw.Image(
                  pw.MemoryImage(jpegBytes),
                  fit: pw.BoxFit.fill,
                ),
              ),
            ),
          );
        } finally {
          pdfImage.dispose();
        }

        onProgress?.call(i + 1, pageCount);
      }

            final outputFile = File(outputPath);
      final parentDir = outputFile.parent;
      if (!await parentDir.exists()) {
        await parentDir.create(recursive: true);
      }
      await outputFile.writeAsBytes(await pdfDoc.save(), flush: true);

      return outputPath;
    } finally {
      await document.dispose();
    }
  }

    static Uint8List _bgraToRgba(Uint8List bgra) {
    final rgba = Uint8List(bgra.length);
    for (var i = 0; i < bgra.length; i += 4) {
      rgba[i] = bgra[i + 2];       rgba[i + 1] = bgra[i + 1];       rgba[i + 2] = bgra[i];       rgba[i + 3] = bgra[i + 3];     }
    return rgba;
  }

  static void _throwIfCancelled(CancellationToken? cancelToken) {
    if (cancelToken?.isCancelled == true) {
      throw CancellationException();
    }
  }
}
