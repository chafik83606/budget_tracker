import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../providers/budget_provider.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../utils/date_formatters.dart';
import '../widgets/add_bottom_sheet.dart';
import 'add_transaction_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  bool _showSearch = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(
            title: _showSearch
                ? TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: AppStrings.searchHint,
                      border: InputBorder.none,
                    ),
                    onChanged: provider.setSearchQuery,
                  )
                : Text(
                    provider.currentAccount != null
                        ? '${provider.currentAccount!.icon} Budget Tracker'
                        : 'Budget Tracker',
                  ),
            centerTitle: true,
            actions: [
              IconButton(
                icon: Icon(_showSearch ? Icons.close : Icons.search),
                onPressed: () {
                  setState(() {
                    _showSearch = !_showSearch;
                    if (!_showSearch) {
                      _searchController.clear();
                      provider.clearFilters();
                    }
                  });
                },
              ),
              if (_showSearch)
                PopupMenuButton<TransactionFilterType>(
                  icon: const Icon(Icons.filter_list),
                  onSelected: provider.setFilterType,
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: TransactionFilterType.all,
                      child: Text('Tous'),
                    ),
                    PopupMenuItem(
                      value: TransactionFilterType.expense,
                      child: Text('Dépenses'),
                    ),
                    PopupMenuItem(
                      value: TransactionFilterType.income,
                      child: Text('Revenus'),
                    ),
                  ],
                ),
            ],
          ),
          body: Column(
            children: [
              _BalanceHeader(provider: provider),
              _SavingsGoalCard(provider: provider),
              _CategorySummary(provider: provider),
              _MonthNavigator(provider: provider),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: provider.refresh,
                  child: provider.isLoading
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: CircularProgressIndicator()),
                          ],
                        )
                      : provider.transactions.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 80),
                            _EmptyState(),
                          ],
                        )
                      : _GroupedTransactionList(provider: provider),
                ),
              ),
              if (!provider.isPro) const _AdBanner(),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => showAddBottomSheet(context, provider),
            backgroundColor: AppConfig.seedColor,
            icon: const Icon(Icons.add),
            label: Text(AppStrings.add),
          ),
        );
      },
    );
  }
}

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
              ? [AppConfig.seedColor, Colors.green.shade400]
              : [Colors.red.shade700, Colors.red.shade400],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.balanceMonth,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(end: balance),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOut,
                  builder: (_, value, __) => Text(
                    fmt.format(value),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _MiniStat(
                label: AppStrings.incomes,
                amount: provider.totalIncomes,
                color: Colors.greenAccent,
              ),
              const SizedBox(height: 4),
              _MiniStat(
                label: AppStrings.expenses,
                amount: provider.totalExpenses,
                color: Colors.red.shade100,
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
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

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
                  color: reached ? Colors.green : AppConfig.seedColor,
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
                  onPressed: () =>
                      _showGoalDialog(context, provider, goal.targetAmount),
                ),
              ],
            ),
            TweenAnimationBuilder<double>(
              tween: Tween(end: ratio),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOut,
              builder: (_, value, __) => LinearProgressIndicator(
                value: value,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
                backgroundColor: Colors.grey.shade200,
                color: reached ? Colors.green : AppConfig.seedColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${fmt.format(progress)} / ${fmt.format(goal.targetAmount)}'
              '${reached ? ' — Objectif atteint !' : ''}',
              style: TextStyle(
                fontSize: 13,
                color: reached ? Colors.green.shade700 : Colors.grey.shade600,
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

class _CategorySummary extends StatefulWidget {
  final BudgetProvider provider;
  const _CategorySummary({required this.provider});

  @override
  State<_CategorySummary> createState() => _CategorySummaryState();
}

class _CategorySummaryState extends State<_CategorySummary> {
  Map<int, double>? _expenses;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(_CategorySummary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.provider.currentMonth != widget.provider.currentMonth ||
        oldWidget.provider.currentYear != widget.provider.currentYear) {
      _load();
    }
  }

  Future<void> _load() async {
    final data = await widget.provider.getCategoryExpensesSummary();
    if (mounted) setState(() => _expenses = data);
  }

  @override
  Widget build(BuildContext context) {
    final expenses = _expenses;
    if (expenses == null || expenses.isEmpty) return const SizedBox.shrink();

    final withBudget = widget.provider.categories
        .where((c) => c.monthlyBudget != null && c.monthlyBudget! > 0)
        .where((c) => expenses.containsKey(c.id))
        .take(4)
        .toList();

    if (withBudget.isEmpty) return const SizedBox.shrink();
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.categoriesSummary,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          ...withBudget.map((cat) {
            final spent = expenses[cat.id!] ?? 0;
            final budget = cat.monthlyBudget!;
            final ratio = (spent / budget).clamp(0.0, 1.0);
            final over = spent > budget;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(cat.icon, style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          cat.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      Text(
                        '${fmt.format(spent)} / ${fmt.format(budget)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: over ? Colors.red : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    backgroundColor: Colors.grey.shade200,
                    color: over ? Colors.red : cat.color,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MonthNavigator extends StatelessWidget {
  final BudgetProvider provider;
  const _MonthNavigator({required this.provider});

  @override
  Widget build(BuildContext context) {
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
            formatFrenchMonthYear(
              DateTime(provider.currentYear, provider.currentMonth),
            ),
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

class _GroupedTransactionList extends StatelessWidget {
  final BudgetProvider provider;
  const _GroupedTransactionList({required this.provider});

  @override
  Widget build(BuildContext context) {
    final groups = provider.groupedTransactions;
    final keys = groups.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final parts = key.split('-');
        final date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        final txs = groups[key]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                formatDayHeader(date),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                  fontSize: 13,
                ),
              ),
            ),
            ...txs.map(
              (t) => _TransactionTile(
                transaction: t,
                category: provider.getCategoryById(t.categoryId),
                provider: provider,
              ),
            ),
          ],
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
      onDismissed: (_) async {
        await provider.deleteTransaction(transaction.id!);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppStrings.deleted),
              action: SnackBarAction(
                label: AppStrings.undo,
                onPressed: () => provider.undoLastDelete(),
              ),
            ),
          );
        }
      },
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddTransactionScreen(transaction: transaction),
          ),
        ),
        onLongPress: () => _showActions(context),
        leading: CircleAvatar(
          backgroundColor: (category?.color ?? Colors.grey).withValues(
            alpha: 0.2,
          ),
          child: Text(category?.icon ?? '📦', style: const TextStyle(fontSize: 20)),
        ),
        title: Text(
          transaction.label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: Text(
          [
            category?.name ?? 'Inconnu',
            if (transaction.tags?.isNotEmpty == true) transaction.tags,
          ].join(' · '),
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Text(
          '${isExpense ? '-' : '+'}${fmt.format(transaction.amount)}',
          style: TextStyle(
            color: isExpense ? Colors.red.shade700 : Colors.green.shade700,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: Text(AppStrings.duplicate),
              onTap: () {
                Navigator.pop(ctx);
                provider.duplicateTransaction(transaction);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Modifier'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        AddTransactionScreen(transaction: transaction),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

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

class _AdBanner extends StatelessWidget {
  const _AdBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      color: Colors.grey.shade200,
      child: Center(
        child: Text(
          '[ Publicité — Pro supprime les pubs ]',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ),
    );
  }
}
