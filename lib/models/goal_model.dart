import 'package:flutter/material.dart';

import '../core/utils/category_color.dart';

/// Data model for a savings goal. [targetAmount] is the only amount stored
/// here — the amount saved so far is always derived from the sum of
/// transactions tagged with this goal's id (see GoalRepository.getAllProgress),
/// so it can never drift out of sync with the transaction history.
class GoalModel {
  final String id;
  final String name;
  final double targetAmount;
  final DateTime? targetDate;
  final String icon;
  final String color;
  final bool isArchived;
  final DateTime createdAt;

  const GoalModel({
    required this.id,
    required this.name,
    required this.targetAmount,
    this.targetDate,
    this.icon = 'savings',
    required this.color,
    this.isArchived = false,
    required this.createdAt,
  });

  /// Parse the hex color string into a Flutter [Color].
  Color get colorValue => parseHexColor(color);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'targetAmount': targetAmount,
      'targetDate': targetDate?.toIso8601String().substring(0, 10),
      'icon': icon,
      'color': color,
      'isArchived': isArchived ? 1 : 0,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GoalModel.fromMap(Map<String, dynamic> map) {
    return GoalModel(
      id: map['id'] as String,
      name: map['name'] as String,
      targetAmount: (map['targetAmount'] as num).toDouble(),
      targetDate: map['targetDate'] != null ? DateTime.parse(map['targetDate'] as String) : null,
      icon: map['icon'] as String? ?? 'savings',
      color: map['color'] as String,
      isArchived: (map['isArchived'] as int?) == 1,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  GoalModel copyWith({
    String? id,
    String? name,
    double? targetAmount,
    DateTime? targetDate,
    bool? clearTargetDate,
    String? icon,
    String? color,
    bool? isArchived,
    DateTime? createdAt,
  }) {
    return GoalModel(
      id: id ?? this.id,
      name: name ?? this.name,
      targetAmount: targetAmount ?? this.targetAmount,
      targetDate: clearTargetDate == true ? null : (targetDate ?? this.targetDate),
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
