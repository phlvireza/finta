import 'package:flutter/material.dart';

/// Data model for a financial account (wallet, bank, card, ...).
class AccountModel {
  final String id;
  final String name;
  final String type; // cash|bank|credit_card|e_wallet|savings|investment
  final double openingBalance;
  final String color; // Hex color string (e.g. '#C87941')
  final double? creditLimit; // credit_card accounts only
  final bool isArchived;
  final bool includeInTotal;
  final int sortOrder;
  final DateTime createdAt;

  const AccountModel({
    required this.id,
    required this.name,
    required this.type,
    required this.openingBalance,
    required this.color,
    this.creditLimit,
    this.isArchived = false,
    this.includeInTotal = true,
    required this.sortOrder,
    required this.createdAt,
  });

  bool get isCreditCard => type == 'credit_card';

  /// Parse the hex color string into a Flutter [Color].
  Color get colorValue {
    final hex = color.replaceAll('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  IconData get iconData => iconForType(type);

  static IconData iconForType(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance;
      case 'credit_card':
        return Icons.credit_card;
      case 'e_wallet':
        return Icons.smartphone;
      case 'savings':
        return Icons.savings;
      case 'investment':
        return Icons.trending_up;
      case 'cash':
      default:
        return Icons.account_balance_wallet;
    }
  }

  static const List<String> types = [
    'cash',
    'bank',
    'credit_card',
    'e_wallet',
    'savings',
    'investment',
  ];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'openingBalance': openingBalance,
      'color': color,
      'creditLimit': creditLimit,
      'isArchived': isArchived ? 1 : 0,
      'includeInTotal': includeInTotal ? 1 : 0,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      openingBalance: (map['openingBalance'] as num).toDouble(),
      color: map['color'] as String,
      creditLimit: (map['creditLimit'] as num?)?.toDouble(),
      isArchived: (map['isArchived'] as int?) == 1,
      includeInTotal: (map['includeInTotal'] as int?) != 0,
      sortOrder: map['sortOrder'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  AccountModel copyWith({
    String? id,
    String? name,
    String? type,
    double? openingBalance,
    String? color,
    double? creditLimit,
    bool? clearCreditLimit,
    bool? isArchived,
    bool? includeInTotal,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return AccountModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalance: openingBalance ?? this.openingBalance,
      color: color ?? this.color,
      creditLimit:
          clearCreditLimit == true ? null : (creditLimit ?? this.creditLimit),
      isArchived: isArchived ?? this.isArchived,
      includeInTotal: includeInTotal ?? this.includeInTotal,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
