/// Data model for a financial transaction (income or expense).
class TransactionModel {
  final String id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String categoryId;
  final String accountId;
  final String? transferId;
  final bool isTransfer;
  final String? merchant;
  final DateTime date;
  final String? note;
  final String? recurringId;
  final String? goalId;
  final String? debtId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    required this.accountId,
    this.transferId,
    this.isTransfer = false,
    this.merchant,
    required this.date,
    this.note,
    this.recurringId,
    this.goalId,
    this.debtId,
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
      'accountId': accountId,
      'transferId': transferId,
      'isTransfer': isTransfer ? 1 : 0,
      'merchant': merchant,
      'date': date.toIso8601String().substring(0, 10),
      'note': note,
      'recurringId': recurringId,
      'goalId': goalId,
      'debtId': debtId,
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
      // Nullable guard: rows written before the accounts migration ran in
      // the same transaction are backfilled by the ALTER TABLE DEFAULT, but
      // defend anyway in case a caller queries mid-migration.
      accountId: map['accountId'] as String? ?? '',
      transferId: map['transferId'] as String?,
      isTransfer: (map['isTransfer'] as int?) == 1,
      merchant: map['merchant'] as String?,
      date: DateTime.parse(map['date'] as String),
      note: map['note'] as String?,
      recurringId: map['recurringId'] as String?,
      goalId: map['goalId'] as String?,
      debtId: map['debtId'] as String?,
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
    );
  }

  TransactionModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? categoryId,
    String? accountId,
    String? transferId,
    bool? isTransfer,
    String? merchant,
    DateTime? date,
    String? note,
    String? recurringId,
    String? goalId,
    String? debtId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return TransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      transferId: transferId ?? this.transferId,
      isTransfer: isTransfer ?? this.isTransfer,
      merchant: merchant ?? this.merchant,
      date: date ?? this.date,
      note: note ?? this.note,
      recurringId: recurringId ?? this.recurringId,
      goalId: goalId ?? this.goalId,
      debtId: debtId ?? this.debtId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
