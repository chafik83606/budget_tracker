import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import 'add_transaction_screen.dart';
import 'scan_receipt_screen.dart';

const List<String> _frMonthNames = [
  'janvier',
  'fevrier',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'aout',
  'septembre',
  'octobre',
  'novembre',
  'decembre',
];

String _formatFrenchMonthYear(DateTime date) {
  return '${_frMonthNames[date.month - 1]} ${date.year}';
}

String _formatDayMonth(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month';
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Budget Tracker'),
            centerTitle: true,
            elevation: 0,
          ),
          body: Column(
            children: [
              _BalanceHeader(provider: provider),
              _SavingsGoalCard(provider: provider),
              _MonthNavigator(provider: provider),
              Expanded(
                child: provider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : provider.transactions.isEmpty
                    ? const _EmptyState()
                    : _TransactionList(provider: provider),
              ),
              // Bannière pub (version gratuite)
              if (!provider.isPro) const _AdBanner(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _showAddOptions(context, provider),
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        );
      },
    );
  }

  void _showAddOptions(BuildContext context, BudgetProvider provider) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Saisie manuelle'),
              onTap: () {
                Navigator.pop(ctx);
                _openAddTransaction(context);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.document_scanner,
                color: provider.isPro ? null : Colors.grey,
              ),
              title: const Text('Scanner un ticket (OCR)'),
              subtitle: provider.isPro
                  ? const Text('Photo de caisse ou reçu')
                  : const Text('Version Pro requise'),
              trailing: provider.isPro
                  ? null
                  : const Icon(Icons.lock, color: Colors.amber, size: 18),
              onTap: () {
                Navigator.pop(ctx);
                if (provider.isPro) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ScanReceiptScreen(),
                    ),
                  );
                } else {
                  _showProRequired(context);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showProRequired(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fonctionnalité Pro'),
        content: const Text(
          'Le scan OCR de tickets est disponible dans la version Pro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _openAddTransaction(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddTransactionScreen()),
    );
  }
}

// ─── WIDGET EN-TÊTE SOLDE ────────────────────────────────────────────────────

class _BalanceHeader extends StatelessWidget {
  final BudgetProvider provider;
  const _BalanceHeader({required this.provider});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final balance = provider.balance;
    final isPositive = balance >= 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [Colors.green.shade600, Colors.green.shade400]
              : [Colors.red.shade600, Colors.red.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solde du mois',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  fmt.format(balance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniStat(
                label: 'Revenus',
                amount: provider.totalIncomes,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 4),
              _MiniStat(
                label: 'Dépenses',
                amount: provider.totalExpenses,
                color: Colors.redAccent.shade100,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _MiniStat({
    required this.label,
    required this.amount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(label, style: TextStyle(color: color, fontSize: 11)),
        Text(
          fmt.format(amount),
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── OBJECTIF D'ÉPARGNE ──────────────────────────────────────────────────────

class _SavingsGoalCard extends StatelessWidget {
  final BudgetProvider provider;
  const _SavingsGoalCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final goal = provider.savingsGoal;
    if (goal == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: OutlinedButton.icon(
          onPressed: () => _showGoalDialog(context, provider, null),
          icon: const Icon(Icons.savings_outlined, size: 18),
          label: const Text('Définir un objectif d\'épargne'),
        ),
      );
    }

    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final progress = provider.savingsProgress;
    final ratio = provider.savingsProgressRatio;
    final reached = progress >= goal.targetAmount;

    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.savings,
                  color: reached ? Colors.green : Colors.indigo,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Objectif d\'épargne',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: () => _showGoalDialog(context, provider, goal.targetAmount),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => provider.clearSavingsGoal(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
                color: reached ? Colors.green : Colors.indigo,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${fmt.format(progress)} / ${fmt.format(goal.targetAmount)}'
              '${reached ? ' — Objectif atteint !' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: reached ? Colors.green.shade700 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoalDialog(
    BuildContext context,
    BudgetProvider provider,
    double? existing,
  ) {
    final ctrl = TextEditingController(
      text: existing?.toStringAsFixed(0) ?? '',
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Objectif d\'épargne'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Montant à épargner ce mois (€)',
            prefixIcon: Icon(Icons.euro),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final amount = double.tryParse(ctrl.text.replaceAll(',', '.'));
              if (amount == null || amount <= 0) return;
              provider.setSavingsGoal(amount);
              Navigator.pop(ctx);
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }
}

// ─── NAVIGATION MOIS ─────────────────────────────────────────────────────────

class _MonthNavigator extends StatelessWidget {
  final BudgetProvider provider;
  const _MonthNavigator({required this.provider});

  @override
  Widget build(BuildContext context) {
    final monthName = _formatFrenchMonthYear(
      DateTime(provider.currentYear, provider.currentMonth),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: provider.previousMonth,
          ),
          Text(
            monthName,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          IconButton(
            icon: Icon(
              Icons.chevron_right,
              color: provider.canGoNext ? null : Colors.grey,
            ),
            onPressed: provider.canGoNext ? provider.nextMonth : null,
          ),
        ],
      ),
    );
  }
}

// ─── LISTE DES TRANSACTIONS ───────────────────────────────────────────────────

class _TransactionList extends StatelessWidget {
  final BudgetProvider provider;
  const _TransactionList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final transactions = provider.transactions;

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final t = transactions[index];
        final cat = provider.getCategoryById(t.categoryId);
        return _TransactionTile(
          transaction: t,
          category: cat,
          provider: provider,
        );
      },
    );
  }
}

class _TransactionTile extends StatelessWidget {
  final Transaction transaction;
  final Category? category;
  final BudgetProvider provider;
  const _TransactionTile({
    required this.transaction,
    required this.category,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final isExpense = transaction.type == TransactionType.expense;
    final dateStr = _formatDayMonth(transaction.date);

    return Dismissible(
      key: Key('t_${transaction.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.red,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
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
                child: const Text(
                  'Supprimer',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => provider.deleteTransaction(transaction.id!),
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(transaction: transaction),
          ),
        ),
        leading: CircleAvatar(
          backgroundColor: (category?.color ?? Colors.grey).withValues(
            alpha: 0.2,
          ),
          child: Text(
            category?.icon ?? '📦',
            style: const TextStyle(fontSize: 20),
          ),
        ),
        title: Text(
          transaction.label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          '${category?.name ?? 'Inconnu'} · $dateStr',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}${fmt.format(transaction.amount)}',
          style: TextStyle(
            color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

// ─── ÉTAT VIDE ────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Aucune transaction ce mois-ci',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Appuyez sur + pour commencer',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

// ─── BANNIÈRE PUB (simulée) ───────────────────────────────────────────────────

class _AdBanner extends StatelessWidget {
  const _AdBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: Colors.grey.shade200,
      child: const Center(
        child: Text(
          '[ Publicité — Passez à la version Pro pour supprimer ]',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ),
    );
  }
}
