import 'package:flutter/material.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';
import '../services/database_service.dart';
import '../services/preferences_service.dart';
import '../services/recurring_service.dart';
import '../services/widget_service.dart';
import '../services/auto_backup_service.dart';

class BudgetProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService();
  final PreferencesService _prefs = PreferencesService();
  final RecurringService _recurring = RecurringService();

  List<Transaction> _transactions = [];
  List<Category> _categories = [];
  List<RecurringTransaction> _recurringTransactions = [];
  SavingsGoal? _savingsGoal;
  bool _isPro = false;
  bool _isDarkTheme = false;
  int _currentYear = DateTime.now().year;
  int _currentMonth = DateTime.now().month;
  bool _isLoading = false;

  // ─── GETTERS ──────────────────────────────────────────────────────────────

  List<Transaction> get transactions => _transactions;
  List<Category> get categories => _categories;
  List<RecurringTransaction> get recurringTransactions => _recurringTransactions;
  SavingsGoal? get savingsGoal => _savingsGoal;
  bool get isPro => _isPro;
  bool get isDarkTheme => _isDarkTheme;
  int get currentYear => _currentYear;
  int get currentMonth => _currentMonth;
  bool get isLoading => _isLoading;

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

  Category? getCategoryById(int id) {
    try {
      return _categories.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  // ─── INITIALISATION ───────────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    _isPro = await _prefs.isPro();
    _isDarkTheme = await _prefs.isDarkTheme();
    await loadCategories();
    await _recurring.processDueTransactions();
    await loadRecurringTransactions();
    await loadTransactions();
    await loadSavingsGoal();

    final restored = await AutoBackupService.instance.tryRestoreLatestIfEmpty();
    if (restored) {
      await loadCategories();
      await loadRecurringTransactions();
      await loadTransactions();
      await loadSavingsGoal();
    }

    await AutoBackupService.instance.runDailyBackupIfNeeded();

    _isLoading = false;
    notifyListeners();
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

  // ─── CHARGEMENT ───────────────────────────────────────────────────────────

  Future<void> loadTransactions() async {
    _transactions = await _db.getTransactions(
      year: _currentYear,
      month: _currentMonth,
      limitToThreeMonths: !_isPro,
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

  // ─── NAVIGATION MOIS ──────────────────────────────────────────────────────

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

  // ─── TRANSACTIONS ─────────────────────────────────────────────────────────

  Future<void> addTransaction(Transaction transaction) async {
    await _db.insertTransaction(transaction);
    await loadTransactions();
  }

  Future<void> updateTransaction(Transaction transaction) async {
    await _db.updateTransaction(transaction);
    await loadTransactions();
  }

  Future<void> deleteTransaction(int id) async {
    await _db.deleteTransaction(id);
    await loadTransactions();
  }

  Future<int> importTransactions(List<Transaction> transactions) async {
    await _db.insertTransactionsBatch(transactions);
    await loadTransactions();
    return transactions.length;
  }

  // ─── TRANSACTIONS RÉCURRENTES ─────────────────────────────────────────────

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

  // ─── OBJECTIFS D'ÉPARGNE ──────────────────────────────────────────────────

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

  // ─── CATÉGORIES ───────────────────────────────────────────────────────────

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

  // ─── STATUT PRO ──────────────────────────────────────────────────────────

  Future<void> setPro(bool value) async {
    _isPro = value;
    await _prefs.setPro(value);
    await loadTransactions();
    notifyListeners();
  }

  // ─── THÈME ───────────────────────────────────────────────────────────────

  Future<void> setDarkTheme(bool value) async {
    _isDarkTheme = value;
    await _prefs.setDarkTheme(value);
    notifyListeners();
  }

  // ─── STATISTIQUES ─────────────────────────────────────────────────────────

  Future<Map<int, double>> getExpensesByCategory() async {
    return _db.getExpensesByCategory(year: _currentYear, month: _currentMonth);
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals() async {
    return _db.getMonthlyTotals(months: 6);
  }
}
