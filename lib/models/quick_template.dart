import 'package:flutter/material.dart';

class QuickTemplate {
  final String label;
  final TransactionTypeHint type;
  final String categoryName;
  final double? defaultAmount;
  final String icon;
  final Color color;

  const QuickTemplate({
    required this.label,
    required this.type,
    required this.categoryName,
    this.defaultAmount,
    required this.icon,
    required this.color,
  });
}

enum TransactionTypeHint { expense, income }

const quickTemplates = [
  QuickTemplate(
    label: 'Courses',
    type: TransactionTypeHint.expense,
    categoryName: 'Alimentation',
    icon: '🛒',
    color: Colors.orange,
  ),
  QuickTemplate(
    label: 'Essence',
    type: TransactionTypeHint.expense,
    categoryName: 'Transport',
    icon: '⛽',
    color: Colors.blue,
  ),
  QuickTemplate(
    label: 'Restaurant',
    type: TransactionTypeHint.expense,
    categoryName: 'Loisirs',
    icon: '🍽️',
    color: Colors.purple,
  ),
];
