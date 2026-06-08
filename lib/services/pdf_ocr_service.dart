import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'ocr_service.dart';

typedef PdfOcrProgress = void Function(int currentPage, int totalPages);

/// Extrait le texte d'un PDF scanné (images) via OCR page par page.
class PdfOcrService {
  PdfOcrService._internal();
  static final PdfOcrService instance = PdfOcrService._internal();

  static const int maxPages = 30;

  Future<String> extractTextFromPdf(
    String path, {
    PdfOcrProgress? onProgress,
  }) async {
    final document = await PdfDocument.openFile(path);
    final buffer = StringBuffer();

    try {
      final total = document.pagesCount;
      if (total > maxPages) {
        throw FormatException(
          'PDF trop long ($total pages). Maximum $maxPages pages pour l\'OCR.',
        );
      }

      final tempDir = await getTemporaryDirectory();

      for (var i = 1; i <= total; i++) {
        onProgress?.call(i, total);

        final page = await document.getPage(i);
        try {
          final scale = 2.5;
          final image = await page.render(
            width: page.width * scale,
            height: page.height * scale,
            format: PdfPageImageFormat.png,
          );

          if (image == null || image.bytes.isEmpty) continue;

          final tempFile = File('${tempDir.path}/pdf_ocr_$i.png');
          await tempFile.writeAsBytes(image.bytes);

          final pageText =
              await OcrService.instance.recognizeRawText(tempFile.path);
          if (pageText.isNotEmpty) {
            buffer.writeln(pageText);
          }

          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } finally {
          await page.close();
        }
      }
    } finally {
      await document.close();
    }

    return buffer.toString();
  }
}
