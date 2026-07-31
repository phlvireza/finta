import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Seeds the database with default categories on first launch.
class SeedData {
  SeedData._();
  static const _uuid = Uuid();

  static Future<void> seedCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();

    // ── Default Expense Categories ────────────────────────────
    final expenseCategories = [
      {'name': 'Food & Drinks', 'icon': 'restaurant', 'color': '#C87941'},
      {'name': 'Transport', 'icon': 'directions_car', 'color': '#6F8B8A'},
      {'name': 'Shopping', 'icon': 'shopping_bag', 'color': '#C2665A'},
      {'name': 'Bills & Utilities', 'icon': 'receipt_long', 'color': '#D4A05A'},
      {'name': 'Entertainment', 'icon': 'movie', 'color': '#8B6F7A'},
      {'name': 'Health', 'icon': 'favorite', 'color': '#5B8C5A'},
      {'name': 'Education', 'icon': 'school', 'color': '#7A8B6F'},
      {'name': 'Groceries', 'icon': 'local_grocery_store', 'color': '#B07A5B'},
      {'name': 'Other', 'icon': 'more_horiz', 'color': '#8A7E74'},
    ];

    for (var i = 0; i < expenseCategories.length; i++) {
      final cat = expenseCategories[i];
      batch.insert('categories', {
        'id': _uuid.v4(),
        'name': cat['name'],
        'type': 'expense',
        'icon': cat['icon'],
        'color': cat['color'],
        'isDefault': 1,
        'sortOrder': i,
        'createdAt': now,
      });
    }

    // ── Default Income Categories ─────────────────────────────
    final incomeCategories = [
      {'name': 'Salary', 'icon': 'account_balance_wallet', 'color': '#5B8C5A'},
      {'name': 'Freelance', 'icon': 'laptop', 'color': '#C87941'},
      {'name': 'Gift', 'icon': 'card_giftcard', 'color': '#D4A05A'},
      {'name': 'Investment', 'icon': 'trending_up', 'color': '#7A8B6F'},
      {'name': 'Other', 'icon': 'more_horiz', 'color': '#8A7E74'},
    ];

    for (var i = 0; i < incomeCategories.length; i++) {
      final cat = incomeCategories[i];
      batch.insert('categories', {
        'id': _uuid.v4(),
        'name': cat['name'],
        'type': 'income',
        'icon': cat['icon'],
        'color': cat['color'],
        'isDefault': 1,
        'sortOrder': i,
        'createdAt': now,
      });
    }

    await batch.commit(noResult: true);
  }
}
