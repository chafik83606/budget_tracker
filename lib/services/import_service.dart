import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';

import '../models/category.dart';
import '../models/transaction.dart';
import 'database_service.dart';
import 'pdf_ocr_service.dart';

typedef ImportProgressCallback = void Function(
  String message,
  int current,
  int total,
);

class ImportPreviewRow {
  final Transaction transaction;
  final String categoryName;
  final bool selected;
  final String? error;

  const ImportPreviewRow({
    required this.transaction,
    required this.categoryName,
    this.selected = true,
    this.error,
  });

  ImportPreviewRow copyWith({bool? selected}) {
    return ImportPreviewRow(
      transaction: transaction,
      categoryName: categoryName,
      selected: selected ?? this.selected,
      error: error,
    );
  }
}

class ImportService {
  static final ImportService _instance = ImportService._internal();
  factory ImportService() => _instance;
  ImportService._internal();

  final DatabaseService _db = DatabaseService();

  Future<List<ImportPreviewRow>> pickAndParseCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (result == null || result.files.single.path == null) {
      return [];
    }

    final file = File(result.files.single.path!);
    final content = await file.readAsString(encoding: utf8);
    return parseCsvContent(content);
  }

  Future<List<ImportPreviewRow>> pickAndParsePdf({
    ImportProgressCallback? onProgress,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result == null || result.files.single.path == null) {
      return [];
    }

    return parsePdfFile(
      result.files.single.path!,
      onProgress: onProgress,
    );
  }

  Future<List<ImportPreviewRow>> parsePdfFile(
    String path, {
    ImportProgressCallback? onProgress,
  }) async {
    onProgress?.call('Analyse du PDF…', 0, 0);

    final text = await PdfOcrService.instance.extractTextFromPdf(
      path,
      onProgress: (current, total) {
        onProgress?.call('OCR page $current/$total…', current, total);
      },
    );

    if (text.trim().isEmpty) {
      throw FormatException(
        'Aucun texte détecté dans le PDF. Vérifiez la qualité du scan.',
      );
    }

    return parsePdfText(text, note: 'Importé depuis PDF (OCR)');
  }

  /// Parse le texte extrait d'un relevé PDF bancaire (texte natif ou OCR).
  Future<List<ImportPreviewRow>> parsePdfText(
    String text, {
    String note = 'Importé depuis PDF',
  }) async {
    final categories = await _db.getCategories();
    final preview = <ImportPreviewRow>[];
    final seen = <String>{};

    final normalized = _normalizeOcrText(text);
    final lines = normalized
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);

    final linePattern = RegExp(
      r'(\d{2}\s*[/.-]\s*\d{2}\s*[/.-]\s*\d{2,4})\s+(.+?)\s+(-?\d[\d\s]*[,.]\d{2})\s*€?',
    );

    final amountEndPattern = RegExp(
      r'(\d{2}\s*[/.-]\s*\d{2}\s*[/.-]\s*\d{2,4})\s+(.+?)\s+(-?\d[\d\s]*[,.]\d{2})\s*$',
    );

    final compactPattern = RegExp(
      r'(\d{2}\s*[/.-]\s*\d{2}\s*[/.-]\s*\d{2,4}).*?(-?\d[\d\s]*[,.]\d{2})',
    );

    for (final line in lines) {
      ImportPreviewRow? row;

      final full = linePattern.firstMatch(line);
      if (full != null) {
        row = _rowFromParts(
          full.group(1)!,
          full.group(2)!,
          full.group(3)!,
          categories,
          note: note,
        );
      } else {
        final end = amountEndPattern.firstMatch(line);
        if (end != null) {
          row = _rowFromParts(
            end.group(1)!,
            end.group(2)!,
            end.group(3)!,
            categories,
            note: note,
          );
        } else {
          final compact = compactPattern.firstMatch(line);
          if (compact != null) {
            row = _rowFromParts(
              compact.group(1)!,
              'Import PDF',
              compact.group(2)!,
              categories,
              note: note,
            );
          }
        }
      }

      if (row != null) {
        final key =
            '${row.transaction.date.toIso8601String()}_'
            '${row.transaction.amount}_'
            '${row.transaction.label}';
        if (seen.add(key)) {
          preview.add(row);
        }
      }
    }

    if (preview.isEmpty) {
      throw FormatException(
        'Aucune transaction détectée. '
        'Le relevé doit contenir des lignes avec date et montant (ex. 15/03/2024 … -45,67).',
      );
    }

    return preview;
  }

  String _normalizeOcrText(String text) {
    return text
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n');
  }

  ImportPreviewRow? _rowFromParts(
    String dateStr,
    String label,
    String amountStr,
    List<Category> categories, {
    String note = 'Importé depuis PDF',
  }) {
    final date = _parseDate(dateStr.replaceAll(' ', ''));
    if (date == null) return null;

    var amountRaw = amountStr.replaceAll(' ', '').replaceAll(',', '.');
    final parsed = double.tryParse(amountRaw);
    if (parsed == null || parsed == 0) return null;

    final type = parsed < 0 ? TransactionType.expense : TransactionType.income;
    final amount = parsed.abs();
    final category = _matchCategory('Autre', categories);

    final cleanLabel = label
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    return ImportPreviewRow(
      transaction: Transaction(
        amount: amount,
        label: cleanLabel.isEmpty ? 'Import PDF' : cleanLabel,
        categoryId: category.id!,
        type: type,
        date: date,
        note: note,
      ),
      categoryName: category.name,
    );
  }

  Future<List<ImportPreviewRow>> parseCsvContent(String content) async {
    final categories = await _db.getCategories();
    final rows = const CsvToListConverter().convert(content);

    if (rows.isEmpty) return [];

    final header = rows.first.map((c) => c.toString().trim().toLowerCase()).toList();
    final dataRows = rows.skip(1).where((r) => r.isNotEmpty).toList();

    final dateIdx = _findColumn(header, ['date']);
    final typeIdx = _findColumn(header, ['type']);
    final categoryIdx = _findColumn(header, ['catégorie', 'categorie', 'category']);
    final labelIdx = _findColumn(header, ['libellé', 'libelle', 'label', 'description']);
    final amountIdx = _findColumn(header, ['montant', 'amount']);
    final noteIdx = _findColumn(header, ['note']);

    if (dateIdx == null || amountIdx == null) {
      throw FormatException(
        'Colonnes requises manquantes. Attendu : Date, Montant (et optionnellement Type, Catégorie, Libellé, Note).',
      );
    }

    final preview = <ImportPreviewRow>[];

    for (final row in dataRows) {
      try {
        final dateStr = row[dateIdx].toString().trim();
        final date = _parseDate(dateStr);
        if (date == null) {
          preview.add(
            ImportPreviewRow(
              transaction: _placeholder(),
              categoryName: '',
              selected: false,
              error: 'Date invalide : $dateStr',
            ),
          );
          continue;
        }

        var amountRaw = row[amountIdx].toString().trim().replaceAll(' ', '');
        amountRaw = amountRaw.replaceAll('€', '').replaceAll(',', '.');
        final amount = double.tryParse(amountRaw)?.abs();
        if (amount == null || amount <= 0) {
          preview.add(
            ImportPreviewRow(
              transaction: _placeholder(),
              categoryName: '',
              selected: false,
              error: 'Montant invalide',
            ),
          );
          continue;
        }

        TransactionType type = TransactionType.expense;
        if (typeIdx != null && row.length > typeIdx) {
          final typeStr = row[typeIdx].toString().toLowerCase();
          if (typeStr.contains('revenu') || typeStr.contains('income')) {
            type = TransactionType.income;
          }
        } else if (amountRaw.startsWith('-') ||
            (row[amountIdx].toString().contains('-') &&
                !row[amountIdx].toString().contains('+'))) {
          type = TransactionType.expense;
        }

        String categoryName = 'Autre';
        if (categoryIdx != null && row.length > categoryIdx) {
          categoryName = row[categoryIdx].toString().trim();
          if (categoryName.isEmpty) categoryName = 'Autre';
        }

        final category = _matchCategory(categoryName, categories);

        String label = 'Import CSV';
        if (labelIdx != null && row.length > labelIdx) {
          label = row[labelIdx].toString().trim();
          if (label.isEmpty) label = 'Import CSV';
        }

        String? note;
        if (noteIdx != null && row.length > noteIdx) {
          final n = row[noteIdx].toString().trim();
          if (n.isNotEmpty) note = n;
        }

        preview.add(
          ImportPreviewRow(
            transaction: Transaction(
              amount: amount,
              label: label,
              categoryId: category.id!,
              type: type,
              date: date,
              note: note,
            ),
            categoryName: category.name,
          ),
        );
      } catch (e) {
        preview.add(
          ImportPreviewRow(
            transaction: _placeholder(),
            categoryName: '',
            selected: false,
            error: 'Ligne ignorée : $e',
          ),
        );
      }
    }

    return preview;
  }

  Future<int> importRows(List<ImportPreviewRow> rows) async {
    final toImport = rows
        .where((r) => r.selected && r.error == null)
        .map((r) => r.transaction)
        .toList();
    if (toImport.isEmpty) return 0;
    await _db.insertTransactionsBatch(toImport);
    return toImport.length;
  }

  int? _findColumn(List<String> header, List<String> names) {
    for (final name in names) {
      final idx = header.indexOf(name);
      if (idx >= 0) return idx;
    }
    return null;
  }

  DateTime? _parseDate(String value) {
    final cleaned = value.replaceAll(' ', '');
    final formats = [
      RegExp(r'^(\d{2})/(\d{2})/(\d{4})$'),
      RegExp(r'^(\d{2})/(\d{2})/(\d{2})$'),
      RegExp(r'^(\d{2})-(\d{2})-(\d{4})$'),
      RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$'),
      RegExp(r'^(\d{4})-(\d{2})-(\d{2})'),
    ];

    for (final re in formats) {
      final m = re.firstMatch(cleaned);
      if (m == null) continue;

      if (re == formats[4]) {
        return DateTime.parse(cleaned);
      }

      final day = int.parse(m.group(1)!);
      final month = int.parse(m.group(2)!);
      var year = int.parse(m.group(3)!);
      if (year < 100) year += 2000;

      try {
        return DateTime(year, month, day);
      } catch (_) {
        continue;
      }
    }
    return DateTime.tryParse(cleaned);
  }

  Category _matchCategory(String name, List<Category> categories) {
    final lower = name.toLowerCase();
    for (final cat in categories) {
      if (cat.name.toLowerCase() == lower) return cat;
    }
    return categories.firstWhere(
      (c) => c.name == 'Autre',
      orElse: () => categories.last,
    );
  }

  Transaction _placeholder() {
    return Transaction(
      amount: 0,
      label: '',
      categoryId: 6,
      type: TransactionType.expense,
      date: DateTime.now(),
    );
  }
}
