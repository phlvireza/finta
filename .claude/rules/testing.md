# Testing rules

Tests live in `test/`, one file per unit under test, named `<subject>_test.dart`.
The suite is plain `flutter_test` — no mocking framework, no golden tests.

## Do not run builds unprompted

`flutter test`, `flutter analyze`, and `flutter run` are expensive on this machine.
Do not run them unless explicitly asked; the maintainer runs analysis at the end of a
session. Write the tests, say what they cover, and leave execution to them.

## Where logic should live so it can be tested

Prefer putting new business logic in a **pure function** under `lib/core/utils/` —
no Flutter imports, no database, no `BuildContext`. Those get tested directly with
zero setup, which is why most of `test/` is fast and deterministic:

```dart
test('carries unspent amount into the next period', () {
  expect(computeCarry(budgeted: 500, spent: 380), 120);
});
```

If a calculation is reachable only through a widget or a provider, that is a design
smell — extract the math first, then test the extracted function.

## Database tests

Use `sqflite_common_ffi` against an in-memory database. Every test file that touches
SQLite needs:

```dart
setUpAll(() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
});
```

and opens `databaseFactoryFfi.openDatabase(':memory:', options: OpenDatabaseOptions(...))`.

**Set `onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON')`** on any database
whose behavior depends on foreign keys. The real app turns FKs on in
`DatabaseHelper`, and SQLite defaults them *off* per connection — a test without this
can pass while the production path silently cascades rows away. `test/migration_test.dart`
was fixed for exactly this.

## Migration tests are mandatory

Any change to `lib/core/database/migrations.dart` or `DatabaseHelper.dbVersion`
requires a matching change in `test/migration_test.dart`. That file must keep proving:

1. **Upgrade path** — a database created from the frozen v1 snapshot
   (`_createV1Schema`) upgrades cleanly to the current version.
2. **Data preservation** — rows that existed before the migration still exist
   afterwards, with the values the migration promises (backfilled defaults, copied
   columns, rebuilt link tables).
3. **Convergence** — a fresh `onCreate` install and a fully-upgraded v1 install end
   up with the *same* schema. Column sets, indexes, and constraints must match.

`_createV1Schema` is a historical record of what already shipped. **Never edit it to
track a newer schema** — doing so makes the whole suite vacuous.

## What is worth a test

Write one when the change touches:

- migrations and seed data;
- money math — balances, budget rollover/pace, category rollup, savings rate;
- date/period logic, especially the payday-anchored cycle in `AppDateUtils`;
- projections and heuristics — debt payoff, goal projection, forecasting, anomaly
  detection, health score, subscription detection, insight rules;
- parsing and serialization — CSV import, backup manifest, model `fromMap`/`toMap`;
- any bug fix, so it cannot silently come back.

Skip widget tests for pure layout. `test/widget_test.dart` is an intentional
placeholder that keeps the suite green — don't build it out speculatively.

## Style

- Name tests as behavior: `'v4 preserves budget category links'`, not `'test v4'`.
- Group related cases with `group()` per method or per migration version.
- Cover the edge cases the code explicitly guards: empty inputs, division by zero,
  null-when-insufficient-history (several utils score neutrally rather than
  penalizing — assert that, it is a deliberate product decision), and the safety caps
  (`_maxLookback`, `_maxCatchUpPerTemplate`).
- Use fixed dates. Never let a test's outcome depend on `DateTime.now()`.
