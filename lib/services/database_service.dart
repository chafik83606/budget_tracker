import 'package:sqflite/sqflite.dart' hide Transaction;
import 'package:path/path.dart';
import '../models/transaction.dart';
import '../models/category.dart';
import '../models/recurring_transaction.dart';
import '../models/savings_goal.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _db;
  static const int _dbVersion = 2;

  Future<Database> get database async {
    _db ??= await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'budget_tracker.db');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createCoreTables(db);
    await _createV2Tables(db);

    for (final cat in defaultCategories) {
      await db.insert('categories', cat.toMap()..remove('id'));
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE transactions ADD COLUMN recurring_id INTEGER',
      );
      await _createV2Tables(db);
    }
  }

  Future<void> _createCoreTables(Database db) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color INTEGER NOT NULL,
        is_default INTEGER NOT NULL DEFAULT 0,
        monthly_budget REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        amount REAL NOT NULL,
        label TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        recurring_id INTEGER,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');
  }

  Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        label TEXT NOT NULL,
        amount REAL NOT NULL,
        category_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        day_of_month INTEGER NOT NULL DEFAULT 1,
        note TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        start_year INTEGER NOT NULL,
        start_month INTEGER NOT NULL,
        last_generated_year INTEGER,
        last_generated_month INTEGER,
        FOREIGN KEY (category_id) REFERENCES categories (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS savings_goals (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        year INTEGER NOT NULL,
        month INTEGER NOT NULL,
        target_amount REAL NOT NULL,
        UNIQUE(year, month)
      )
    ''');
  }

  // ─── CATEGORIES ──────────────────────────────────────────────────────────

  Future<List<Category>> getCategories() async {
    final db = await database;
    final maps = await db.query('categories', orderBy: 'name ASC');
    return maps.map((m) => Category.fromMap(m)).toList();
  }

  Future<Category?> getCategoryById(int id) async {
    final db = await database;
    final maps = await db.query('categories', where: 'id = ?', whereArgs: [id]);
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<Category?> getCategoryByName(String name) async {
    final db = await database;
    final maps = await db.query(
      'categories',
      where: 'LOWER(name) = ?',
      whereArgs: [name.toLowerCase()],
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<int> insertCategory(Category category) async {
    final db = await database;
    final map = category.toMap()..remove('id');
    return db.insert('categories', map);
  }

  Future<void> updateCategory(Category category) async {
    final db = await database;
    await db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  Future<void> deleteCategory(int id) async {
    final db = await database;
    await db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  // ─── TRANSACTIONS ─────────────────────────────────────────────────────────

  Future<List<Transaction>> getTransactions({
    int? year,
    int? month,
    bool limitToThreeMonths = false,
  }) async {
    final db = await database;
    String? where;
    List<dynamic>? whereArgs;

    if (year != null && month != null) {
      final start = DateTime(year, month, 1).toIso8601String();
      final end = DateTime(year, month + 1, 1).toIso8601String();
      where = 'date >= ? AND date < ?';
      whereArgs = [start, end];
    } else if (limitToThreeMonths) {
      final limit = DateTime.now().subtract(const Duration(days: 92));
      where = 'date >= ?';
      whereArgs = [limit.toIso8601String()];
    }

    final maps = await db.query(
      'transactions',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<List<Transaction>> getAllTransactions() async {
    final db = await database;
    final maps = await db.query('transactions', orderBy: 'date DESC');
    return maps.map((m) => Transaction.fromMap(m)).toList();
  }

  Future<bool> hasRecurringTransactionForMonth(
    int recurringId,
    int year,
    int month,
  ) async {
    final db = await database;
    final start = DateTime(year, month, 1).toIso8601String();
    final end = DateTime(year, month + 1, 1).toIso8601String();
    final maps = await db.query(
      'transactions',
      where: 'recurring_id = ? AND date >= ? AND date < ?',
      whereArgs: [recurringId, start, end],
      limit: 1,
    );
    return maps.isNotEmpty;
  }

  Future<int> insertTransaction(Transaction transaction) async {
    final db = await database;
    final map = transaction.toMap()..remove('id');
    return db.insert('transactions', map);
  }

  Future<void> insertTransactionsBatch(List<Transaction> transactions) async {
    final db = await database;
    final batch = db.batch();
    for (final t in transactions) {
      batch.insert('transactions', t.toMap()..remove('id'));
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateTransaction(Transaction transaction) async {
    final db = await database;
    await db.update(
      'transactions',
      transaction.toMap(),
      where: 'id = ?',
      whereArgs: [transaction.id],
    );
  }

  Future<void> deleteTransaction(int id) async {
    final db = await database;
    await db.delete('transactions', where: 'id = ?', whereArgs: [id]);
  }

  // ─── TRANSACTIONS RÉCURRENTES ─────────────────────────────────────────────

  Future<List<RecurringTransaction>> getRecurringTransactions() async {
    final db = await database;
    final maps = await db.query(
      'recurring_transactions',
      orderBy: 'label ASC',
    );
    return maps.map((m) => RecurringTransaction.fromMap(m)).toList();
  }

  Future<int> insertRecurringTransaction(RecurringTransaction recurring) async {
    final db = await database;
    final map = recurring.toMap()..remove('id');
    return db.insert('recurring_transactions', map);
  }

  Future<void> updateRecurringTransaction(RecurringTransaction recurring) async {
    final db = await database;
    await db.update(
      'recurring_transactions',
      recurring.toMap(),
      where: 'id = ?',
      whereArgs: [recurring.id],
    );
  }

  Future<void> deleteRecurringTransaction(int id) async {
    final db = await database;
    await db.delete(
      'recurring_transactions',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ─── OBJECTIFS D'ÉPARGNE ──────────────────────────────────────────────────

  Future<SavingsGoal?> getSavingsGoal(int year, int month) async {
    final db = await database;
    final maps = await db.query(
      'savings_goals',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
    if (maps.isEmpty) return null;
    return SavingsGoal.fromMap(maps.first);
  }

  Future<void> upsertSavingsGoal(SavingsGoal goal) async {
    final db = await database;
    await db.insert(
      'savings_goals',
      goal.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteSavingsGoal(int year, int month) async {
    final db = await database;
    await db.delete(
      'savings_goals',
      where: 'year = ? AND month = ?',
      whereArgs: [year, month],
    );
  }

  Future<double> getMonthBalance(int year, int month) async {
    final transactions = await getTransactions(year: year, month: month);
    double incomes = 0;
    double expenses = 0;
    for (final t in transactions) {
      if (t.type == TransactionType.income) {
        incomes += t.amount;
      } else {
        expenses += t.amount;
      }
    }
    return incomes - expenses;
  }

  // ─── STATISTIQUES ─────────────────────────────────────────────────────────

  Future<Map<int, double>> getExpensesByCategory({
    required int year,
    required int month,
  }) async {
    final transactions = await getTransactions(year: year, month: month);
    final Map<int, double> result = {};
    for (final t in transactions) {
      if (t.type == TransactionType.expense) {
        result[t.categoryId] = (result[t.categoryId] ?? 0) + t.amount;
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> getMonthlyTotals({int months = 6}) async {
    final db = await database;
    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    for (int i = months - 1; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final start = date.toIso8601String();
      final end = DateTime(date.year, date.month + 1, 1).toIso8601String();

      final rows = await db.rawQuery(
        '''
        SELECT type, SUM(amount) as total
        FROM transactions
        WHERE date >= ? AND date < ?
        GROUP BY type
      ''',
        [start, end],
      );

      double expenses = 0;
      double incomes = 0;
      for (final row in rows) {
        if (row['type'] == 'expense') {
          expenses = (row['total'] as num).toDouble();
        }
        if (row['type'] == 'income') {
          incomes = (row['total'] as num).toDouble();
        }
      }

      result.add({
        'year': date.year,
        'month': date.month,
        'expenses': expenses,
        'incomes': incomes,
      });
    }
    return result;
  }

  // ─── SAUVEGARDE / RESTAURATION ────────────────────────────────────────────

  Future<Map<String, dynamic>> exportAllData() async {
    final db = await database;
    return {
      'categories': await db.query('categories'),
      'transactions': await db.query('transactions'),
      'recurring_transactions': await db.query('recurring_transactions'),
      'savings_goals': await db.query('savings_goals'),
      'exported_at': DateTime.now().toIso8601String(),
      'version': _dbVersion,
    };
  }

  Future<void> importAllData(Map<String, dynamic> data) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('transactions');
      await txn.delete('recurring_transactions');
      await txn.delete('savings_goals');
      await txn.delete('categories');

      for (final cat in (data['categories'] as List)) {
        await txn.insert('categories', Map<String, dynamic>.from(cat as Map));
      }
      for (final tr in (data['transactions'] as List)) {
        await txn.insert('transactions', Map<String, dynamic>.from(tr as Map));
      }
      if (data['recurring_transactions'] != null) {
        for (final r in (data['recurring_transactions'] as List)) {
          await txn.insert(
            'recurring_transactions',
            Map<String, dynamic>.from(r as Map),
          );
        }
      }
      if (data['savings_goals'] != null) {
        for (final g in (data['savings_goals'] as List)) {
          await txn.insert(
            'savings_goals',
            Map<String, dynamic>.from(g as Map),
          );
        }
      }
    });
  }
}
