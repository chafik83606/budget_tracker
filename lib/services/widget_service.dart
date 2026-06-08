import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class WidgetService {
  WidgetService._internal();
  static final WidgetService instance = WidgetService._internal();

  static const String androidWidgetName = 'BudgetTrackerWidget';
  static const String iosWidgetName = 'BudgetTrackerWidget';

  static const String keyBalance = 'balance';
  static const String keyIncomes = 'incomes';
  static const String keyExpenses = 'expenses';
  static const String keyMonth = 'month_label';

  Future<void> initialize() async {
    try {
      await HomeWidget.setAppGroupId('group.budget_tracker.widget');
    } catch (_) {}
  }

  Future<void> updateWidgetData({
    required double balance,
    required double incomes,
    required double expenses,
    required int year,
    required int month,
  }) async {
    const monthNames = [
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

    final fmt = NumberFormat.currency(locale: 'fr_FR', symbol: '€');
    final monthLabel = '${monthNames[month - 1]} $year';

    await HomeWidget.saveWidgetData<String>(keyBalance, fmt.format(balance));
    await HomeWidget.saveWidgetData<String>(keyIncomes, fmt.format(incomes));
    await HomeWidget.saveWidgetData<String>(keyExpenses, fmt.format(expenses));
    await HomeWidget.saveWidgetData<String>(keyMonth, monthLabel);

    await HomeWidget.updateWidget(
      androidName: androidWidgetName,
      iOSName: iosWidgetName,
    );
  }
}
