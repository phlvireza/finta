# Finta — Necessary Improvements & Implementation Guide

Companion to [`feature_gap_analysis.md`](feature_gap_analysis.md). That document covers *what to build next*. **This one covers what must be fixed in what already exists** — defects that cause data loss, wrong numbers, or a crash on the next release.

Every item below was traced to a specific line in the source. Each entry gives the **symptom**, a **reproduction**, the **root cause**, a **concrete fix**, and how to **verify** it.

| Priority | Meaning | Ship before |
| :--- | :--- | :--- |
| **P0** | Destroys or strands user data | Any public release |
| **P1** | Produces wrong numbers the user trusts | v1.1 |
| **P2** | Promised in the PRD, missing or broken | v1.1 |
| **P3** | Structural debt that blocks V2 | Before accounts land |

---

## P0 — Data Loss

### P0-1 · Deleting a category silently deletes every transaction in it

**Severity: critical, irreversible, no warning.**

**Reproduce:** Create a custom category "Coffee". Log 40 transactions to it over two months. Settings → Categories → tap 🗑 → the dialog asks *"Are you sure you want to delete this?"* → confirm. **All 40 transactions are permanently gone**, along with the category's budget and any recurring templates using it. The balance drops with no explanation and there is no undo.

**Root cause** — [category_repository.dart:68-80](lib/repositories/category_repository.dart#L68-L80):

```dart
await db.transaction((txn) async {
  await txn.delete('transactions', where: 'categoryId = ?', whereArgs: [id]);          // ← destroys history
  await txn.delete('recurring_transactions', where: 'categoryId = ?', whereArgs: [id]);
  await txn.delete('budgets', where: 'categoryId = ?', whereArgs: [id]);
  await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
});
```

The confirmation text is the generic `confirmDelete` string ([app_en.arb:83](lib/l10n/app_en.arb#L83)) — it never mentions transactions. This also directly contradicts [PRD.md §2C](PRD.md): *"Deleting a category does not delete transactions — those transactions keep their category label as archived text."*

**Fix — soft-delete (archive) instead of cascade.** A finance app must never destroy history as a side effect of a settings change.

Schema (part of migration v2, see P0-2):

```sql
ALTER TABLE categories ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0;
```

```dart
// lib/repositories/category_repository.dart

/// Archive a category: it disappears from pickers but every historical
/// transaction keeps a resolvable label. Never deletes transactions.
Future<void> archive(String id) async {
  try {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      await txn.update('categories', {'isArchived': 1},
          where: 'id = ?', whereArgs: [id]);
      // A budget for a category you can no longer spend on is meaningless.
      await txn.update('budgets', {'isActive': 0},
          where: 'categoryId = ?', whereArgs: [id]);
      // Stop generating future occurrences, keep the past ones.
      await txn.update('recurring_transactions', {'isActive': 0},
          where: 'categoryId = ?', whereArgs: [id]);
    });
  } catch (e) {
    throw DatabaseException('Failed to archive category', cause: e);
  }
}

/// Hard delete — only permitted when nothing references the category.
Future<int> countUsage(String id) async {
  final db = await _dbHelper.database;
  final r = await db.rawQuery(
    'SELECT COUNT(*) c FROM transactions WHERE categoryId = ?', [id]);
  return (r.first['c'] as int);
}

Future<void> deleteIfUnused(String id) async {
  if (await countUsage(id) > 0) {
    throw StateError('Category still in use');
  }
  final db = await _dbHelper.database;
  await db.transaction((txn) async {
    await txn.delete('budgets', where: 'categoryId = ?', whereArgs: [id]);
    await txn.delete('recurring_transactions', where: 'categoryId = ?', whereArgs: [id]);
    await txn.delete('categories', where: 'id = ?', whereArgs: [id]);
  });
}
```

Provider + UI:

```dart
// lib/providers/category_provider.dart
Future<void> removeCategory(String id) async {
  final category = getCategoryById(id);
  if (category == null || category.isDefault) return;

  if (await _repository.countUsage(id) > 0) {
    await _repository.archive(id);          // history preserved
  } else {
    await _repository.deleteIfUnused(id);   // nothing to lose
  }
  await loadCategories();
}

// Pickers and management lists must filter archived entries:
List<CategoryModel> get selectable =>
    _categories.where((c) => !c.isArchived).toList();
// …but getCategoryById() must still resolve archived ones so old rows render.
```

Then make the dialog honest ([manage_categories_screen.dart:132-139](lib/screens/categories/manage_categories_screen.dart#L132-L139)):

```dart
final usage = await context.read<CategoryProvider>().countUsage(category.id);
final message = usage == 0
    ? loc.confirmDeleteCategory(category.name)
    : loc.confirmArchiveCategory(category.name, usage); // "…used by 40 transactions.
                                                        //  They'll be kept and the
                                                        //  category hidden from new entries."
```

Add both strings to `app_en.arb` and `app_id.arb`.

> **Note:** archived categories must still render in `BudgetOverview`, `TransactionTile`, and `CategoryRankList`. Those widgets currently bail with `SizedBox.shrink()` when `getCategoryById` returns null ([budget_overview.dart:47](lib/screens/dashboard/widgets/budget_overview.dart#L47)) — with archiving, the lookup succeeds, so rows stop vanishing. Style archived labels with reduced opacity plus an "archived" suffix.

**Verify:** archive a category with transactions → history intact, totals unchanged, category absent from the add-transaction picker, old rows still show name and icon.

---

### P0-2 · No `onUpgrade` — the next release crashes every existing install

**Reproduce:** Add any column to any table, bump nothing, install over an existing app. `_onCreate` does not run (the DB file exists), the new column does not exist, and the first query throws `DatabaseException: no such column`. The app is bricked for that user until they reinstall — which wipes all their data.

**Root cause** — [database_helper.dart:27-32](lib/core/database/database_helper.dart#L27-L32): `openDatabase` is called with `version: 1` and `onCreate` only. No `onUpgrade`, no `onConfigure`. Your own [database_migration_guide.md](database_migration_guide.md) documents the correct pattern; it was never wired in.

**Fix:**

```dart
// lib/core/database/database_helper.dart
class DatabaseHelper {
  /// Bump on EVERY schema change and add a matching `if (oldVersion < n)` block.
  static const int dbVersion = 2;

  Future<Database> _initDatabase() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final path = join(await getDatabasesPath(), 'finta.db');

    return openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        // SQLite defaults foreign_keys to OFF; the FKs in our DDL are
        // currently decorative. See P1-4 before enabling.
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Sequential, non-exclusive ifs: a v1 install upgrading to v4
    // replays v2, then v3, then v4 in order.
    if (oldVersion < 2) await Migrations.v2(db);
    if (oldVersion < 3) await Migrations.v3(db);
  }
}
```

Create `lib/core/database/migrations.dart` and keep each version in its own static method, each wrapped in `db.transaction`.

**The invariant that matters:** `_onCreate` must produce a schema *byte-identical* to replaying every `_onUpgrade` step. The cheapest way to guarantee it is to build `_onCreate` from the same DDL constants the migrations use, and to assert it in a test (see P3-4). Divergence here produces bugs that only exist on upgraded installs and are invisible in development.

Migration v2 carries the P0-1 column plus the housekeeping ones:

```dart
// lib/core/database/migrations.dart
static Future<void> v2(Database db) async {
  await db.transaction((txn) async {
    await txn.execute(
      'ALTER TABLE categories ADD COLUMN isArchived INTEGER NOT NULL DEFAULT 0');
    await txn.execute('ALTER TABLE transactions ADD COLUMN merchant TEXT');
    // Idempotency guard for the recurring generator (P1-1).
    await txn.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_recurring_occurrence '
      'ON transactions(recurringId, date) WHERE recurringId IS NOT NULL');
  });
}
```

**Verify:** the migration test in P3-4. Do not ship a schema change without it.

---

### P0-3 · The user cannot get their data out

Finta is local-first with no cloud sync. Today the only export is CSV, and it is broken in two ways ([settings_screen.dart:338-370](lib/screens/settings/settings_screen.dart#L338-L370)):

1. **It writes UUIDs where the user expects names** — line 349 emits `tx.categoryId` into the `Category` column. The file is unreadable to a human and unimportable anywhere.
2. **The file is unreachable.** `getApplicationDocumentsDirectory()` is app-private on Android and iOS. The snackbar prints a path the user cannot open, and there is no share sheet.

Net effect: a lost or reset phone is total, unrecoverable data loss.

**Fix, part 1 — a correct CSV:**

```dart
// lib/core/services/export_service.dart
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportCsv({
  required List<TransactionModel> transactions,
  required CategoryProvider categories,
}) async {
  final rows = <List<dynamic>>[
    ['Date', 'Type', 'Amount', 'Category', 'Merchant', 'Note'],
    for (final t in transactions)
      [
        AppDateUtils.formatIso(t.date),
        t.type,
        t.amount,
        categories.getCategoryById(t.categoryId)?.name ?? 'Uncategorized',
        t.merchant ?? '',
        t.note ?? '',
      ],
  ];

  // ListToCsvConverter handles quoting, embedded commas, newlines and quotes.
  final csv = const ListToCsvConverter().convert(rows);

  final file = File(join(
    (await getTemporaryDirectory()).path,
    'finta_${AppDateUtils.formatIso(DateTime.now())}.csv',
  ));
  // BOM so Excel opens UTF-8 correctly — otherwise accented names mojibake.
  await file.writeAsString('﻿$csv');

  await Share.shareXFiles([XFile(file.path)], subject: 'Finta export');
}
```

**Fix, part 2 — a real backup.** CSV is for humans; a backup must restore *everything*.

```dart
// lib/core/services/backup_service.dart
Future<void> exportBackup() async {
  await DatabaseHelper.instance.close();          // flush WAL before copying
  final archive = Archive()
    ..addFile(ArchiveFile.string('meta.json', jsonEncode({
      'app': 'finta',
      'schemaVersion': DatabaseHelper.dbVersion,
      'appVersion': packageInfo.version,
      'createdAt': DateTime.now().toIso8601String(),
    })))
    ..addFile(await _archiveFile('finta.db'));
  // …plus every file under receipts/ once attachments ship.

  final out = File(join((await getTemporaryDirectory()).path,
      'finta_backup_${AppDateUtils.formatIso(DateTime.now())}.zip'));
  await out.writeAsBytes(ZipEncoder().encode(archive)!);
  await Share.shareXFiles([XFile(out.path)]);
}

Future<void> importBackup(File zip) async {
  final archive = ZipDecoder().decodeBytes(await zip.readAsBytes());
  final meta = jsonDecode(
      utf8.decode(archive.findFile('meta.json')!.content as List<int>));

  if (meta['app'] != 'finta') throw const FormatException('Not a Finta backup');
  // Refuse a backup written by a NEWER app version — its schema is unknown
  // to this build and importing it would corrupt state.
  if ((meta['schemaVersion'] as int) > DatabaseHelper.dbVersion) {
    throw const FormatException('Backup is from a newer version of Finta');
  }

  await _snapshotCurrentDbForRollback();   // so a failed import is recoverable
  await DatabaseHelper.instance.close();
  await _replaceDbFile(archive);
  // Reopening runs onUpgrade, so an OLDER backup migrates forward for free.
}
```

Add **CSV import** with a column-mapping step in the same release — it is how a spreadsheet user or a Money Lover refugee onboards without retyping a year of history.

**Verify:** export a backup, uninstall the app, reinstall, import → identical transaction count, totals, categories, and budgets.

---

## P1 — Wrong Numbers

### P1-1 · Recurring transactions fire on the wrong date (and drift)

Two distinct defects in the same code path.

**Defect A — the first occurrence is skipped for every frequency except daily.**

[recurring_transaction_model.dart:51-67](lib/models/recurring_transaction_model.dart#L51-L67):

```dart
DateTime get nextOccurrence {
  final from = lastRunDate ?? startDate.subtract(const Duration(days: 1));
  switch (frequency) {
    case 'weekly':  return from.add(const Duration(days: 7));   // ← start + 6 days
    case 'monthly': return DateTime(from.year, from.month + 1, from.day);
    …
```

The "subtract one day, then advance one period" trick only works for `daily`. Walk it through:

| Template | Expected first post | Actual first post |
| :--- | :--- | :--- |
| Weekly, starts Jul 15 | Jul 15 | **Jul 21** (start − 1 + 7) |
| Monthly, starts Jul 15 | Jul 15 | **Aug 14** |
| Monthly, starts Jan 31 | Jan 31 | **Mar 2** (Jan 30 → "Feb 30" → overflows) |

A user sets up their salary on payday and it does not appear until the following month, on the wrong day.

**Defect B — monthly dates drift permanently.** [recurring_service.dart:88](lib/core/services/recurring_service.dart#L88) advances from the *previous generated date*, not from the template's anchor day: `DateTime(from.year, from.month + 1, from.day)`. Jan 31 → "Feb 31" = Mar 3 → Apr 3 → May 3. Rent due on the 31st permanently becomes the 3rd.

**Fix — anchor to `startDate.day`, clamp to month length:**

```dart
// lib/models/recurring_transaction_model.dart

/// First run posts on startDate itself; later runs advance from lastRunDate.
DateTime get nextOccurrence =>
    lastRunDate == null ? startDate : advanceFrom(lastRunDate!);

DateTime advanceFrom(DateTime from) {
  switch (frequency) {
    case 'daily':    return from.add(const Duration(days: 1));
    case 'weekly':   return from.add(const Duration(days: 7));
    case 'biweekly': return from.add(const Duration(days: 14));
    case 'monthly':  return _addMonthsAnchored(from, 1);
    case 'yearly':   return _addMonthsAnchored(from, 12);
    default:         return from.add(const Duration(days: 1));
  }
}

/// Advances by [months] keeping the template's anchor day-of-month, clamped
/// to the target month's length. Jan 31 → Feb 28 → Mar 31 (no drift).
DateTime _addMonthsAnchored(DateTime from, int months) {
  final m = from.month + months;                  // DateTime handles >12 rollover
  final lastDay = DateTime(from.year, m + 1, 0).day;
  return DateTime(from.year, m, startDate.day.clamp(1, lastDay));
}
```

Delete `_getNextDate` from `RecurringService` and call `recurring.advanceFrom(nextDate)` — one implementation, not two.

**Defect C — generation is not atomic or idempotent.** [recurring_service.dart:59-61](lib/core/services/recurring_service.dart#L59-L61) inserts and updates `lastRunDate` one row at a time inside a `while` loop with a `try/catch` that swallows errors. A failure mid-loop leaves a partial catch-up, and a crash between insert and `updateLastRunDate` re-posts that occurrence on the next launch — a duplicate salary entry.

```dart
// lib/core/services/recurring_service.dart — per template
final due = <TransactionModel>[];
var next = recurring.nextOccurrence;
while (!next.isAfter(todayDate)) {
  if (recurring.endDate != null && next.isAfter(recurring.endDate!)) break;
  due.add(_materialize(recurring, next));
  next = recurring.advanceFrom(next);
  if (due.length > 500) break;   // runaway guard for a template left open for years
}
if (due.isEmpty) continue;

await db.transaction((txn) async {
  final batch = txn.batch();
  for (final t in due) {
    // Backed by the partial unique index from migration v2 — a replay
    // after a crash is a no-op instead of a duplicate.
    batch.insert('transactions', t.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore);
  }
  await batch.commit(noResult: true);
  await txn.update('recurring_transactions', {'lastRunDate': fmt(due.last.date)},
      where: 'id = ?', whereArgs: [recurring.id]);
});
```

One transaction per template: either the whole catch-up lands or none of it does, and `lastRunDate` can never disagree with what was written.

**Verify:** unit tests in P3-4, especially "monthly on the 31st across February" and "run the generator twice → same row count".

---

### P1-2 · Payday periods break for any payday after the 28th

**Reproduce:** Set payday to 31. Open the app on 15 February.

**Root cause** — [date_utils.dart:39-57](lib/core/utils/date_utils.dart#L39-L57) constructs period bounds with arithmetic that relies on `DateTime`'s silent overflow rollover:

```dart
periodStart = DateTime(now.year, now.month - 1, payday);   // "Feb 31" → Mar 3
periodEnd   = DateTime(now.year, now.month, payday - 1);
```

With payday 31 in a 28-day February the bounds roll into the next month, producing periods that **overlap on some days and leave gaps on others**. Transactions fall outside every period and silently vanish from the dashboard, budgets, and analytics — while still existing in history. The user sees a balance that does not match their transaction list, which is the fastest way to lose trust in a finance app.

`payday` is settable to any value 1–31 ([settings_provider.dart:71](lib/providers/settings_provider.dart#L71) clamps to 1–31), and the picker offers all 31 days, so this is reachable by design, not by accident.

**Fix — clamp the anchor day to each month's actual length:**

```dart
// lib/core/utils/date_utils.dart

/// The [day]-th of [month], clamped to that month's last day.
/// Month values outside 1–12 roll over correctly (0 = December of year−1).
static DateTime _anchor(int year, int month, int day) {
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day.clamp(1, lastDay));
}

static ({DateTime start, DateTime end}) getCurrentPeriod(int payday) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final thisMonthAnchor = _anchor(today.year, today.month, payday);
  final start = today.isBefore(thisMonthAnchor)
      ? _anchor(today.year, today.month - 1, payday)
      : thisMonthAnchor;

  // End is always the day before the next anchor — guarantees contiguous,
  // non-overlapping periods for every payday value.
  final end = _anchor(start.year, start.month + 1, payday)
      .subtract(const Duration(days: 1));

  return (start: start, end: end);
}
```

With payday 31 this yields `Jan 31 – Feb 27`, `Feb 28 – Mar 30`, `Mar 31 – Apr 29` — contiguous, no gaps, no overlaps.

Apply the same `_anchor` helper to `getPreviousPeriod` ([date_utils.dart:84-96](lib/core/utils/date_utils.dart#L84-L96)), which has the identical `month - 1` overflow problem and additionally mis-detects "monthly" by measuring `inDays` between 28 and 31.

**Verify:** parameterised test over `payday ∈ 1..31 × month ∈ 1..12`, asserting `end == nextPeriod.start - 1 day` and `start <= today <= end`.

---

### P1-3 · Backdated transactions corrupt the period totals

**Reproduce:** On 30 July with payday 1, add an expense dated **15 March**. The dashboard's "Expense" total for July increases immediately. Pull-to-refresh and it corrects itself — so the number is wrong only until the next reload, which is exactly when the user is looking at it.

**Root cause** — [transaction_provider.dart:120-130](lib/providers/transaction_provider.dart#L120-L130): `addTransaction` mutates the current-period list and totals with no date check.

```dart
_transactions.add(transaction);        // _transactions is the CURRENT PERIOD list
if (transaction.isIncome) { _totalIncome += amount; } else { _totalExpense += amount; }
```

`updateTransaction` ([:145-156](lib/providers/transaction_provider.dart#L145-L156)) has the mirror problem: it adjusts totals whenever the row is found in the in-memory list, without checking whether the *new* date is still inside the period — so moving a transaction from July to March leaves its amount counted in July.

**Fix — make the loaded period explicit state and gate every mutation on it:**

```dart
// lib/providers/transaction_provider.dart
({DateTime start, DateTime end})? _period;

bool _inPeriod(DateTime date) {
  final p = _period;
  if (p == null) return false;
  final d = DateTime(date.year, date.month, date.day);
  return !d.isBefore(p.start) && !d.isAfter(p.end);
}

Future<void> loadTransactions({required int payday}) async {
  _period = AppDateUtils.getCurrentPeriod(payday);
  …
}

// add:
if (_inPeriod(transaction.date)) {
  _transactions..add(transaction)..sort(_byDateDesc);
  transaction.isIncome ? _totalIncome += amount : _totalExpense += amount;
}

// update: remove the old contribution only if the OLD date was in period,
// add the new one only if the NEW date is.
if (_inPeriod(old.date))     { old.isIncome     ? _totalIncome -= old.amount     : _totalExpense -= old.amount; }
if (_inPeriod(updated.date)) { updated.isIncome ? _totalIncome += updated.amount : _totalExpense += updated.amount; }
```

Also fix the sort comparator: the repository orders by `date DESC, createdAt DESC` ([transaction_repository.dart:12](lib/repositories/transaction_repository.dart#L12)) but the provider re-sorts by `date` alone, so same-day rows shuffle position between a fresh load and an in-memory insert:

```dart
static int _byDateDesc(TransactionModel a, TransactionModel b) {
  final d = b.date.compareTo(a.date);
  return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
}
```

**Verify:** add a backdated transaction → period totals unchanged; add an in-period one → totals move by exactly the amount; edit a transaction's date out of the period → total decreases.

---

### P1-4 · Foreign keys are declared but not enforced

Every table declares `FOREIGN KEY … REFERENCES` ([database_helper.dart](lib/core/database/database_helper.dart)), but SQLite defaults `foreign_keys` to **OFF** per connection. Nothing prevents a transaction pointing at a category that no longer exists — which is precisely the state the app will be in once category deletion stops cascading (P0-1).

Enable it in `onConfigure` (shown in P0-2), then **audit the consequences before shipping**, because enforcement changes runtime behaviour:

- Any delete that leaves a dangling reference now throws instead of silently orphaning. The archive-based flow in P0-1 avoids this by design.
- Add `ON DELETE CASCADE` to the child tables where cascade *is* the intent (`transaction_tags`, `attachments`), so cleanup happens in SQLite rather than in Dart.
- Run a one-off integrity sweep during migration v2 and repair pre-existing orphans, otherwise enabling the pragma will fail on already-corrupt databases:

```dart
final orphans = await db.rawQuery(
  'SELECT t.id FROM transactions t '
  'LEFT JOIN categories c ON c.id = t.categoryId WHERE c.id IS NULL');
// Reassign to a seeded "Uncategorized" category rather than deleting.
```

---

## P2 — Promised but Missing

### P2-1 · The dashboard budget section does not exist

[budget_overview.dart](lib/screens/dashboard/widgets/budget_overview.dart) is complete, correct, and **imported nowhere**. `grep -rn "BudgetOverview" lib/` matches only its own declaration. [PRD.md §2I](PRD.md) specifies it; the dashboard renders `BalanceCard → SummaryRow → DashboardCalendar → RecentTransactions` ([dashboard_screen.dart:79-87](lib/screens/dashboard/dashboard_screen.dart#L79-L87)).

**Fix** — two lines, plus a layout decision:

```dart
children: const [
  BalanceCard(),
  SizedBox(height: AppConstants.spacingLg),
  SummaryRow(),
  SizedBox(height: AppConstants.spacingXxxl),
  BudgetOverview(),                                  // ← mount it
  SizedBox(height: AppConstants.spacingXxxl),
  RecentTransactions(),
],
```

Move `DashboardCalendar` to the Records screen as a list/calendar toggle (see [`feature_gap_analysis.md` §3.3](feature_gap_analysis.md)). A full month grid is a browsing tool; it should not occupy the middle of the at-a-glance screen, and it currently pushes recent transactions below the fold.

While mounting it, localise the hardcoded `'Over Budget!'` at [budget_overview.dart:91](lib/screens/dashboard/widgets/budget_overview.dart#L91) (the code comment already flags it) and add the **pace indicator** from the gap analysis — a progress bar with no time reference tells the user 85% but not whether that is alarming on day 3 or fine on day 27.

---

### P2-2 · Search cannot find what users search for

[transaction_history_screen.dart:45-63](lib/screens/transactions/transaction_history_screen.dart#L45-L63) filters in memory over the note field only — the code comment concedes the point. `TransactionRepository.search` ([:187-204](lib/repositories/transaction_repository.dart#L187-L204)) has the same limit and is not even called by the screen (`TransactionProvider.searchTransactions` is dead API). Filters are three type chips; the PRD scoped category and date-range filters too.

**Fix — push filtering into SQL with a filter object:**

```dart
// lib/models/transaction_filter.dart
class TransactionFilter {
  final String? query;
  final DateTimeRange? dateRange;
  final String? type;                 // income | expense | null
  final Set<String> categoryIds;
  final double? minAmount, maxAmount;
  const TransactionFilter({...});
  bool get isEmpty => …;
}
```

```dart
// lib/repositories/transaction_repository.dart
Future<List<TransactionModel>> query(TransactionFilter f) async {
  final where = <String>[];
  final args  = <Object?>[];

  if (f.type != null)      { where.add('t.type = ?'); args.add(f.type); }
  if (f.dateRange != null) {
    where.add('t.date BETWEEN ? AND ?');
    args..add(fmt(f.dateRange!.start))..add(fmt(f.dateRange!.end));
  }
  if (f.categoryIds.isNotEmpty) {
    where.add('t.categoryId IN (${List.filled(f.categoryIds.length, '?').join(',')})');
    args.addAll(f.categoryIds);
  }
  if (f.minAmount != null) { where.add('t.amount >= ?'); args.add(f.minAmount); }
  if (f.maxAmount != null) { where.add('t.amount <= ?'); args.add(f.maxAmount); }

  if (f.query?.isNotEmpty ?? false) {
    final q = '%${f.query!.replaceAll(RegExp(r'[%_]'), '')}%';
    // Search note, merchant, category name AND the raw amount, so typing
    // "45000" or "starbucks" or "food" all find the row.
    where.add('(t.note LIKE ? OR t.merchant LIKE ? OR c.name LIKE ? '
              'OR CAST(t.amount AS TEXT) LIKE ?)');
    args.addAll([q, q, q, q]);
  }

  final sql = 'SELECT t.* FROM transactions t '
      'LEFT JOIN categories c ON c.id = t.categoryId '
      '${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'} '
      'ORDER BY t.date DESC, t.createdAt DESC';
  return (await (await _dbHelper.database).rawQuery(sql, args))
      .map(TransactionModel.fromMap).toList();
}
```

UI: debounce the search field by ~250 ms, replace the three chips with a filter sheet plus removable active-filter chips, and add the running **"12 transactions · Rp 1.240.000"** summary bar — that single line turns history from a log into an analysis tool.

---

### P2-3 · Half the app is untranslated

The l10n scaffolding (EN + ID ARB, `l10n.yaml`, generated delegates) is in place, but literals bypass it throughout. Confirmed instances:

| String | Location |
| :--- | :--- |
| `'Period'`, `'Weekly'`, `'Bi-Weekly'`, `'Monthly'` | [analytics_screen.dart:130-137](lib/screens/analytics/analytics_screen.dart#L130-L137) |
| `'% more/less than last period'` | [analytics_screen.dart:202](lib/screens/analytics/analytics_screen.dart#L202) |
| `'Yearly Report'` | [analytics_screen.dart:58](lib/screens/analytics/analytics_screen.dart#L58) |
| `'Backup your data'`, `'Select Payday'`, `'System Default'`, `'Light'`, `'Dark'` | [settings_screen.dart](lib/screens/settings/settings_screen.dart) |
| `'Failed to load data'` and every other `ErrorState` title | dashboard, analytics, history |
| `'Over Budget!'` | [budget_overview.dart:91](lib/screens/dashboard/widgets/budget_overview.dart#L91) |
| `'No transactions on this day'` | [dashboard_calendar.dart:54](lib/screens/dashboard/widgets/dashboard_calendar.dart#L54) |
| `'Today'`, `'Yesterday'`, weekday names | [date_utils.dart:15-19](lib/core/utils/date_utils.dart#L15-L19) |
| `frequencyLabel` (`'Daily'`, `'Every 2 weeks'`, …) | [recurring_transaction_model.dart:33-48](lib/models/recurring_transaction_model.dart#L33-L48) |

An Indonesian user gets a visibly half-translated app.

**Fix:** move every literal into the ARB files. Two structural notes:

- `AppDateUtils.relativeLabel` and `frequencyLabel` return display strings from a model/util layer with no `BuildContext`. Return a **token** (`DateLabel.today`, `Frequency.biweekly`) and resolve it in the widget, or pass `AppLocalizations` in. Do not add `BuildContext` to the model.
- Pass `settings.locale` into `DateFormat(pattern, locale)` — month and weekday names currently always render in English regardless of the selected language.
- Add a CI guard: `flutter analyze` plus a grep for `Text('` with a literal in `lib/screens/` catches regressions cheaply.

---

### P2-4 · Two small production leaks

1. **Debug tile in Settings** — "Reset Onboarding (Debug)" ([settings_screen.dart:139-146](lib/screens/settings/settings_screen.dart#L139-L146)) ships to users. Wrap in `if (kDebugMode)` or delete.
2. **Settings is a dead end on 3 of 4 tabs.** It is reachable only from the dashboard app bar ([dashboard_screen.dart:30-41](lib/screens/dashboard/dashboard_screen.dart#L30-L41)). The "More" hub in the proposed navigation ([`feature_gap_analysis.md` §3.1](feature_gap_analysis.md)) solves this permanently; until then, add the icon to the other three app bars.

---

## P3 — Structural Debt (fix before accounts land)

### P3-1 · Aggregate in SQL, not in Dart

`BudgetProvider._calculateStatuses` issues one `getCategorySumByDateRange` query **per budget**, and `AnalyticsProvider` aggregates over lists already materialised in memory. `TransactionProvider.loadAllTransactions` loads the entire table into a `List` for the history screen ([transaction_provider.dart:70-82](lib/providers/transaction_provider.dart#L70-L82)).

At a few hundred transactions this is invisible; at a few thousand — two years of daily use — it is a visible stutter on mid-range Android, and memory grows without bound. Replace the N+1 with one grouped query:

```dart
Future<Map<String, double>> getSumsByCategory(DateTime start, DateTime end) async {
  final rows = await db.rawQuery(
    'SELECT categoryId, COALESCE(SUM(amount),0) total FROM transactions '
    "WHERE type = 'expense' AND date BETWEEN ? AND ? GROUP BY categoryId",
    [fmt(start), fmt(end)]);
  return {for (final r in rows) r['categoryId'] as String: (r['total'] as num).toDouble()};
}
```

Paginate the history screen (`LIMIT`/`OFFSET` on scroll) rather than holding every row.

### P3-2 · Stop orchestrating cache invalidation from widgets

[add_transaction_screen.dart](lib/screens/transactions/add_transaction_screen.dart) reads five providers and manually re-triggers `budgetProvider` and `analyticsProvider` reloads after each save; the same ritual is repeated in [transaction_history_screen.dart:82-85](lib/screens/transactions/transaction_history_screen.dart#L82-L85) and [manage_categories_screen.dart:146-149](lib/screens/categories/manage_categories_screen.dart#L146-L149). Every new dependent provider (accounts, goals, debts) multiplies these call sites, and any missed one is a stale-number bug.

Publish one change signal and let dependents subscribe:

```dart
// TransactionProvider
final _changes = StreamController<void>.broadcast();
Stream<void> get onChanged => _changes.stream;
// …emit after every add/update/delete

// BudgetProvider / AnalyticsProvider constructor
transactionProvider.onChanged.listen((_) => reload());
```

`ChangeNotifierProxyProvider` in `main.dart` wires it. Screens then only save.

### P3-3 · Batch the write paths

`RecurringService` inserts one row per `await` in a loop (P1-1 fixes this with `batch()`); CSV import will need the same treatment. `sqflite`'s `Batch` is roughly an order of magnitude faster for bulk writes and gives transactional atomicity for free.

### P3-4 · Test the money math

`test/` contains only the default `widget_test.dart`. Everything in P1 was a silent-wrong-number bug — exactly the class of defect unit tests catch and manual QA does not. `sqflite_common_ffi` is already a dependency, so this runs headless on desktop with no emulator:

```dart
// test/date_utils_test.dart
void main() {
  group('getCurrentPeriod', () {
    test('periods are contiguous and non-overlapping for every payday', () {
      for (var payday = 1; payday <= 31; payday++) {
        final p = AppDateUtils.getCurrentPeriod(payday);
        expect(p.end.isAfter(p.start), isTrue, reason: 'payday $payday');
        final next = AppDateUtils.getPeriodAfter(p, payday);
        expect(next.start.difference(p.end).inDays, 1, reason: 'payday $payday');
      }
    });
  });
}

// test/recurring_service_test.dart
test('monthly on the 31st does not drift through February', () {
  final t = template(frequency: 'monthly', startDate: DateTime(2026, 1, 31));
  expect(t.nextOccurrence, DateTime(2026, 1, 31));            // posts on start date
  expect(t.advanceFrom(DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
  expect(t.advanceFrom(DateTime(2026, 2, 28)), DateTime(2026, 3, 31)); // recovers
});

test('running the generator twice does not duplicate', () async {
  await service.processRecurringTransactions();
  final first = await repo.getAll();
  await service.processRecurringTransactions();
  expect((await repo.getAll()).length, first.length);
});

// test/migration_test.dart — the one that prevents P0-2 from recurring
test('upgraded schema is identical to a fresh install', () async {
  final upgraded = await openV1Fixture().then(runOnUpgradeTo(DatabaseHelper.dbVersion));
  final fresh    = await openFresh();
  expect(await schemaOf(upgraded), await schemaOf(fresh));
});
```

Minimum bar before v1.1 ships: `date_utils`, `recurring_service`, `budget_provider` ratios, `currency_formatter`, and the migration test.

---

## Sequencing

Nine PRs, ordered by dependency. Each is independently shippable and reviewable.

| # | PR | Contains | Depends on |
| :--- | :--- | :--- | :--- |
| 1 | **Migration infrastructure** | `onUpgrade`, `onConfigure`, `migrations.dart`, migration test | — |
| 2 | **Stop destroying data** | Category archive, honest dialog, orphan sweep, FK pragma | 1 |
| 3 | **Date & period correctness** | `_anchor` clamping, `getPreviousPeriod`, tests | 1 |
| 4 | **Recurring correctness** | First-occurrence fix, anchored months, batched atomic generation, tests | 1, 3 |
| 5 | **Provider total correctness** | `_inPeriod` gating, sort comparator, tests | 3 |
| 6 | **Data out** | CSV with names + share sheet, zip backup/restore, CSV import | 1 |
| 7 | **Dashboard budgets** | Mount `BudgetOverview`, pace indicator, calendar moves to Records | — |
| 8 | **Search & filter** | `TransactionFilter`, SQL query path, filter sheet, summary bar | — |
| 9 | **Localisation & cleanup** | ARB sweep, locale-aware `DateFormat`, remove debug tile, Settings access | — |

PRs 1–5 are the correctness core and should land together as **v1.1**; 6–9 complete it. Only then start accounts ([`feature_gap_analysis.md` §2.1](feature_gap_analysis.md)) — that migration will be far larger, and it should not be the release that first exercises an untested `onUpgrade` path.

### Definition of done for v1.1

- [ ] A category can be removed without losing a single transaction
- [ ] Upgrading from a populated v1 database preserves all data and matches a fresh schema
- [ ] Every payday value 1–31 produces contiguous, non-overlapping periods
- [ ] A monthly recurring created today posts today, and on the 31st every month it can
- [ ] Running the recurring generator twice changes nothing
- [ ] A backdated transaction does not move this period's totals
- [ ] The user can produce a backup file and restore it on a clean install
- [ ] Searching a category name or an amount finds the transaction
- [ ] Switching to Bahasa Indonesia leaves no English strings on the main flows
- [ ] `flutter test` covers dates, recurring, budgets, formatting, and migrations
