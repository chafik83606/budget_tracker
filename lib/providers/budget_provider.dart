import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../models/account.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../services/recurring_service.dart';
import '../services/widget_service.dart';
import '../services/auto_backup_service.dart';
import '../services/notification_service.dart';
import '../models/period_stats.dart';

enum TransactionFilterType { all, expense, income }

class BudgetProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final PreferencesService _prefs = PreferencesService();
  final RecurringService _recurring = RecurringService();

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  List<RecurringTransaction> _recurringTransactions = [];
  List<Account> _accounts = [];
  SavingsGoal? _savingsGoal;
  Transaction? _lastDeletedTransaction;
  bool _isPro = false;
  bool _isDarkTheme = false;
  bool _budgetAlertsEnabled = true;
  int _currentAccountId = 1;
  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;
  bool _isLoading = false;
  String _searchQuery = '';
  TransactionFilterType _filterType = TransactionFilterType.all;
  int? _filterCategoryId;

  List<Transaction> get transactions => _filteredTransactions();
  List<Category> get categories => _categories;
  List<RecurringTransaction> get recurringTransactions =>
      _recurringTransactions;
  List<Account> get accounts => _accounts;
  SavingsGoal? get savingsGoal => _savingsGoal;
  bool get isPro => _isPro;
  bool get isDarkTheme => _isDarkTheme;
  bool get budgetAlertsEnabled => _budgetAlertsEnabled;
  int get currentAccountId => _currentAccountId;
  int get currentYear => _currentYear;
  int get currentMonth => _currentMonth;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  TransactionFilterType get filterType => _filterType;
  int? get filterCategoryId => _filterCategoryId;

  double get totalExpenses => _transactions
      .where((t) => t.type == TransactionType.expense)
      .fold(0, (sum, t) => sum + t.amount);

  double get totalIncomes => _transactions
      .where((t) => t.type == TransactionType.income)
      .fold(0, (sum, t) => sum + t.amount);

  double get balance => totalIncomes - totalExpenses;

  double get savingsProgress =>
      _savingsGoal == null ? 0 : balance.clamp(0, double.infinity);

  double get savingsProgressRatio {
    if (_savingsGoal == null || _savingsGoal!.targetAmount <= 0) return 0;
    return (savingsProgress / _savingsGoal!.targetAmount).clamp(0.0, 1.0);
  }

  Account? get currentAccount {
    try {
      return _accounts.firstWhere((a) => a.id == _currentAccountId);
    } catch (_) {
      return _accounts.isNotEmpty ? _accounts.first : null;
    }
  }

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  Category? getCategoryByName(String name) {
    try {
      return _categories.firstWhere(
        (c) => c.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  List<Transaction> _filteredTransactions() {
    var list = List<Transaction>.from(_transactions);
    if (_filterType == TransactionFilterType.expense) {
      list = list.where((t) => t.type == TransactionType.expense).toList();
    } else if (_filterType == TransactionFilterType.income) {
      list = list.where((t) => t.type == TransactionType.income).toList();
    }
    if (_filterCategoryId != null) {
      list = list.where((t) => t.categoryId == _filterCategoryId).toList();
    }
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      list = list.where((t) {
        final cat = getCategoryById(t.categoryId);
        return t.label.toLowerCase().contains(q) ||
            (t.note?.toLowerCase().contains(q) ?? false) ||
            (t.tags?.toLowerCase().contains(q) ?? false) ||
            (cat?.name.toLowerCase().contains(q) ?? false) ||
            t.amount.toString().contains(q);
      }).toList();
    }
    return list;
  }

  Map<String, List<Transaction>> get groupedTransactions {
    final map = <String, List<Transaction>>{};
    for (final t in transactions) {
      final key =
          '${t.date.year}-${t.date.month.toString().padLeft(2, '0')}-${t.date.day.toString().padLeft(2, '0')}';
      map.putIfAbsent(key, () => []).add(t);
    }
    return map;
  }

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isPro = await _prefs.isPro();
    _isDarkTheme = await _prefs.isDarkTheme();
    _budgetAlertsEnabled = await _prefs.areBudgetAlertsEnabled();
    _currentAccountId = await _prefs.getCurrentAccountId();
    await loadAccounts();
    await loadCategories();
    await _recurring.processDueTransactions();
    await loadRecurringTransactions();
    await loadTransactions();
    await loadSavingsGoal();

    final restored = await AutoBackupService.instance.tryRestoreLatestIfEmpty();
    if (restored) {
      await loadAccounts();
      await loadCategories();
      await loadRecurringTransactions();
      await loadTransactions();
      await loadSavingsGoal();
    }

    await AutoBackupService.instance.runDailyBackupIfNeeded();
    await _checkBudgetAlerts();

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    await loadTransactions();
    await loadSavingsGoal();
    await _checkBudgetAlerts();
  }

  Future<void> _refreshWidget() async {
    await WidgetService.instance.updateWidgetData(
      balance: balance,
      incomes: totalIncomes,
      expenses: totalExpenses,
      year: _currentYear,
      month: _currentMonth,
    );
  }

  Future<void> _checkBudgetAlerts() async {
    if (!_budgetAlertsEnabled) return;
    final expenses = await _db.getExpensesByCategory(
      year: _currentYear,
      month: _currentMonth,
    );
    await NotificationService.instance.checkBudgetAlerts(
      categories: _categories,
      expensesByCategory: expenses,
      year: _currentYear,
      month: _currentMonth,
    );
  }

  Future<void> loadAccounts() async {
    _accounts = await _db.getAccounts();
    notifyListeners();
  }

  Future<void> loadTransactions() async {
    _transactions = await _db.getTransactions(
      year: _currentYear,
      month: _currentMonth,
      limitToThreeMonths: !_isPro,
      accountId: _currentAccountId,
    );
    await _refreshWidget();
    notifyListeners();
  }

  Future<void> loadCategories() async {
    _categories = await _db.getCategories();
    notifyListeners();
  }

  Future<void> loadRecurringTransactions() async {
    _recurringTransactions = await _db.getRecurringTransactions();
    notifyListeners();
  }

  Future<void> loadSavingsGoal() async {
    _savingsGoal = await _db.getSavingsGoal(_currentYear, _currentMonth);
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setFilterType(TransactionFilterType type) {
    _filterType = type;
    notifyListeners();
  }

  void setFilterCategoryId(int? categoryId) {
    _filterCategoryId = categoryId;
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterType = TransactionFilterType.all;
    _filterCategoryId = null;
    notifyListeners();
  }

  Future<void> setCurrentAccount(int accountId) async {
    _currentAccountId = accountId;
    await _prefs.setCurrentAccountId(accountId);
    await loadTransactions();
    await loadSavingsGoal();
  }

  Future<void> setBudgetAlertsEnabled(bool value) async {
    _budgetAlertsEnabled = value;
    await _prefs.setBudgetAlertsEnabled(value);
    notifyListeners();
  }

  void previousMonth() {
    if (_currentMonth == 1) {
      _currentMonth = 12;
      _currentYear--;
    } else {
      _currentMonth--;
    }
    loadTransactions();
    loadSavingsGoal();
  }

  void nextMonth() {
    final now = DateTime.now();
    if (_currentYear == now.year && _currentMonth == now.month) return;
    if (_currentMonth == 12) {
      _currentMonth = 1;
      _currentYear++;
    } else {
      _currentMonth++;
    }
    loadTransactions();
    loadSavingsGoal();
  }

  bool get canGoNext {
    final now = DateTime.now();
    return !(_currentYear == now.year && _currentMonth == now.month);
  }

  Future<Map<int, double>> getCategoryExpensesSummary() async {
    return _db.getExpensesByCategory(
      year: _currentYear,
      month: _currentMonth,
    );
  }

  Future<Map<String, dynamic>?> getMonthComparison() async {
    final prevMonth = _currentMonth == 1 ? 12 : _currentMonth - 1;
    final prevYear = _currentMonth == 1 ? _currentYear - 1 : _currentYear;
    final currentExpenses = totalExpenses;
    final prevExpenses = await _db.getMonthExpensesTotal(
      year: prevYear,
      month: prevMonth,
      accountId: _currentAccountId,
    );
    if (prevExpenses <= 0) return null;
    final changePct = ((currentExpenses - prevExpenses) / prevExpenses) * 100;
    return {
      'current': currentExpenses,
      'previous': prevExpenses,
      'changePct': changePct,
    };
  }

  Future<void> addTransaction(Transaction transaction) async {
    await _db.insertTransaction(
      transaction.copyWith(accountId: _currentAccountId),
    );
    await loadTransactions();
    await _checkBudgetAlerts();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _db.updateTransaction(transaction);
    await loadTransactions();
    await _checkBudgetAlerts();
  }

  Future<void> deleteTransaction(int id) async {
    _lastDeletedTransaction = _transactions.firstWhere((t) => t.id == id);
    await _db.deleteTransaction(id);
    await loadTransactions();
  }

  Future<bool> undoLastDelete() async {
    final t = _lastDeletedTransaction;
    if (t == null) return false;
    await _db.insertTransaction(t.copyWith(id: null));
    _lastDeletedTransaction = null;
    await loadTransactions();
    return true;
  }

  Future<void> duplicateTransaction(Transaction transaction) async {
    await _db.insertTransaction(
      transaction.copyWith(
        id: null,
        date: DateTime.now(),
        recurringId: null,
      ),
    );
    await loadTransactions();
  }

  Future<int> importTransactions(List<Transaction> transactions) async {
    await _db.insertTransactionsBatch(transactions);
    await loadTransactions();
    return transactions.length;
  }

  Future<void> addRecurringTransaction(RecurringTransaction recurring) async {
    await _db.insertRecurringTransaction(recurring);
    await _recurring.processDueTransactions();
    await loadRecurringTransactions();
    await loadTransactions();
  }

  Future<void> updateRecurringTransaction(
    RecurringTransaction recurring,
  ) async {
    await _db.updateRecurringTransaction(recurring);
    await loadRecurringTransactions();
  }

  Future<void> deleteRecurringTransaction(int id) async {
    await _db.deleteRecurringTransaction(id);
    await loadRecurringTransactions();
  }

  Future<void> toggleRecurringActive(RecurringTransaction recurring) async {
    await _db.updateRecurringTransaction(
      recurring.copyWith(isActive: !recurring.isActive),
    );
    if (!recurring.isActive) {
      await _recurring.processDueTransactions();
      await loadTransactions();
    }
    await loadRecurringTransactions();
  }

  Future<void> setSavingsGoal(double targetAmount) async {
    await _db.upsertSavingsGoal(
      SavingsGoal(
        year: _currentYear,
        month: _currentMonth,
        targetAmount: targetAmount,
      ),
    );
    await loadSavingsGoal();
  }

  Future<void> clearSavingsGoal() async {
    await _db.deleteSavingsGoal(_currentYear, _currentMonth);
    _savingsGoal = null;
    notifyListeners();
  }

  Future<void> addCategory(Category category) async {
    await _db.insertCategory(category);
    await loadCategories();
  }

  Future<void> updateCategory(Category category) async {
    await _db.updateCategory(category);
    await loadCategories();
  }

  Future<void> deleteCategory(int id) async {
    await _db.deleteCategory(id);
    await loadCategories();
  }

  Future<void> setPro(bool value) async {
    _isPro = value;
    await _prefs.setPro(value);
    await loadTransactions();
    notifyListeners();
  }

  Future<void> setDarkTheme(bool value) async {
    _isDarkTheme = value;
    await _prefs.setDarkTheme(value);
    notifyListeners();
  }

  Future<Map<int, double>> getExpensesByCategory() async {
    return _db.getExpensesByCategory(
      year: _currentYear,
      month: _currentMonth,
    );
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals() async {
    return _db.getMonthlyTotals(months: 6);
  }

  (int, int) _previousMonth(int year, int month) {
    if (month == 1) return (year - 1, 12);
    return (year, month - 1);
  }

  Future<Map<int, double>> getExpensesByCategoryFor(int year, int month) async {
    return _db.getExpensesByCategory(year: year, month: month);
  }

  Future<({double incomes, double expenses, double balance})> getPeriodTotals(
    int year,
    int month,
  ) async {
    final txs = await _db.getTransactions(
      year: year,
      month: month,
      accountId: _currentAccountId,
    );
    double incomes = 0;
    double expenses = 0;
    for (final t in txs) {
      if (t.type == TransactionType.expense) {
        expenses += t.amount;
      } else {
        incomes += t.amount;
      }
    }
    return (incomes: incomes, expenses: expenses, balance: incomes - expenses);
  }

  Future<PeriodOverview> getPeriodOverview(int year, int month) async {
    final current = await getPeriodTotals(year, month);
    final (prevY, prevM) = _previousMonth(year, month);
    final prev = await getPeriodTotals(prevY, prevM);
    final lastYear = await getPeriodTotals(year - 1, month);
    return PeriodOverview(
      year: year,
      month: month,
      incomes: current.incomes,
      expenses: current.expenses,
      balance: current.balance,
      previousMonthExpenses: prev.expenses,
      sameMonthLastYearExpenses: lastYear.expenses,
      previousMonthBalance: prev.balance,
      sameMonthLastYearBalance: lastYear.balance,
    );
  }

  Future<List<CategoryComparison>> getCategoryComparisons(
    int year,
    int month,
  ) async {
    final current = await getExpensesByCategoryFor(year, month);
    final (prevY, prevM) = _previousMonth(year, month);
    final prev = await getExpensesByCategoryFor(prevY, prevM);
    final lastYear = await getExpensesByCategoryFor(year - 1, month);

    final comparisons = <CategoryComparison>[];
    for (final cat in _categories) {
      if (cat.id == null) continue;
      final id = cat.id!;
      final cur = current[id] ?? 0;
      final p = prev[id] ?? 0;
      final ly = lastYear[id] ?? 0;
      if (cur == 0 && p == 0 && ly == 0) continue;
      comparisons.add(
        CategoryComparison(
          categoryId: id,
          name: cat.name,
          icon: cat.icon,
          current: cur,
          previousMonth: p,
          sameMonthLastYear: ly,
        ),
      );
    }
    comparisons.sort((a, b) => b.current.compareTo(a.current));
    return comparisons;
  }
}
