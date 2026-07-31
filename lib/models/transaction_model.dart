/// Data model for a financial transaction (income or expense).
class TransactionModel {
  final String id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String categoryId;
  final DateTime date;
  final String? note;
  final String? recurringId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.date,
    this.note,
    this.recurringId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isRecurring => recurringId != null;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'date': date.toIso8601String().substring(0, 10),
      'note': note,
      'recurringId': recurringId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      recurringId: map['recurringId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? categoryId,
    DateTime? date,
    String? note,
    String? recurringId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      date: date ?? this.date,
      note: note ?? this.note,
      recurringId: recurringId ?? this.recurringId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
