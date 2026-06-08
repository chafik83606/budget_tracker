import 'transaction.dart';

class RecurringTransaction {
  final int? id;
  final String label;
  final double amount;
  final int categoryId;
  final TransactionType type;
  final int dayOfMonth;
  final String? note;
  final bool isActive;
  final int startYear;
  final int startMonth;
  final int? lastGeneratedYear;
  final int? lastGeneratedMonth;

  const RecurringTransaction({
    this.id,
    required this.label,
    required this.amount,
    required this.categoryId,
    required this.type,
    this.dayOfMonth = 1,
    this.note,
    this.isActive = true,
    required this.startYear,
    required this.startMonth,
    this.lastGeneratedYear,
    this.lastGeneratedMonth,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'amount': amount,
      'category_id': categoryId,
      'type': type.name,
      'day_of_month': dayOfMonth,
      'note': note,
      'is_active': isActive ? 1 : 0,
      'start_year': startYear,
      'start_month': startMonth,
      'last_generated_year': lastGeneratedYear,
      'last_generated_month': lastGeneratedMonth,
    };
  }

  factory RecurringTransaction.fromMap(Map<String, dynamic> map) {
    return RecurringTransaction(
      id: map['id'] as int?,
      label: map['label'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['category_id'] as int,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      dayOfMonth: map['day_of_month'] as int? ?? 1,
      note: map['note'] as String?,
      isActive: (map['is_active'] as int? ?? 1) == 1,
      startYear: map['start_year'] as int,
      startMonth: map['start_month'] as int,
      lastGeneratedYear: map['last_generated_year'] as int?,
      lastGeneratedMonth: map['last_generated_month'] as int?,
    );
  }

  RecurringTransaction copyWith({
    int? id,
    String? label,
    double? amount,
    int? categoryId,
    TransactionType? type,
    int? dayOfMonth,
    String? note,
    bool? isActive,
    int? startYear,
    int? startMonth,
    int? lastGeneratedYear,
    int? lastGeneratedMonth,
  }) {
    return RecurringTransaction(
      id: id ?? this.id,
      label: label ?? this.label,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      dayOfMonth: dayOfMonth ?? this.dayOfMonth,
      note: note ?? this.note,
      isActive: isActive ?? this.isActive,
      startYear: startYear ?? this.startYear,
      startMonth: startMonth ?? this.startMonth,
      lastGeneratedYear: lastGeneratedYear ?? this.lastGeneratedYear,
      lastGeneratedMonth: lastGeneratedMonth ?? this.lastGeneratedMonth,
    );
  }
}
