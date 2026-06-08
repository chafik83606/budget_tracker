import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'receipt_parser.dart';

class OcrService {
  OcrService._internal();
  static final OcrService instance = OcrService._internal();

  Future<ParsedReceipt> scanImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      final text = result.text.trim();

      if (text.isEmpty) {
        return ParsedReceipt(rawText: '');
      }

      return ReceiptParser.parse(text);
    } finally {
      await recognizer.close();
    }
  }

  Future<ParsedReceipt> scanImageFile(File file) async {
    return scanImage(file.path);
  }

  /// Retourne le texte brut reconnu (sans parsing ticket).
  Future<String> recognizeRawText(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
