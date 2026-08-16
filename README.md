# Finta

A personal finance tracker built with Flutter. Local-first: everything lives in a
SQLite database on the device — no account, no cloud sync, no server, no telemetry.

## Features

- **Payday-anchored periods** — the app's "month" is a pay cycle, not a calendar
  month. Set a payday (any day 1–31) and the dashboard, budgets, analytics, health
  score and recap all run on that window; periods are contiguous and never overlap,
  and the anchor clamps to each month's last day so payday 31 works in February.
- **Accounts & transfers** — track balances across cash, bank, credit card,
  e-wallet, savings and investment accounts, with linked transfer transactions
  between them, a net worth summary, and credit cards shown as amount owed.
- **Transactions** — income/expense entry with categories, sub-categories, merchant
  autocomplete (which pre-fills the account from that merchant's history, but
  deliberately not the category), notes, full-text/amount search, and filtering.
- **Budgets** — per-category, per-group, or overall budgets on a weekly or monthly
  cycle, recurring or one-off, with optional rollover of unspent (or overspent)
  amounts into the next period, and a pace indicator that reads progress against how
  much of the period has actually elapsed.
- **Recurring transactions & subscriptions** — recurring templates that auto-post on
  schedule, with subscription tracking (monthly/annual cost totals, pause/resume,
  and renewal reminder notifications on Android/iOS/macOS).
- **Goals & debts** — savings goals with a projected completion date, and
  lent/borrowed debt tracking with an optional payoff calculator. Contributions and
  repayments are ordinary transactions tagged with a `goalId`/`debtId`, so edit,
  search, analytics and CSV export work on them for free.
- **Analytics & trends** — category breakdowns, budget performance, a yearly report,
  a rolling 12-month cashflow chart, category spend trends, a spending heatmap
  calendar, and top-merchant rankings.
- **Intelligence layer** — on-device statistics only, no cloud calls: automatic
  subscription detection from repeated charges, anomaly detection for unusually
  large transactions, end-of-period spend forecasting, rule-based spending insights,
  a financial health score, and a shareable recap of the pay period.
- **Faster entry** — one-tap quick-add templates, transaction duplication, an in-app
  amount keypad (with `000` key and `+ − × ÷` expression evaluation) that replaces
  the OS keyboard on every money field, and bulk select/delete/recategorize in the
  transaction list.
- **Backup & data portability** — full-database backup/restore (zip export/import)
  and CSV import/export with column mapping.
- **Privacy touches** — a hide-balances toggle that masks every amount on screen.
- **Archive, not delete** — accounts, categories, goals and debts archive rather
  than vanish, and deleting a goal or debt that has history asks whether to keep
  the underlying transactions or remove them, instead of picking silently.
- **Localization** — English and Bahasa Indonesia, kept at ARB key parity.

## Tech stack

| Concern | Choice |
| --- | --- |
| Framework | Flutter (Material 3), Dart `^3.12.2` |
| Database | `sqflite` on mobile, `sqflite_common_ffi` on desktop |
| State | `provider` (`ChangeNotifier`) |
| Charts | `fl_chart` |
| Settings storage | `shared_preferences` |
| Notifications | `flutter_local_notifications` + `timezone` |
| Data exchange | `archive`, `csv`, `file_picker`, `share_plus` |
| i18n | `flutter_localizations` + ARB (`flutter gen-l10n`) |

## Architecture

Strict one-way layering:

```
Screen / Widget  →  Provider (ChangeNotifier)  →  Repository  →  DatabaseHelper (sqflite)
```

- **Database** — versioned schema migrations in `lib/core/database/migrations.dart`,
  one static method per version bump, replayed sequentially on upgrade. A fresh
  install's `onCreate` schema is asserted to match a v1 install that has replayed
  every migration (`test/migration_test.dart`).
- **State** — `provider`, with screens never touching the database directly.
  Repositories are the only layer that talks to `sqflite`.
- **Business logic** — kept in pure, dependency-free functions under
  `lib/core/utils/` wherever possible (payday period math, budget rollover, category
  rollup, trend comparison, anomaly detection, forecasting, subscription detection,
  insight rules, debt payoff, goal projection, health score, expression evaluation)
  so the math is unit-testable without a database or widget tree.
- **Derived, not stored** — account balances, goal/debt progress, and budget rollover
  carry are all computed from the transaction history rather than persisted
  separately, so they can never drift out of sync when a past transaction is edited.
- **Idempotent catch-up** — recurring generation, one-off budget expiry and rollover
  all reconcile at launch, so leaving the app closed for a month is a supported case.
  Recurring posts are deduplicated by a partial unique index on
  `transactions(recurringId, date)`.

### Project layout

```
lib/
  app/            app shell — init sequence, onboarding routing, bottom nav
  core/
    constants/    spacing, radii, colors, typography, currencies
    database/     DatabaseHelper, migrations, seed data
    formatters/   currency input/display formatting
    services/     recurring, budget rollover, budget expiry, backup, CSV import,
                  notifications
    theme/        light + dark ThemeData
    utils/        pure business logic (unit-tested, no Flutter imports)
  l10n/           ARB files + generated localizations
  models/         data classes with toMap/fromMap/copyWith
  providers/      ChangeNotifier state holders
  repositories/   per-table data access
  screens/        feature directories, each with its own widgets/
  widgets/        shared, feature-agnostic widgets
test/             unit tests (sqflite_common_ffi, in-memory databases)
```

## Getting started

Requires a Flutter SDK providing Dart `^3.12.2`.

```bash
flutter pub get
flutter run                 # connected device or emulator
flutter run -d windows      # desktop dev target
```

Android and iOS are the shipping targets; the Windows target exists for faster
development iteration — note that scheduled notifications are a no-op there, since
the notifications plugin only supports Android/iOS/macOS.

### Development

```bash
flutter test        # run the test suite
flutter analyze     # static analysis (flutter_lints)
flutter gen-l10n    # regenerate localizations after editing lib/l10n/*.arb
```

When adding user-facing strings, update **both** `lib/l10n/app_en.arb` and
`lib/l10n/app_id.arb` — the two files are kept at key parity.

## Data & privacy

All data stays on the device. The app makes no network requests; the "intelligence"
features are ordinary on-device statistics. Backup produces a zip of the SQLite file
plus a small manifest recording the schema version it was written at, handed to the
OS share sheet — you choose where it goes.
