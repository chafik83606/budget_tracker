import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/budget_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../services/ad_service.dart';
import '../services/preferences_service.dart';
import 'scan_receipt_screen.dart';

import '../utils/date_formatters.dart';

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction;
  final double? prefilledAmount;
  final String? prefilledLabel;
  final DateTime? prefilledDate;
  final int? prefilledCategoryId;
  final String? prefilledNote;
  final TransactionType? initialType;

  const AddTransactionScreen({
    super.key,
    this.transaction,
    this.prefilledAmount,
    this.prefilledLabel,
    this.prefilledDate,
    this.prefilledCategoryId,
    this.prefilledNote,
    this.initialType,
  });

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _labelController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagsController = TextEditingController();

  TransactionType _type = TransactionType.expense;
  int? _selectedCategoryId;
  DateTime _selectedDate = DateTime.now();

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final t = widget.transaction!;
      _amountController.text = t.amount.toStringAsFixed(2);
      _labelController.text = t.label;
      _noteController.text = t.note ?? '';
      _tagsController.text = t.tags ?? '';
      _type = t.type;
      _selectedCategoryId = t.categoryId;
      _selectedDate = t.date;
    } else {
      if (widget.prefilledAmount != null) {
        _amountController.text = widget.prefilledAmount!.toStringAsFixed(2);
      }
      if (widget.prefilledLabel != null) {
        _labelController.text = widget.prefilledLabel!;
      }
      if (widget.prefilledNote != null) {
        _noteController.text = widget.prefilledNote!;
      }
      if (widget.prefilledDate != null) {
        _selectedDate = widget.prefilledDate!;
      }
      if (widget.prefilledCategoryId != null) {
        _selectedCategoryId = widget.prefilledCategoryId;
      }
      if (widget.initialType != null) {
        _type = widget.initialType!;
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _labelController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        // Pour les revenus on n'affiche pas les catégories (catégorie 6 = Autre par défaut)
        final showCategory = _type == TransactionType.expense;

        return Scaffold(
          appBar: AppBar(
            title: Text(_isEditing ? 'Modifier' : 'Nouvelle transaction'),
            actions: [
              if (!_isEditing && provider.isPro)
                IconButton(
                  icon: const Icon(Icons.document_scanner),
                  tooltip: 'Scanner un ticket',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScanReceiptScreen(),
                    ),
                  ),
                ),
              if (_isEditing)
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: _confirmDelete,
                ),
            ],
          ),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Sélecteur Type
                _TypeSelector(
                  selected: _type,
                  onChanged: (t) => setState(() => _type = t),
                ),
                const SizedBox(height: 16),

                // Montant
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Montant (€)',
                    prefixIcon: Icon(Icons.euro),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Requis';
                    if (double.tryParse(v.replaceAll(',', '.')) == null) {
                      return 'Nombre invalide';
                    }
                    if (double.parse(v.replaceAll(',', '.')) <= 0) {
                      return 'Doit être positif';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Libellé
                TextFormField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    labelText: 'Libellé',
                    prefixIcon: Icon(Icons.label),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 16),

                // Catégorie (uniquement pour les dépenses)
                if (showCategory) ...[
                  _CategorySelector(
                    categories: provider.categories,
                    selectedId: _selectedCategoryId,
                    onChanged: (id) => setState(() => _selectedCategoryId = id),
                  ),
                  const SizedBox(height: 16),
                ],

                // Date
                _DateSelector(
                  date: _selectedDate,
                  onChanged: (d) => setState(() => _selectedDate = d),
                ),
                const SizedBox(height: 16),

                // Note (optionnel)
                TextFormField(
                  controller: _noteController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note (optionnel)',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (optionnel, séparés par des virgules)',
                    prefixIcon: Icon(Icons.sell_outlined),
                    border: OutlineInputBorder(),
                    hintText: 'vacances, urgent',
                  ),
                ),
                const SizedBox(height: 24),

                // Bouton Enregistrer
                FilledButton.icon(
                  onPressed: () => _submit(provider),
                  icon: Icon(_isEditing ? Icons.save : Icons.add),
                  label: Text(_isEditing ? 'Enregistrer' : 'Ajouter'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit(BudgetProvider provider) async {
    if (!_formKey.currentState!.validate()) return;
    if (_type == TransactionType.expense && _selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez choisir une catégorie')),
      );
      return;
    }

    final amount = double.parse(_amountController.text.replaceAll(',', '.'));
    final categoryId =
        _selectedCategoryId ?? 6; // Autre par défaut pour revenus

    final transaction = Transaction(
      id: widget.transaction?.id,
      amount: amount,
      label: _labelController.text.trim(),
      categoryId: categoryId,
      type: _type,
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      tags: _tagsController.text.trim().isEmpty
          ? null
          : _tagsController.text.trim(),
    );

    if (_isEditing) {
      await provider.updateTransaction(transaction);
    } else {
      await provider.addTransaction(transaction);
      // Incrémenter compteur pub
      final count = await PreferencesService().incrementAddCount();
      if (!provider.isPro && count % 5 == 0) {
        await AdService.instance.showInterstitialAd();
      }
    }

    if (mounted) Navigator.pop(context);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: const Text('Supprimer cette transaction ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Supprimer', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<BudgetProvider>().deleteTransaction(
        widget.transaction!.id!,
      );
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

// ─── TYPE SELECTOR ────────────────────────────────────────────────────────────

class _TypeSelector extends StatelessWidget {
  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;
  const _TypeSelector({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<TransactionType>(
      segments: const [
        ButtonSegment(
          value: TransactionType.expense,
          label: Text('Dépense'),
          icon: Icon(Icons.remove_circle_outline),
        ),
        ButtonSegment(
          value: TransactionType.income,
          label: Text('Revenu'),
          icon: Icon(Icons.add_circle_outline),
        ),
      ],
      selected: {selected},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}

// ─── CATEGORY SELECTOR ────────────────────────────────────────────────────────

class _CategorySelector extends StatelessWidget {
  final List<Category> categories;
  final int? selectedId;
  final ValueChanged<int?> onChanged;
  const _CategorySelector({
    required this.categories,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: selectedId,
      decoration: const InputDecoration(
        labelText: 'Catégorie',
        prefixIcon: Icon(Icons.category),
        border: OutlineInputBorder(),
      ),
      items: categories.map((cat) {
        return DropdownMenuItem<int>(
          value: cat.id,
          child: Row(
            children: [
              Text(cat.icon),
              const SizedBox(width: 8),
              Text(cat.name),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (v) => v == null ? 'Requis' : null,
    );
  }
}

// ─── DATE SELECTOR ────────────────────────────────────────────────────────────

class _DateSelector extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onChanged;
  const _DateSelector({required this.date, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onChanged(picked);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_today),
          border: OutlineInputBorder(),
        ),
        child: Text(formatFrenchLongDate(date)),
      ),
    );
  }
}
