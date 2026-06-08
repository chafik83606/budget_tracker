import '../models/transaction.dart';
import 'database_service.dart';

class RecurringService {
  static final RecurringService _instance = RecurringService._internal();
  factory RecurringService() => _instance;
  RecurringService._internal();

  final DatabaseService _db = DatabaseService();

  /// Génère les transactions manquantes pour tous les modèles récurrents actifs.
  Future<int> processDueTransactions() async {
    final now = DateTime.now();
    final recurringList = await _db.getRecurringTransactions();
    int created = 0;

    for (final recurring in recurringList) {
      if (!recurring.isActive || recurring.id == null) continue;

      var year = recurring.lastGeneratedYear ?? recurring.startYear;
      var month = recurring.lastGeneratedMonth ?? recurring.startMonth;

      if (recurring.lastGeneratedYear == null) {
        // Première génération : commencer au mois de départ
        year = recurring.startYear;
        month = recurring.startMonth;
      } else {
        // Passer au mois suivant le dernier généré
        if (month == 12) {
          year++;
          month = 1;
        } else {
          month++;
        }
      }

      while (_isBeforeOrEqual(year, month, now.year, now.month)) {
        final exists = await _db.hasRecurringTransactionForMonth(
          recurring.id!,
          year,
          month,
        );

        if (!exists) {
          final day = _clampDay(recurring.dayOfMonth, year, month);
          await _db.insertTransaction(
            Transaction(
              amount: recurring.amount,
              label: recurring.label,
              categoryId: recurring.categoryId,
              type: recurring.type,
              date: DateTime(year, month, day),
              note: recurring.note,
              recurringId: recurring.id,
            ),
          );
          created++;
        }

        await _db.updateRecurringTransaction(
          recurring.copyWith(
            lastGeneratedYear: year,
            lastGeneratedMonth: month,
          ),
        );

        if (month == 12) {
          year++;
          month = 1;
        } else {
          month++;
        }
      }
    }

    return created;
  }

  bool _isBeforeOrEqual(int y1, int m1, int y2, int m2) {
    if (y1 < y2) return true;
    if (y1 > y2) return false;
    return m1 <= m2;
  }

  int _clampDay(int day, int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    return day.clamp(1, lastDay);
  }
}
