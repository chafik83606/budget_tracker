class SavingsGoal {
  final int? id;
  final int year;
  final int month;
  final double targetAmount;

  const SavingsGoal({
    this.id,
    required this.year,
    required this.month,
    required this.targetAmount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'year': year,
      'month': month,
      'target_amount': targetAmount,
    };
  }

  factory SavingsGoal.fromMap(Map<String, dynamic> map) {
    return SavingsGoal(
      id: map['id'] as int?,
      year: map['year'] as int,
      month: map['month'] as int,
      targetAmount: (map['target_amount'] as num).toDouble(),
    );
  }

  SavingsGoal copyWith({
    int? id,
    int? year,
    int? month,
    double? targetAmount,
  }) {
    return SavingsGoal(
      id: id ?? this.id,
      year: year ?? this.year,
      month: month ?? this.month,
      targetAmount: targetAmount ?? this.targetAmount,
    );
  }
}
