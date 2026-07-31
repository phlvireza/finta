/// Data model for a category budget (monthly spending limit).
class BudgetModel {
  final String id;
  final String categoryId;
  final double amount; // Monthly limit
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetModel({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'categoryId': categoryId,
      'amount': amount,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map) {
    return BudgetModel(
      id: map['id'] as String,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      isActive: (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  BudgetModel copyWith({
    String? id,
    String? categoryId,
    double? amount,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
