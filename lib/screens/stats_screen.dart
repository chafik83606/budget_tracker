import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/budget_provider.dart';

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

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Map<int, double>? _expensesByCategory;
  List<Map<String, dynamic>>? _monthlyTotals;
  int _touchedIndex = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<BudgetProvider>();
    final expenses = await provider.getExpensesByCategory();
    final monthly = await provider.getMonthlyTotals();
    if (mounted) {
      setState(() {
        _expensesByCategory = expenses;
        _monthlyTotals = monthly;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BudgetProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          appBar: AppBar(title: const Text('Statistiques'), centerTitle: true),
          body: _expensesByCategory == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Titre section camembert
                    _SectionTitle(
                      title: 'Dépenses par catégorie',
                      subtitle: _formatFrenchMonthYear(
                        DateTime(provider.currentYear, provider.currentMonth),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Camembert
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

                    // Graphique barres (Pro uniquement)
                    if (!provider.isPro) ...[
                      _ProFeatureCard(
                        icon: Icons.bar_chart,
                        title: 'Évolution mensuelle',
                        description:
                            'Visualisez vos dépenses sur 6 mois avec la version Pro.',
                      ),
                    ] else ...[
                      const _SectionTitle(title: 'Évolution sur 6 mois'),
                      const SizedBox(height: 12),
                      if (_monthlyTotals == null || _monthlyTotals!.isEmpty)
                        _EmptyChart(message: 'Pas encore assez de données')
                      else
                        _BarChartWidget(monthlyTotals: _monthlyTotals!),
                    ],

                    const SizedBox(height: 24),

                    // Budget par catégorie (Pro uniquement)
                    if (provider.isPro) ...[
                      const _SectionTitle(title: 'Budget par catégorie'),
                      const SizedBox(height: 12),
                      _BudgetProgressList(
                        expensesByCategory: _expensesByCategory!,
                        provider: provider,
                      ),
                    ],
                  ],
                ),
        );
      },
    );
  }
}

// ─── CAMEMBERT ────────────────────────────────────────────────────────────────

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
                  titleStyle: TextStyle(
                    fontSize: isTouched ? 13 : 11,
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
        // Légende
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

// ─── BARRES (PRO) ─────────────────────────────────────────────────────────────

class _BarChartWidget extends StatelessWidget {
  final List<Map<String, dynamic>> monthlyTotals;
  const _BarChartWidget({required this.monthlyTotals});

  @override
  Widget build(BuildContext context) {
    final months = [
      'Jan',
      'Fév',
      'Mar',
      'Avr',
      'Mai',
      'Jun',
      'Jul',
      'Aoû',
      'Sep',
      'Oct',
      'Nov',
      'Déc',
    ];

    final maxY = monthlyTotals.fold<double>(0, (max, m) {
      final e = (m['expenses'] as double);
      final i = (m['incomes'] as double);
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
                  toY: (data['expenses'] as double),
                  color: Colors.red.shade400,
                  width: 10,
                  borderRadius: BorderRadius.circular(4),
                ),
                BarChartRodData(
                  toY: (data['incomes'] as double),
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
                  return Text(
                    months[month],
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '${value.toInt()}€',
                    style: const TextStyle(fontSize: 10),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(show: true, drawVerticalLine: false),
          borderData: FlBorderData(show: false),
        ),
      ),
    );
  }
}

// ─── BUDGET PROGRESSION (PRO) ─────────────────────────────────────────────────

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
      return const Text(
        'Aucun budget fixé. Modifiez vos catégories dans Réglages.',
        style: TextStyle(color: Colors.grey),
      );
    }

    return Column(
      children: categoriesWithBudget.map((cat) {
        final spent = expensesByCategory[cat.id] ?? 0;
        final budget = cat.monthlyBudget!;
        final ratio = (spent / budget).clamp(0.0, 1.0);
        final isOver = spent > budget;

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${cat.icon} ${cat.name}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  Text(
                    '${fmt.format(spent)} / ${fmt.format(budget)}',
                    style: TextStyle(
                      color: isOver ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ratio,
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

// ─── HELPERS ──────────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        if (subtitle != null) ...[
          const Spacer(),
          Text(
            subtitle!,
            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
          ),
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
      height: 120,
      alignment: Alignment.center,
      child: Text(message, style: TextStyle(color: Colors.grey.shade500)),
    );
  }
}

class _ProFeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  const _ProFeatureCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Colors.amber.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
