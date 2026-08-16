import 'package:flutter/material.dart';

import '../core/utils/category_color.dart';

/// Data model for a transaction category.
class CategoryModel {
  final String id;
  final String name;
  final String type; // 'income' or 'expense'
  final String icon; // Material icon name
  final String color; // Hex color string (e.g. '#C87941')
  final bool isDefault;
  final bool isArchived;
  final String? parentId;
  final bool isSystem;
  final int sortOrder;
  final DateTime createdAt;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    required this.isDefault,
    this.isArchived = false,
    this.parentId,
    this.isSystem = false,
    required this.sortOrder,
    required this.createdAt,
  });

  bool get isIncome => type == 'income';
  bool get isExpense => type == 'expense';
  bool get isSubcategory => parentId != null;

  /// Parse the hex color string into a Flutter [Color].
  Color get colorValue => parseHexColor(color);

  /// Resolve the icon name to a Material [IconData].
  IconData get iconData {
    return _iconMap[icon] ?? Icons.category;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'isDefault': isDefault ? 1 : 0,
      'isArchived': isArchived ? 1 : 0,
      'parentId': parentId,
      'isSystem': isSystem ? 1 : 0,
      'sortOrder': sortOrder,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String,
      color: map['color'] as String,
      isDefault: (map['isDefault'] as int) == 1,
      // Nullable guards: rows written before these columns existed are
      // read back as null on some drivers rather than the DEFAULT.
      isArchived: (map['isArchived'] as int?) == 1,
      parentId: map['parentId'] as String?,
      isSystem: (map['isSystem'] as int?) == 1,
      sortOrder: map['sortOrder'] as int,
      createdAt: DateTime.parse(map['createdAt'] as String),
    );
  }

  CategoryModel copyWith({
    String? id,
    String? name,
    String? type,
    String? icon,
    String? color,
    bool? isDefault,
    bool? isArchived,
    String? parentId,
    bool clearParentId = false,
    bool? isSystem,
    int? sortOrder,
    DateTime? createdAt,
  }) {
    return CategoryModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isArchived: isArchived ?? this.isArchived,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      isSystem: isSystem ?? this.isSystem,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  /// Map of icon name strings to Material [IconData].
  /// Used for both default and custom categories.
  static const Map<String, IconData> _iconMap = {
    'restaurant': Icons.restaurant,
    'directions_car': Icons.directions_car,
    'shopping_bag': Icons.shopping_bag,
    'receipt_long': Icons.receipt_long,
    'movie': Icons.movie,
    'favorite': Icons.favorite,
    'school': Icons.school,
    'local_grocery_store': Icons.local_grocery_store,
    'more_horiz': Icons.more_horiz,
    'account_balance_wallet': Icons.account_balance_wallet,
    'laptop': Icons.laptop,
    'card_giftcard': Icons.card_giftcard,
    'trending_up': Icons.trending_up,
    'home': Icons.home,
    'flight': Icons.flight,
    'pets': Icons.pets,
    'fitness_center': Icons.fitness_center,
    'local_cafe': Icons.local_cafe,
    'build': Icons.build,
    'phone_android': Icons.phone_android,
    'wifi': Icons.wifi,
    'local_gas_station': Icons.local_gas_station,
    'child_care': Icons.child_care,
    'checkroom': Icons.checkroom,
    'sports_esports': Icons.sports_esports,
    'music_note': Icons.music_note,
    'local_bar': Icons.local_bar,
    'local_parking': Icons.local_parking,
    'savings': Icons.savings,
    'attach_money': Icons.attach_money,
    'work': Icons.work,
    'business': Icons.business,
    'volunteer_activism': Icons.volunteer_activism,
    'redeem': Icons.redeem,
    'category': Icons.category,
  };

  /// Get all available icon options (for the icon picker UI).
  static Map<String, IconData> get availableIcons => _iconMap;
}
