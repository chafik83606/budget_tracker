import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../services/import_service.dart';

class ImportDataScreen extends StatefulWidget {
  const ImportDataScreen({super.key});

  @override
  State<ImportDataScreen> createState() => _ImportDataScreenState();
}

class _ImportDataScreenState extends State<ImportDataScreen> {
  List<ImportPreviewRow> _rows = [];
  bool _loading = false;
  String? _error;
  String? _sourceLabel;
  String? _progressMessage;
  int _progressCurrent = 0;
  int _progressTotal = 0;

  Future<void> _pickCsv() async {
    await _pickFile(
      label: 'CSV',
      loader: () => ImportService().pickAndParseCsv(),
    );
  }

  Future<void> _pickPdf() async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
      _sourceLabel = null;
      _progressMessage = null;
      _progressCurrent = 0;
      _progressTotal = 0;
    });

    try {
      final rows = await ImportService().pickAndParsePdf(
        onProgress: (message, current, total) {
          if (mounted) {
            setState(() {
              _progressMessage = message;
              _progressCurrent = current;
              _progressTotal = total;
            });
          }
        },
      );
      if (rows.isEmpty && mounted) {
        setState(() => _loading = false);
        return;
      }
      if (mounted) {
        setState(() {
          _rows = rows;
          _sourceLabel = 'PDF';
          _loading = false;
          _progressMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('FormatException: ', '');
          _loading = false;
          _progressMessage = null;
        });
      }
    }
  }

  Future<void> _pickFile({
    required String label,
    required Future<List<ImportPreviewRow>> Function() loader,
  }) async {
    setState(() {
      _loading = true;
      _error = null;
      _rows = [];
      _sourceLabel = null;
    });
    try {
      final rows = await loader();
      if (rows.isEmpty && mounted) {
        setState(() => _loading = false);
        return;
      }
      if (mounted) {
        setState(() {
          _rows = rows;
          _sourceLabel = label;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('FormatException: ', '');
          _loading = false;
        });
      }
    }
  }

  Future<void> _import() async {
    setState(() => _loading = true);
    try {
      final count = await ImportService().importRows(_rows);
      if (!mounted) return;
      await context.read<BudgetProvider>().loadTransactions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count transaction(s) importée(s)')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors de l\'import';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final validCount = _rows.where((r) => r.selected && r.error == null).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Importer des données')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Importez un relevé bancaire ou un export Budget Tracker '
                  'depuis un fichier CSV ou PDF. Les PDF scannés (images) '
                  'sont lus automatiquement page par page via OCR.',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _pickCsv,
                        icon: const Icon(Icons.table_chart),
                        label: const Text('Fichier CSV'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _pickPdf,
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Fichier PDF'),
                      ),
                    ),
                  ],
                ),
                if (_sourceLabel != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Source : $_sourceLabel — ${_rows.length} ligne(s) détectée(s)',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
              ],
            ),
          ),
          if (_loading) ...[
            const LinearProgressIndicator(),
            if (_progressMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Text(
                  _progressTotal > 0
                      ? '$_progressMessage ($_progressCurrent/$_progressTotal)'
                      : _progressMessage!,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
          Expanded(
            child: _rows.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (context, index) {
                      final row = _rows[index];
                      if (row.error != null) {
                        return ListTile(
                          leading: const Icon(Icons.error, color: Colors.red),
                          title: Text(row.error!),
                        );
                      }
                      final t = row.transaction;
                      return CheckboxListTile(
                        value: row.selected,
                        onChanged: (v) {
                          setState(() {
                            _rows[index] = row.copyWith(selected: v ?? false);
                          });
                        },
                        title: Text(t.label),
                        subtitle: Text(
                          '${row.categoryName} · '
                          '${t.date.day}/${t.date.month}/${t.date.year}',
                        ),
                        secondary: Text(
                          '${t.type.name == 'expense' ? '-' : '+'}${fmt.format(t.amount)}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: t.type.name == 'expense'
                                ? Colors.red.shade700
                                : Colors.green.shade700,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          if (_rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _loading || validCount == 0 ? null : _import,
                child: Text('Importer $validCount transaction(s)'),
              ),
            ),
        ],
      ),
    );
  }
}
