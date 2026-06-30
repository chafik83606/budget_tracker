import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../models/period_stats.dart';
import '../utils/date_formatters.dart';
import '../providers/budget_provider.dart';
import '../services/pro_purchase_helper.dart';

enum _CompareMode { previousMonth, sameMonthLastYear }

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late int _year;
  late int _month;
  Map<int, double>? _expensesByCategory;
  List<Map<String, dynamic>>? _monthlyTotals;
  PeriodOverview? _overview;
  List<CategoryComparison>? _comparisons;
  _CompareMode _compareMode = _CompareMode.previousMonth;
  int _touchedIndex = -1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final provider = context.read<BudgetProvider>();
    _year = provider.currentYear;
    _month = provider.currentMonth;
    _loadData();
  }

  bool get _canGoNext {
    final now = DateTime.now();
    return !(_year == now.year && _month == now.month);
  }

  void _previousPeriod() {
    if (_month == 1) {
      _month = 12;
      _year--;
    } else {
      _month--;
    }
    _loadData();
  }

  void _nextPeriod() {
    if (!_canGoNext) return;
    if (_month == 12) {
      _month = 1;
      _year++;
    } else {
      _month++;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final provider = context.read<BudgetProvider>();
    final expenses = await provider.getExpensesByCategoryFor(_year, _month);
    final monthly = await provider.getMonthlyTotals();
    final overview = await provider.getPeriodOverview(_year, _month);
    final comparisons = await provider.getCategoryComparisons(_year, _month);
    if (mounted) {
      setState(() {
        _expensesByCategory = expenses;
        _monthlyTotals = monthly;
        _overview = overview;
        _comparisons = comparisons;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Statistiques'), centerTitle: true),
          body: _loading || _expensesByCategory == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _PeriodSelector(
                        year: _year,
                        month: _month,
                        canGoNext: _canGoNext,
                        onPrevious: _previousPeriod,
                        onNext: _nextPeriod,
                      ),
                      const SizedBox(height: 16),
                      if (_overview != null)
                        _OverviewCards(overview: _overview!),
                      const SizedBox(height: 16),
                      SegmentedButton<_CompareMode>(
                        segments: const [
                          ButtonSegment(
                            value: _CompareMode.previousMonth,
                            label: Text('vs mois dernier'),
                          ),
                          ButtonSegment(
                            value: _CompareMode.sameMonthLastYear,
                            label: Text('vs an dernier'),
                          ),
                        ],
                        selected: {_compareMode},
                        onSelectionChanged: (s) {
                          setState(() => _compareMode = s.first);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_comparisons != null && _comparisons!.isNotEmpty)
                        _CategoryComparisonList(
                          comparisons: _comparisons!,
                          mode: _compareMode,
                        )
                      else
                        _EmptyChart(
                          message: 'Pas de dépenses sur cette période',
                        ),
                      const SizedBox(height: 24),
                      _SectionTitle(
                        title: 'Répartition des dépenses',
                        subtitle: formatFrenchMonthYear(
                          DateTime(_year, _month),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (_expensesByCategory!.isEmpty)
                        _EmptyChart(message: 'Aucune dépense ce mois-ci')
                      else
                        _PieChartWidget(
                          expensesByCategory: _expensesByCategory!,
                          provider: provider,
                          touchedIndex: _touchedIndex,
                          onTouch: (i) => setState(() => _touchedIndex = i),
                        ),
                      const SizedBox(height: 24),
                      const _SectionTitle(title: 'Budgets par catégorie'),
                      const SizedBox(height: 12),
                      _BudgetProgressList(
                        expensesByCategory: _expensesByCategory!,
                        provider: provider,
                      ),
                      const SizedBox(height: 24),
                      if (!provider.isPro) ...[
                        _ProFeatureCard(
                          icon: Icons.bar_chart,
                          title: 'Évolution sur 6 mois',
                          description:
                              'Graphique d\'évolution avec la version Pro.',
                          onUpgrade: () => ProPurchaseHelper.requestUpgrade(
                            context,
                            provider,
                          ),
                        ),
                      ] else ...[
                        const _SectionTitle(title: 'Évolution sur 6 mois'),
                        const SizedBox(height: 12),
                        if (_monthlyTotals == null || _monthlyTotals!.isEmpty)
                          _EmptyChart(message: 'Pas encore assez de données')
                        else
                          _BarChartWidget(monthlyTotals: _monthlyTotals!),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  final int year;
  final int month;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _PeriodSelector({
    required this.year,
    required this.month,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrevious,
            ),
            Column(
              children: [
                Text(
                  formatFrenchMonthYear(DateTime(year, month)),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                  ),
                ),
                Text(
                  'Période analysée',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            IconButton(
              icon: Icon(
                Icons.chevron_right,
                color: canGoNext ? null : Colors.grey,
              ),
              onPressed: canGoNext ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final PeriodOverview overview;
  const _OverviewCards({required this.overview});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final savings = overview.savingsVsPreviousMonth;
    final savingsYear = overview.savingsVsLastYear;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Revenus',
                value: fmt.format(overview.incomes),
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: 'Dépenses',
                value: fmt.format(overview.expenses),
                color: Colors.red.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _StatCard(
          label: 'Solde du mois',
          value: fmt.format(overview.balance),
          color: overview.balance >= 0
              ? AppConfig.seedColor
              : Colors.red.shade700,
          fullWidth: true,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _InsightChip(
                title: 'vs mois dernier',
                amount: savings,
                subtitle: savings >= 0
                    ? 'Économie sur les dépenses'
                    : 'Dépenses en hausse',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InsightChip(
                title: 'vs an dernier',
                amount: savingsYear,
                subtitle: savingsYear >= 0
                    ? 'Économie sur les dépenses'
                    : 'Dépenses en hausse',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool fullWidth;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: fullWidth ? 22 : 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InsightChip extends StatelessWidget {
  final String title;
  final double amount;
  final String subtitle;

  const _InsightChip({
    required this.title,
    required this.amount,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final positive = amount >= 0;
    return Card(
      color: positive ? Colors.green.shade50 : Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
            Text(
              '${positive ? '+' : ''}${fmt.format(amount)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: positive ? Colors.green.shade800 : Colors.red.shade800,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryComparisonList extends StatelessWidget {
  final List<CategoryComparison> comparisons;
  final _CompareMode mode;

  const _CategoryComparisonList({
    required this.comparisons,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Comparaison par catégorie'),
        const SizedBox(height: 8),
        ...comparisons.map((c) {
          final reference = mode == _CompareMode.previousMonth
              ? c.previousMonth
              : c.sameMonthLastYear;
          final delta = mode == _CompareMode.previousMonth
              ? c.deltaVsPreviousMonth
              : c.deltaVsLastYear;
          final positive = delta >= 0;
          return Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(c.icon, style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      Text(
                        fmt.format(c.current),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Réf. : ${fmt.format(reference)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        positive ? Icons.arrow_downward : Icons.arrow_upward,
                        size: 14,
                        color: positive ? Colors.green : Colors.red,
                      ),
                      Text(
                        ' ${positive ? '+' : ''}${fmt.format(delta)}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: positive ? Colors.green.shade700 : Colors.red,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    positive
                        ? 'Économie sur ${c.name.toLowerCase()}'
                        : 'Dépense supplémentaire',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _PieChartWidget extends StatelessWidget {
  final Map<int, double> expensesByCategory;
  final BudgetProvider provider;
  final int touchedIndex;
  final ValueChanged<int> onTouch;

  const _PieChartWidget({
    required this.expensesByCategory,
    required this.provider,
    required this.touchedIndex,
    required this.onTouch,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final total = expensesByCategory.values.fold(0.0, (a, b) => a + b);
    final entries = expensesByCategory.entries.toList();

    return Column(
      children: [
        SizedBox(
          height: 220,
          child: PieChart(
            PieChartData(
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  if (response?.touchedSection != null) {
                    onTouch(response!.touchedSection!.touchedSectionIndex);
                  } else {
                    onTouch(-1);
                  }
                },
              ),
              sections: entries.asMap().entries.map((entry) {
                final idx = entry.key;
                final catId = entry.value.key;
                final amount = entry.value.value;
                final cat = provider.getCategoryById(catId);
                final isTouched = idx == touchedIndex;

                return PieChartSectionData(
                  value: amount,
                  title: isTouched
                      ? fmt.format(amount)
                      : '${(amount / total * 100).toStringAsFixed(0)}%',
                  color: cat?.color ?? Colors.grey,
                  radius: isTouched ? 70 : 55,
                  titleStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
              centerSpaceRadius: 40,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: entries.map((entry) {
            final cat = provider.getCategoryById(entry.key);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: cat?.color ?? Colors.grey,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${cat?.icon ?? ''} ${cat?.name ?? 'Autre'} (${fmt.format(entry.value)})',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _BarChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> monthlyTotals;
  const _BarChartWidget({required this.monthlyTotals});

  @override
  Widget build(BuildContext context) {
    const months = [
      'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
      'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
    ];
    final maxY = monthlyTotals.fold<double>(0, (max, m) {
      final e = m['expenses'] as double;
      final i = m['incomes'] as double;
      return e > max ? (i > e ? i : e) : (i > max ? i : max);
    });

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          maxY: maxY * 1.2 + 1,
          barGroups: monthlyTotals.asMap().entries.map((entry) {
            final idx = entry.key;
            final data = entry.value;
            return BarChartGroupData(
              x: idx,
              barRods: [
                BarChartRodData(
                  toY: data['expenses'] as double,
                  color: Colors.red.shade400,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
                BarChartRodData(
                  toY: data['incomes'] as double,
                  color: Colors.green.shade400,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            );
          }).toList(),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= monthlyTotals.length) {
                    return const SizedBox();
                  }
                  final month = (monthlyTotals[idx]['month'] as int) - 1;
                  return Text(months[month], style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()}€', style: const TextStyle(fontSize: 10));
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

class _BudgetProgressList extends StatelessWidget {
  final Map<int, double> expensesByCategory;
  final BudgetProvider provider;
  const _BudgetProgressList({
    required this.expensesByCategory,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final categoriesWithBudget = provider.categories.where(
      (c) => c.monthlyBudget != null && c.monthlyBudget! > 0,
    );

    if (categoriesWithBudget.isEmpty) {
      return Text(
        'Aucun budget fixé. Modifiez vos catégories dans Réglages (Pro).',
        style: TextStyle(color: Colors.grey.shade600),
      );
    }

    return Column(
      children: categoriesWithBudget.map((cat) {
        final spent = expensesByCategory[cat.id] ?? 0;
        final budget = cat.monthlyBudget!;
        final ratio = budget > 0 ? (spent / budget).clamp(0.0, 1.2) : 0.0;
        final isOver = spent > budget;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('${cat.icon} ${cat.name}',
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(
                    '${fmt.format(spent)} / ${fmt.format(budget)}',
                    style: TextStyle(
                      color: isOver ? Colors.red : Colors.green.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio.clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation(
                    isOver ? Colors.red : cat.color,
                  ),
                ),
              ),
              if (isOver)
                Text(
                  'Dépassement : ${fmt.format(spent - budget)}',
                  style: const TextStyle(color: Colors.red, fontSize: 11),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        if (subtitle != null) ...[
          const Spacer(),
          Text(subtitle!, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
        ],
      ],
    );
  }
}

class _EmptyChart extends StatelessWidget {
  final String message;
  const _EmptyChart({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      alignment: Alignment.center,
      child: Text(message, style: TextStyle(color: Colors.grey.shade500)),
    );
  }
}

class _ProFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onUpgrade;
  const _ProFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.onUpgrade,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 36, color: Colors.amber.shade700),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(description,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onUpgrade,
                child: const Text('Passer à Pro — 4,99 €'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
