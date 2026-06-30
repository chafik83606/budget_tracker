enum TransactionType { expense, income }

class Transaction {
  final int? id;
  final double amount;
  final String label;
  final int categoryId;
  final TransactionType type;
  final DateTime date;
  final String? note;
  final int? recurringId;
  final String? tags;
  final int accountId;

  const Transaction({
    this.id,
    required this.amount,
    required this.label,
    required this.categoryId,
    required this.type,
    required this.date,
    this.note,
    this.recurringId,
    this.tags,
    this.accountId = 1,
  });

  List<String> get tagList {
    if (tags == null || tags!.trim().isEmpty) return [];
    return tags!.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'label': label,
      'category_id': categoryId,
      'type': type.name,
      'date': date.toIso8601String(),
      'note': note,
      'recurring_id': recurringId,
      'tags': tags,
      'account_id': accountId,
    };
  }

  factory Transaction.fromMap(Map<String, dynamic> map) {
    return Transaction(
      id: map['id'] as int?,
      amount: (map['amount'] as num).toDouble(),
      label: map['label'] as String,
      categoryId: map['category_id'] as int,
      type: TransactionType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => TransactionType.expense,
      ),
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      recurringId: map['recurring_id'] as int?,
      tags: map['tags'] as String?,
      accountId: map['account_id'] as int? ?? 1,
    );
  }

  Transaction copyWith({
    int? id,
    double? amount,
    String? label,
    int? categoryId,
    TransactionType? type,
    DateTime? date,
    String? note,
    int? recurringId,
    String? tags,
    int? accountId,
  }) {
    return Transaction(
      id: id ?? this.id,
      amount: amount ?? this.amount,
      label: label ?? this.label,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      date: date ?? this.date,
      note: note ?? this.note,
      recurringId: recurringId ?? this.recurringId,
      tags: tags ?? this.tags,
      accountId: accountId ?? this.accountId,
    );
  }
}
