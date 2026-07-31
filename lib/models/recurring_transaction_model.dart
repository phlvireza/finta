/// Data model for a recurring transaction template.
class RecurringTransactionModel {
  final String id;
  final String type; // 'income' or 'expense'
  final double amount;
  final String categoryId;
  final String? accountId;
  final String? merchant;
  final String? note;
  final String frequency; // 'daily', 'weekly', 'biweekly', 'monthly', 'yearly'
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime? lastRunDate;
  final bool isActive;
  final bool isSubscription;
  final bool isPaused;
  final int? reminderDaysBefore;
  final DateTime createdAt;

  const RecurringTransactionModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.categoryId,
    this.accountId,
    this.merchant,
    this.note,
    required this.frequency,
    required this.startDate,
    this.endDate,
    this.lastRunDate,
    required this.isActive,
    this.isSubscription = false,
    this.isPaused = false,
    this.reminderDaysBefore,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';

  /// Human-readable frequency label.
  String get frequencyLabel {
    switch (frequency) {
      case 'daily':
        return 'Daily';
      case 'weekly':
        return 'Weekly';
      case 'biweekly':
        return 'Every 2 weeks';
      case 'monthly':
        return 'Monthly';
      case 'yearly':
        return 'Yearly';
      default:
        return frequency;
    }
  }

  /// The next date a transaction should be generated for. The first
  /// occurrence is always [startDate] itself; later ones advance from
  /// [lastRunDate] by one period.
  DateTime get nextOccurrence =>
      lastRunDate == null ? startDate : advanceFrom(lastRunDate!);

  /// Advances [from] by one period. Monthly/yearly keep the template's
  /// original day-of-month (clamped to the target month's length) so a
  /// template anchored on the 31st doesn't permanently drift to the
  /// 1st/2nd/3rd after passing through a shorter month.
  DateTime advanceFrom(DateTime from) {
    switch (frequency) {
      case 'daily':
        return from.add(const Duration(days: 1));
      case 'weekly':
        return from.add(const Duration(days: 7));
      case 'biweekly':
        return from.add(const Duration(days: 14));
      case 'monthly':
        return _addMonthsAnchored(from, 1);
      case 'yearly':
        return _addMonthsAnchored(from, 12);
      default:
        return from.add(const Duration(days: 1));
    }
  }

  DateTime _addMonthsAnchored(DateTime from, int months) {
    final targetMonth = from.month + months;
    // The "day 0 of the following month" trick yields the target month's
    // last day; it works even when targetMonth overflows past 12 because
    // DateTime normalizes the year/month pair as a whole.
    final lastDayOfTargetMonth = DateTime(from.year, targetMonth + 1, 0).day;
    return DateTime(
      from.year,
      targetMonth,
      startDate.day.clamp(1, lastDayOfTargetMonth),
    );
  }

  /// Roughly how many days a single period of [frequency] spans — used to
  /// normalize a subscription's cost onto a common monthly/yearly basis.
  double get approxDaysPerPeriod {
    switch (frequency) {
      case 'daily':
        return 1;
      case 'weekly':
        return 7;
      case 'biweekly':
        return 14;
      case 'monthly':
        return 30.44;
      case 'yearly':
        return 365.25;
      default:
        return 30.44;
    }
  }

  /// This template's cost normalized to an average-per-month figure —
  /// e.g. a yearly $120 subscription is $10/month here — so subscriptions
  /// on different billing cycles can be summed and compared meaningfully.
  double get monthlyEquivalent => amount * 30.44 / approxDaysPerPeriod;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type,
      'amount': amount,
      'categoryId': categoryId,
      'accountId': accountId,
      'merchant': merchant,
      'note': note,
      'frequency': frequency,
      'startDate': startDate.toIso8601String().substring(0, 10),
      'endDate': endDate?.toIso8601String().substring(0, 10),
      'lastRunDate': lastRunDate?.toIso8601String().substring(0, 10),
      'isActive': isActive ? 1 : 0,
      'isSubscription': isSubscription ? 1 : 0,
      'isPaused': isPaused ? 1 : 0,
      'reminderDaysBefore': reminderDaysBefore,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory RecurringTransactionModel.fromMap(Map<String, dynamic> map) {
    return RecurringTransactionModel(
      id: map['id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      accountId: map['accountId'] as String?,
      merchant: map['merchant'] as String?,
      note: map['note'] as String?,
      frequency: map['frequency'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : null,
      lastRunDate: map['lastRunDate'] != null
          ? DateTime.parse(map['lastRunDate'] as String)
          : null,
      isActive: (map['isActive'] as int) == 1,
      isSubscription: (map['isSubscription'] as int?) == 1,
      isPaused: (map['isPaused'] as int?) == 1,
      reminderDaysBefore: map['reminderDaysBefore'] as int?,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  RecurringTransactionModel copyWith({
    String? id,
    String? type,
    double? amount,
    String? categoryId,
    String? accountId,
    String? merchant,
    String? note,
    String? frequency,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? lastRunDate,
    bool? isActive,
    bool? isSubscription,
    bool? isPaused,
    int? reminderDaysBefore,
    bool clearReminder = false,
    DateTime? createdAt,
  }) {
    return RecurringTransactionModel(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      categoryId: categoryId ?? this.categoryId,
      accountId: accountId ?? this.accountId,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      lastRunDate: lastRunDate ?? this.lastRunDate,
      isActive: isActive ?? this.isActive,
      isSubscription: isSubscription ?? this.isSubscription,
      isPaused: isPaused ?? this.isPaused,
      reminderDaysBefore:
          clearReminder ? null : (reminderDaysBefore ?? this.reminderDaysBefore),
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
