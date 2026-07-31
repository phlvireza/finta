/// A saved one-tap entry ("favorite") — tapping it in the quick-add sheet
/// materializes a normal transaction dated whenever it's used, not when it
/// was saved.
class TemplateModel {
  final String id;
  final String name;
  final String type; // 'income' or 'expense'
  final double amount;
  final String categoryId;
  final String accountId;
  final String? merchant;
  final String? note;
  final int sortOrder;
  final DateTime createdAt;

  const TemplateModel({
    required this.id,
    required this.name,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.merchant,
    this.note,
    required this.sortOrder,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'merchant': merchant,
      'note': note,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory TemplateModel.fromMap(Map<String, dynamic> map) {
    return TemplateModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      accountId: map['accountId'] as String,
      merchant: map['merchant'] as String?,
      note: map['note'] as String?,
      sortOrder: map['sortOrder'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }
}
