import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recurring_transaction.dart';
import '../models/transaction.dart';
import '../providers/budget_provider.dart';

class RecurringTransactionsScreen extends StatelessWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        final list = provider.recurringTransactions;

        return Scaffold(
          appBar: AppBar(title: const Text('Transactions récurrentes')),
          body: list.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune transaction récurrente',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ajoutez un loyer, abonnement ou salaire',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final item = list[index];
                    final cat = provider.getCategoryById(item.categoryId);
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: (cat?.color ?? Colors.grey)
                            .withValues(alpha: 0.2),
                        child: Text(cat?.icon ?? '📦'),
                      ),
                      title: Text(item.label),
                      subtitle: Text(
                        '${item.type == TransactionType.expense ? 'Dépense' : 'Revenu'} · '
                        'Le ${item.dayOfMonth} · '
                        '${item.amount.toStringAsFixed(2)} €',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Switch(
                            value: item.isActive,
                            onChanged: (_) =>
                                provider.toggleRecurringActive(item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showForm(context, provider, item),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _confirmDelete(context, provider, item),
                          ),
                        ],
                      ),
                    );
                  },
                ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _showForm(context, provider, null),
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BudgetProvider provider,
    RecurringTransaction item,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer'),
        content: Text('Supprimer « ${item.label} » ?'),
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
    if (ok == true) await provider.deleteRecurringTransaction(item.id!);
  }

  void _showForm(
    BuildContext context,
    BudgetProvider provider,
    RecurringTransaction? existing,
  ) {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final amountCtrl = TextEditingController(
      text: existing?.amount.toStringAsFixed(2) ?? '',
    );
    final noteCtrl = TextEditingController(text: existing?.note ?? '');
    var type = existing?.type ?? TransactionType.expense;
    var categoryId = existing?.categoryId ?? provider.categories.first.id;
    var dayOfMonth = existing?.dayOfMonth ?? 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          return AlertDialog(
            title: Text(
              existing == null ? 'Nouvelle récurrence' : 'Modifier',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SegmentedButton<TransactionType>(
                    segments: const [
                      ButtonSegment(
                        value: TransactionType.expense,
                        label: Text('Dépense'),
                      ),
                      ButtonSegment(
                        value: TransactionType.income,
                        label: Text('Revenu'),
                      ),
                    ],
                    selected: {type},
                    onSelectionChanged: (s) => setState(() => type = s.first),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: labelCtrl,
                    decoration: const InputDecoration(labelText: 'Libellé'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Montant (€)',
                    ),
                  ),
                  if (type == TransactionType.expense) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      initialValue: categoryId,
                      decoration: const InputDecoration(labelText: 'Catégorie'),
                      items: provider.categories
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.icon} ${c.name}'),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => categoryId = v),
                    ),
                  ],
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: dayOfMonth,
                    decoration: const InputDecoration(
                      labelText: 'Jour du mois',
                    ),
                    items: List.generate(
                      28,
                      (i) => DropdownMenuItem(
                        value: i + 1,
                        child: Text('Le ${i + 1}'),
                      ),
                    ),
                    onChanged: (v) => setState(() => dayOfMonth = v ?? 1),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Note (optionnel)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  final amount = double.tryParse(
                    amountCtrl.text.replaceAll(',', '.'),
                  );
                  if (labelCtrl.text.isEmpty || amount == null || amount <= 0) {
                    return;
                  }
                  final now = DateTime.now();
                  final recurring = RecurringTransaction(
                    id: existing?.id,
                    label: labelCtrl.text.trim(),
                    amount: amount,
                    categoryId: categoryId ?? 6,
                    type: type,
                    dayOfMonth: dayOfMonth,
                    note: noteCtrl.text.trim().isEmpty
                        ? null
                        : noteCtrl.text.trim(),
                    isActive: existing?.isActive ?? true,
                    startYear: existing?.startYear ?? now.year,
                    startMonth: existing?.startMonth ?? now.month,
                    lastGeneratedYear: existing?.lastGeneratedYear,
                    lastGeneratedMonth: existing?.lastGeneratedMonth,
                  );
                  if (existing == null) {
                    provider.addRecurringTransaction(recurring);
                  } else {
                    provider.updateRecurringTransaction(recurring);
                  }
                  Navigator.pop(ctx);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      ),
    );
  }
}
