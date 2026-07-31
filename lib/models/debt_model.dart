/// Data model for a debt — money lent to someone else, or borrowed from
/// them. [principal] is fixed at creation; the outstanding balance is
/// always derived as `principal - sum(repayment transactions tagged with
/// this debt's id)` (see DebtRepository.getAllRepaid), so it can never
/// drift out of sync with the transaction history.
class DebtModel {
  final String id;
  final String name;
  final String type; // 'lent' | 'borrowed'
  final double principal;
  final DateTime? dueDate;
  final double? interestRate;
  final String? note;
  final bool isArchived;
  final DateTime createdAt;

  const DebtModel({
    required this.id,
    required this.name,
    required this.type,
    required this.principal,
    this.dueDate,
    this.interestRate,
    this.note,
    this.isArchived = false,
    required this.createdAt,
  });

  /// True when someone owes *you* money (you lent it out).
  bool get isLent => type == 'lent';

  /// True when *you* owe someone else money (you borrowed it).
  bool get isBorrowed => type == 'borrowed';

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'principal': principal,
      'dueDate': dueDate?.toIso8601String().substring(0, 10),
      'interestRate': interestRate,
      'note': note,
      'isArchived': isArchived ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      principal: (map['principal'] as num).toDouble(),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate'] as String) : null,
      interestRate: (map['interestRate'] as num?)?.toDouble(),
      note: map['note'] as String?,
      isArchived: (map['isArchived'] as int?) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  DebtModel copyWith({
    String? id,
    String? name,
    String? type,
    double? principal,
    DateTime? dueDate,
    bool? clearDueDate,
    double? interestRate,
    bool? clearInterestRate,
    String? note,
    bool? clearNote,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return DebtModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      principal: principal ?? this.principal,
      dueDate: clearDueDate == true ? null : (dueDate ?? this.dueDate),
      interestRate: clearInterestRate == true ? null : (interestRate ?? this.interestRate),
      note: clearNote == true ? null : (note ?? this.note),
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
