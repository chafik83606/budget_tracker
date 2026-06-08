import 'dart:convert';
import 'dart:io';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'database_service.dart';

class ExportService {
  static final ExportService _instance = ExportService._internal();
  factory ExportService() => _instance;
  ExportService._internal();

  // Clé de chiffrement (32 chars = AES-256)
  static const String _encryptionKey = 'BudgetTracker2024SecureKey123456';
  static const String _encryptionIV = 'BudgetTrackerIV1';

  final DatabaseService _db = DatabaseService();

  // ─── EXPORT CSV ───────────────────────────────────────────────────────────

  Future<void> exportCsv(
    List<Transaction> transactions,
    List<Category> categories,
  ) async {
    final catMap = {for (final c in categories) c.id!: c};

    final rows = <List<dynamic>>[
      ['Date', 'Type', 'Catégorie', 'Libellé', 'Montant', 'Note'],
    ];

    for (final t in transactions) {
      final cat = catMap[t.categoryId];
      rows.add([
        '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}',
        t.type == TransactionType.expense ? 'Dépense' : 'Revenu',
        cat?.name ?? 'Inconnu',
        t.label,
        t.type == TransactionType.expense ? -t.amount : t.amount,
        t.note ?? '',
      ]);
    }

    final csvData = const ListToCsvConverter().convert(rows);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/budget_export.csv');
    await file.writeAsString(csvData, encoding: utf8);

    await Share.shareXFiles([XFile(file.path)], text: 'Export budget CSV');
  }

  // ─── EXPORT PDF ───────────────────────────────────────────────────────────

  Future<void> exportPdf(
    List<Transaction> transactions,
    List<Category> categories,
    int year,
    int month,
  ) async {
    final catMap = {for (final c in categories) c.id!: c};
    final pdf = pw.Document();

    double totalExpenses = 0;
    double totalIncomes = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        totalExpenses += t.amount;
      } else {
        totalIncomes += t.amount;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text(
              'Budget Tracker - $month/$year',
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              pw.Text('Revenus : ${totalIncomes.toStringAsFixed(2)} €   '),
              pw.Text('Dépenses : ${totalExpenses.toStringAsFixed(2)} €   '),
              pw.Text(
                'Solde : ${(totalIncomes - totalExpenses).toStringAsFixed(2)} €',
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Catégorie', 'Libellé', 'Montant'],
            data: transactions.map((t) {
              final cat = catMap[t.categoryId];
              return [
                '${t.date.day.toString().padLeft(2, '0')}/${t.date.month.toString().padLeft(2, '0')}/${t.date.year}',
                t.type == TransactionType.expense ? 'Dépense' : 'Revenu',
                cat?.name ?? 'Inconnu',
                t.label,
                '${t.type == TransactionType.expense ? '-' : '+'}${t.amount.toStringAsFixed(2)} €',
              ];
            }).toList(),
          ),
        ],
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/budget_export_${month}_$year.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Export budget PDF');
  }

  // ─── SAUVEGARDE CHIFFRÉE ──────────────────────────────────────────────────

  Future<void> backupData() async {
    final data = await _db.exportAllData();
    final jsonStr = jsonEncode(data);

    final key = enc.Key.fromUtf8(_encryptionKey);
    final iv = enc.IV.fromUtf8(_encryptionIV);
    final encrypter = enc.Encrypter(enc.AES(key));
    final encrypted = encrypter.encrypt(jsonStr, iv: iv);

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/budget_backup.btk');
    await file.writeAsBytes(encrypted.bytes);

    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Sauvegarde Budget Tracker');
  }

  // ─── RESTAURATION ─────────────────────────────────────────────────────────

  Future<bool> restoreData() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['btk'],
    );

    if (result == null || result.files.single.path == null) return false;

    final file = File(result.files.single.path!);
    final encryptedBytes = await file.readAsBytes();

    final key = enc.Key.fromUtf8(_encryptionKey);
    final iv = enc.IV.fromUtf8(_encryptionIV);
    final encrypter = enc.Encrypter(enc.AES(key));
    final decrypted = encrypter.decrypt(enc.Encrypted(encryptedBytes), iv: iv);

    final data = jsonDecode(decrypted) as Map<String, dynamic>;
    await _db.importAllData(data);
    return true;
  }
}
