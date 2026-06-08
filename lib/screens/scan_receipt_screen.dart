import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../providers/budget_provider.dart';
import '../services/ocr_service.dart';
import '../services/receipt_parser.dart';
import 'add_transaction_screen.dart';

class ScanReceiptScreen extends StatefulWidget {
  const ScanReceiptScreen({super.key});

  @override
  State<ScanReceiptScreen> createState() => _ScanReceiptScreenState();
}

class _ScanReceiptScreenState extends State<ScanReceiptScreen> {
  final _picker = ImagePicker();
  bool _loading = false;
  String? _error;
  File? _imageFile;
  ParsedReceipt? _parsed;

  Future<void> _pickImage(ImageSource source) async {
    setState(() {
      _loading = true;
      _error = null;
      _parsed = null;
    });

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
      );
      if (picked == null) {
        setState(() => _loading = false);
        return;
      }

      final file = File(picked.path);
      final parsed = await OcrService.instance.scanImageFile(file);

      if (!mounted) return;
      setState(() {
        _imageFile = file;
        _parsed = parsed;
        _loading = false;
      });

      if (!parsed.hasData) {
        setState(() {
          _error =
              'Peu de données détectées. Vérifiez la photo ou saisissez manuellement.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Erreur lors de la lecture : $e';
          _loading = false;
        });
      }
    }
  }

  void _openPrefilledForm() {
    final parsed = _parsed;
    if (parsed == null) return;

    final provider = context.read<BudgetProvider>();
    int? categoryId;
    if (parsed.suggestedCategory != null) {
      final cat = provider.categories.where(
        (c) => c.name.toLowerCase() == parsed.suggestedCategory!.toLowerCase(),
      );
      if (cat.isNotEmpty) categoryId = cat.first.id;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AddTransactionScreen(
          prefilledAmount: parsed.amount,
          prefilledLabel: parsed.label,
          prefilledDate: parsed.date,
          prefilledCategoryId: categoryId,
          prefilledNote: 'Scanné par OCR',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final parsed = _parsed;

    return Scaffold(
      appBar: AppBar(title: const Text('Scanner un ticket')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Prenez en photo un ticket de caisse ou un reçu. '
            'L\'application détectera automatiquement le montant, '
            'la date et le commerçant.',
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Appareil photo'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _loading
                      ? null
                      : () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galerie'),
                ),
              ),
            ],
          ),
          if (_loading) ...[
            const SizedBox(height: 24),
            const Center(child: CircularProgressIndicator()),
            const SizedBox(height: 8),
            const Center(child: Text('Analyse en cours…')),
          ],
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (_imageFile != null) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.file(_imageFile!, height: 180, fit: BoxFit.cover),
            ),
          ],
          if (parsed != null && parsed.hasData) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Données détectées',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    if (parsed.label != null)
                      _InfoRow(label: 'Libellé', value: parsed.label!),
                    if (parsed.amount != null)
                      _InfoRow(
                        label: 'Montant',
                        value: '${parsed.amount!.toStringAsFixed(2)} €',
                      ),
                    if (parsed.date != null)
                      _InfoRow(
                        label: 'Date',
                        value:
                            '${parsed.date!.day.toString().padLeft(2, '0')}/'
                            '${parsed.date!.month.toString().padLeft(2, '0')}/'
                            '${parsed.date!.year}',
                      ),
                    if (parsed.suggestedCategory != null)
                      _InfoRow(
                        label: 'Catégorie suggérée',
                        value: parsed.suggestedCategory!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _openPrefilledForm,
              icon: const Icon(Icons.check),
              label: const Text('Utiliser ces données'),
            ),
          ],
          if (parsed != null && parsed.rawText.isNotEmpty) ...[
            const SizedBox(height: 24),
            ExpansionTile(
              title: const Text('Texte brut détecté'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    parsed.rawText,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
