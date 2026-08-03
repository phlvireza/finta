import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

/// Seeds the database with default categories, the default account, and
/// system-owned rows on first launch (and backfills the same system rows
/// during the v3 upgrade for existing installs).
class SeedData {
  SeedData._();
  static const _uuid = Uuid();

  /// Well-known id for the account every pre-v3 transaction is backfilled
  /// into, and the default account offered to brand-new installs. Kept as
  /// a fixed constant (rather than a fresh uuid) so [RecurringService] can
  /// fall back to it without a DB round trip.
  static const String defaultAccountId = 'account_default';

  /// Well-known id for the system "Transfer" category used by both legs of
  /// every transfer. It's marked `isSystem` so it never appears in a
  /// user-facing category picker.
  static const String transferCategoryId = 'system_transfer';

  /// Well-known ids for the default categories a goal contribution or debt
  /// repayment is filed under (see [seedGoalDebtCategories]) — fixed
  /// constants so [GoalProvider]/[DebtProvider] can reference them without
  /// a lookup-by-name.
  static const String savingsGoalsCategoryId = 'default_savings_goals';
  static const String debtPaymentsCategoryId = 'default_debt_payments';
  static const String debtRepaymentsCategoryId = 'default_debt_repayments';

  /// Well-known id for the "Donation" category added in v8. Fixed (rather
  /// than a fresh uuid like the original seed list) so a fresh install and
  /// an upgraded one end up with the same row, and so replaying the
  /// migration can't create a second copy.
  static const String donationCategoryId = 'default_donation';

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

  /// Seeds the system "Transfer" category. Its `type` is arbitrary (never
  /// shown in a type-filtered picker since `isSystem` rows are excluded by
  /// [CategoryProvider]).
  static Future<void> seedSystemCategory(DatabaseExecutor db) async {
    await db.insert('categories', {
      'id': transferCategoryId,
      'name': 'Transfer',
      'type': 'expense',
      'icon': 'account_balance_wallet',
      'color': '#8A7E74',
      'isDefault': 1,
      'isArchived': 0,
      'isSystem': 1,
      'sortOrder': -1,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  /// Seeds the default categories a goal contribution or debt repayment
  /// transaction is filed under. Ordinary (non-system) categories — unlike
  /// the Transfer category, there's real value in seeing "Savings & Goals"
  /// or "Debt Payments" show up in a normal category breakdown.
  static Future<void> seedGoalDebtCategories(DatabaseExecutor db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();
    batch.insert('categories', {
      'id': savingsGoalsCategoryId,
      'name': 'Savings & Goals',
      'type': 'expense',
      'icon': 'savings',
      'color': '#5B8C5A',
      'isDefault': 1,
      'sortOrder': 100,
      'createdAt': now,
    });
    batch.insert('categories', {
      'id': debtPaymentsCategoryId,
      'name': 'Debt Payments',
      'type': 'expense',
      'icon': 'attach_money',
      'color': '#C2665A',
      'isDefault': 1,
      'sortOrder': 101,
      'createdAt': now,
    });
    batch.insert('categories', {
      'id': debtRepaymentsCategoryId,
      'name': 'Debt Repayments',
      'type': 'income',
      'icon': 'redeem',
      'color': '#5B8C5A',
      'isDefault': 1,
      'sortOrder': 100,
      'createdAt': now,
    });
    await batch.commit(noResult: true);
  }

  /// Seeds the "Donation" expense category. Shipped after the original
  /// default set, so it is seeded separately (by [Migrations.v8] for
  /// existing installs and alongside the other seeds for new ones) rather
  /// than being appended to [seedCategories] — which only ever runs on a
  /// fresh database.
  ///
  /// `sortOrder` 9 puts it directly after "Other" (8) and ahead of the
  /// goal/debt categories at 100+. Inserted with `ignore` so replaying the
  /// migration is a no-op instead of a primary-key failure.
  static Future<void> seedDonationCategory(DatabaseExecutor db) async {
    await db.insert(
      'categories',
      {
        'id': donationCategoryId,
        'name': 'Donation',
        'type': 'expense',
        'icon': 'volunteer_activism',
        'color': '#7A8B6F',
        'isDefault': 1,
        'isArchived': 0,
        'isSystem': 0,
        'sortOrder': 9,
        'createdAt': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Seeds the default "My Wallet" cash account every pre-accounts
  /// transaction is backfilled into.
  static Future<void> seedDefaultAccount(DatabaseExecutor db) async {
    await db.insert('accounts', {
      'id': defaultAccountId,
      'name': 'My Wallet',
      'type': 'cash',
      'openingBalance': 0,
      'color': '#C87941',
      'creditLimit': null,
      'isArchived': 0,
      'includeInTotal': 1,
      'sortOrder': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }
}
