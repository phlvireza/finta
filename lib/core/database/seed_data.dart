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

  /// Seeded default category names, in sortOrder order.
  ///
  /// Public and const because they are the English half of the locale table
  /// in `core/utils/default_category_names.dart` — the app renames these rows
  /// when the user changes language, and both sides have to agree on what the
  /// English name is. Seeding always writes English; the rename happens
  /// afterwards, in the app layer, so migrations stay locale-free.
  ///
  /// Note 'Other' appears in both lists, which is why anything matching these
  /// by name must also match on type.
  static const List<String> defaultExpenseCategoryNames = [
    'Food & Drinks',
    'Transport',
    'Shopping',
    'Bills & Utilities',
    'Entertainment',
    'Health',
    'Education',
    'Groceries',
    'Other',
  ];

  static const List<String> defaultIncomeCategoryNames = [
    'Salary',
    'Freelance',
    'Gift',
    'Investment',
    'Other',
  ];

  /// Names of the fixed-id seeded categories, for the same reason.
  static const String savingsGoalsCategoryName = 'Savings & Goals';
  static const String debtPaymentsCategoryName = 'Debt Payments';
  static const String debtRepaymentsCategoryName = 'Debt Repayments';
  static const String donationCategoryName = 'Donation';

  static Future<void> seedCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();

    // ── Default Expense Categories ────────────────────────────
    // Colours come from the chart ramp (AppColors.chartColorsLight) rather
    // than the older muted swatch list. Two of those swatches were
    // #D4A05A — byte-identical to AppColors.warning — so a Bills budget at
    // 30% used was already wearing the colour that is supposed to mean
    // "75% spent". The chart ramp deliberately omits an amber for exactly
    // that reason; the seed list never got the same treatment.
    //
    // Migration v10 moves existing installs onto these, but only for
    // categories still sitting on the old hex — a colour the user picked
    // is theirs.
    final expenseCategories = [
      {'icon': 'restaurant', 'color': '#3F8B4C'},
      {'icon': 'directions_car', 'color': '#2E5FA8'},
      {'icon': 'shopping_bag', 'color': '#C13F55'},
      {'icon': 'receipt_long', 'color': '#C1661E'},
      {'icon': 'movie', 'color': '#7B5B9E'},
      {'icon': 'favorite', 'color': '#12928C'},
      {'icon': 'school', 'color': '#A0522D'},
      {'icon': 'local_grocery_store', 'color': '#C87941'},
      {'icon': 'more_horiz', 'color': '#8A7E74'},
    ];

    for (var i = 0; i < expenseCategories.length; i++) {
      final cat = expenseCategories[i];
      batch.insert('categories', {
        'id': _uuid.v4(),
        'name': defaultExpenseCategoryNames[i],
        'type': 'expense',
        'icon': cat['icon'],
        'color': cat['color'],
        'isDefault': 1,
        'sortOrder': i,
        'createdAt': now,
      });
    }

    // ── Default Income Categories ─────────────────────────────
    // Income and expense categories are never charted together, so the same
    // hues can serve both lists without two slices of one pie colliding.
    final incomeCategories = [
      {'icon': 'account_balance_wallet', 'color': '#3F8B4C'},
      {'icon': 'laptop', 'color': '#2E5FA8'},
      {'icon': 'card_giftcard', 'color': '#7B5B9E'},
      {'icon': 'trending_up', 'color': '#12928C'},
      {'icon': 'more_horiz', 'color': '#8A7E74'},
    ];

    for (var i = 0; i < incomeCategories.length; i++) {
      final cat = incomeCategories[i];
      batch.insert('categories', {
        'id': _uuid.v4(),
        'name': defaultIncomeCategoryNames[i],
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
      'name': savingsGoalsCategoryName,
      'type': 'expense',
      'icon': 'savings',
      'color': '#5B8C5A',
      'isDefault': 1,
      'sortOrder': 100,
      'createdAt': now,
    });
    batch.insert('categories', {
      'id': debtPaymentsCategoryId,
      'name': debtPaymentsCategoryName,
      'type': 'expense',
      'icon': 'attach_money',
      'color': '#C2665A',
      'isDefault': 1,
      'sortOrder': 101,
      'createdAt': now,
    });
    batch.insert('categories', {
      'id': debtRepaymentsCategoryId,
      'name': debtRepaymentsCategoryName,
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
        'name': donationCategoryName,
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
