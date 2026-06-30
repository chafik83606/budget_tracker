class CategoryComparison {
  final int categoryId;
  final String name;
  final String icon;
  final double current;
  final double previousMonth;
  final double sameMonthLastYear;

  const CategoryComparison({
    required this.categoryId,
    required this.name,
    required this.icon,
    required this.current,
    required this.previousMonth,
    required this.sameMonthLastYear,
  });

  double get deltaVsPreviousMonth => previousMonth - current;
  double get deltaVsLastYear => sameMonthLastYear - current;

  double? get deltaVsPreviousMonthPct =>
      previousMonth > 0 ? (deltaVsPreviousMonth / previousMonth) * 100 : null;

  double? get deltaVsLastYearPct =>
      sameMonthLastYear > 0 ? (deltaVsLastYear / sameMonthLastYear) * 100 : null;
}

class PeriodOverview {
  final int year;
  final int month;
  final double incomes;
  final double expenses;
  final double balance;
  final double previousMonthExpenses;
  final double sameMonthLastYearExpenses;
  final double previousMonthBalance;
  final double sameMonthLastYearBalance;

  const PeriodOverview({
    required this.year,
    required this.month,
    required this.incomes,
    required this.expenses,
    required this.balance,
    required this.previousMonthExpenses,
    required this.sameMonthLastYearExpenses,
    required this.previousMonthBalance,
    required this.sameMonthLastYearBalance,
  });

  double get savingsVsPreviousMonth => previousMonthExpenses - expenses;
  double get savingsVsLastYear => sameMonthLastYearExpenses - expenses;
  double get balanceDeltaVsPreviousMonth => balance - previousMonthBalance;
  double get balanceDeltaVsLastYear => balance - sameMonthLastYearBalance;
}
