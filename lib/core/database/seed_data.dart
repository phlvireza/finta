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

  /// The expense categories every fresh install starts with, in sort order
  /// (the index *is* the `sortOrder`).
  ///
  /// Colours come from the chart ramp (AppColors.chartColorsLight) rather
  /// than the older muted swatch list. Two of those swatches were
  /// #D4A05A — byte-identical to AppColors.warning — so a Bills budget at
  /// 30% used was already wearing the colour that is supposed to mean
  /// "75% spent". The chart ramp deliberately omits an amber for exactly
  /// that reason; the seed list never got the same treatment.
  ///
  /// Migration v10 moves existing installs onto these, but only for
  /// categories still sitting on the old hex — a colour the user picked
  /// is theirs.
  ///
  /// Kept as a const table rather than literals inside [seedCategories] so
  /// that [shippedColorFor] — which is what "reset to the default colour"
  /// reads — can never drift from what was actually seeded.
  static const List<({String name, String icon, String color})>
      defaultExpenseCategories = [
    (name: 'Food & Drinks', icon: 'restaurant', color: '#3F8B4C'),
    (name: 'Transport', icon: 'directions_car', color: '#2E5FA8'),
    (name: 'Shopping', icon: 'shopping_bag', color: '#C13F55'),
    (name: 'Bills & Utilities', icon: 'receipt_long', color: '#C1661E'),
    (name: 'Entertainment', icon: 'movie', color: '#7B5B9E'),
    (name: 'Health', icon: 'favorite', color: '#12928C'),
    (name: 'Education', icon: 'school', color: '#A0522D'),
    (name: 'Groceries', icon: 'local_grocery_store', color: '#C87941'),
    (name: 'Other', icon: 'more_horiz', color: '#8A7E74'),
  ];

  /// The income categories every fresh install starts with, in sort order.
  ///
  /// Income and expense categories are never charted together, so the same
  /// hues can serve both lists without two slices of one pie colliding.
  static const List<({String name, String icon, String color})>
      defaultIncomeCategories = [
    (name: 'Salary', icon: 'account_balance_wallet', color: '#3F8B4C'),
    (name: 'Freelance', icon: 'laptop', color: '#2E5FA8'),
    (name: 'Gift', icon: 'card_giftcard', color: '#7B5B9E'),
    (name: 'Investment', icon: 'trending_up', color: '#12928C'),
    (name: 'Other', icon: 'more_horiz', color: '#8A7E74'),
  ];

  /// The colour each fixed-id seed ships with. These rows are referenced by
  /// id (unlike the original seed set, which gets fresh uuids), so they are
  /// keyed that way here too.
  static const Map<String, String> _fixedIdSeedColors = {
    transferCategoryId: '#8A7E74',
    savingsGoalsCategoryId: '#5B8C5A',
    debtPaymentsCategoryId: '#C2665A',
    debtRepaymentsCategoryId: '#5B8C5A',
    donationCategoryId: '#7A8B6F',
  };

  /// The colour a seeded category shipped with, or null when it wasn't
  /// seeded by us — i.e. what "reset to default colour" restores.
  ///
  /// Fixed-id seeds match on id. The original seed set gets fresh uuids at
  /// install time, so those match on type + name, the same key
  /// `Migrations.seedCategoryRecolours` uses. That is also why the UI lets a
  /// default category's colour be edited but not its name: a renamed default
  /// falls out of both lookups.
  ///
  /// [isDefault] is required and short-circuits to null, because name is not
  /// a unique key — a user is free to create their own "Health" expense
  /// category, and it must not be offered a reset to a colour it never had.
  static String? shippedColorFor({
    required String id,
    required String type,
    required String name,
    required bool isDefault,
  }) {
    if (!isDefault) return null;

    final fixed = _fixedIdSeedColors[id];
    if (fixed != null) return fixed;

    final table =
        type == 'income' ? defaultIncomeCategories : defaultExpenseCategories;
    for (final row in table) {
      if (row.name == name) return row.color;
    }
    return null;
  }

  static Future<void> seedCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final batch = db.batch();

    for (var i = 0; i < defaultExpenseCategories.length; i++) {
      final cat = defaultExpenseCategories[i];
      batch.insert('categories', {
        'id': _uuid.v4(),
        'name': cat.name,
        'type': 'expense',
        'icon': cat.icon,
        'color': cat.color,
        'isDefault': 1,
        'sortOrder': i,
        'createdAt': now,
      });
    }

    for (var i = 0; i < defaultIncomeCategories.length; i++) {
      final cat = defaultIncomeCategories[i];
      batch.insert('categories', {
        'id': _uuid.v4(),
        'name': cat.name,
        'type': 'income',
        'icon': cat.icon,
        'color': cat.color,
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
      'color': _fixedIdSeedColors[transferCategoryId]!,
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
      'color': _fixedIdSeedColors[savingsGoalsCategoryId]!,
      'isDefault': 1,
      'sortOrder': 100,
      'createdAt': now,
    });
    batch.insert('categories', {
      'id': debtPaymentsCategoryId,
      'name': 'Debt Payments',
      'type': 'expense',
      'icon': 'attach_money',
      'color': _fixedIdSeedColors[debtPaymentsCategoryId]!,
      'isDefault': 1,
      'sortOrder': 101,
      'createdAt': now,
    });
    batch.insert('categories', {
      'id': debtRepaymentsCategoryId,
      'name': 'Debt Repayments',
      'type': 'income',
      'icon': 'redeem',
      'color': _fixedIdSeedColors[debtRepaymentsCategoryId]!,
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
        'color': _fixedIdSeedColors[donationCategoryId]!,
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
