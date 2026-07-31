/// Data model for a budget — a spending limit over some period, scoped to
/// a single category, a group of categories, or every expense category.
///
/// [categoryIds] isn't a column on `budgets` — it's loaded from the
/// `budget_categories` join table by the repository and attached here so
/// callers get a single self-contained object. [toMap] therefore excludes
/// it; the repository writes it to the join table separately.
class BudgetModel {
  final String id;
  final String? name; // user label — mainly for group/overall budgets
  final double amount;
  final String period; // weekly|monthly|quarterly|yearly
  final String rolloverMode; // none|positive|full
  final String scope; // category|group|overall
  final List<String> categoryIds; // empty for scope == 'overall'
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BudgetModel({
    required this.id,
    this.name,
    required this.amount,
    this.period = 'monthly',
    this.rolloverMode = 'none',
    this.scope = 'category',
    this.categoryIds = const [],
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasRollover => rolloverMode != 'none';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'amount': amount,
      'period': period,
      'rolloverMode': rolloverMode,
      'scope': scope,
      'isActive': isActive ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory BudgetModel.fromMap(Map<String, dynamic> map, {List<String> categoryIds = const []}) {
    return BudgetModel(
      id: map['id'] as String,
      name: map['name'] as String?,
      amount: (map['amount'] as num).toDouble(),
      period: (map['period'] as String?) ?? 'monthly',
      rolloverMode: (map['rolloverMode'] as String?) ?? 'none',
      scope: (map['scope'] as String?) ?? 'category',
      categoryIds: categoryIds,
      isActive: (map['isActive'] as int) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  BudgetModel copyWith({
    String? id,
    String? name,
    bool clearName = false,
    double? amount,
    String? period,
    String? rolloverMode,
    String? scope,
    List<String>? categoryIds,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BudgetModel(
      id: id ?? this.id,
      name: clearName ? null : (name ?? this.name),
      amount: amount ?? this.amount,
      period: period ?? this.period,
      rolloverMode: rolloverMode ?? this.rolloverMode,
      scope: scope ?? this.scope,
      categoryIds: categoryIds ?? this.categoryIds,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
