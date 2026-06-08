import 'package:flutter/material.dart';

class Category {
  final int? id;
  final String name;
  final String icon;
  final Color color;
  final bool isDefault;
  final double? monthlyBudget; // Pro uniquement

  const Category({
    this.id,
    required this.name,
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.monthlyBudget,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'icon': icon,
      'color': color.toARGB32(),
      'is_default': isDefault ? 1 : 0,
      'monthly_budget': monthlyBudget,
    };
  }

  factory Category.fromMap(Map<String, dynamic> map) {
    return Category(
      id: map['id'] as int?,
      name: map['name'] as String,
      icon: map['icon'] as String,
      color: Color(map['color'] as int),
      isDefault: (map['is_default'] as int) == 1,
      monthlyBudget: map['monthly_budget'] as double?,
    );
  }

  Category copyWith({
    int? id,
    String? name,
    String? icon,
    Color? color,
    bool? isDefault,
    double? monthlyBudget,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    );
  }
}

// Catégories par défaut
final List<Category> defaultCategories = [
  Category(
    id: 1,
    name: 'Alimentation',
    icon: '🛒',
    color: Colors.orange,
    isDefault: true,
  ),
  Category(
    id: 2,
    name: 'Transport',
    icon: '🚗',
    color: Colors.blue,
    isDefault: true,
  ),
  Category(
    id: 3,
    name: 'Logement',
    icon: '🏠',
    color: Colors.brown,
    isDefault: true,
  ),
  Category(
    id: 4,
    name: 'Loisirs',
    icon: '🎮',
    color: Colors.purple,
    isDefault: true,
  ),
  Category(
    id: 5,
    name: 'Santé',
    icon: '💊',
    color: Colors.red,
    isDefault: true,
  ),
  Category(
    id: 6,
    name: 'Autre',
    icon: '📦',
    color: Colors.grey,
    isDefault: true,
  ),
];
