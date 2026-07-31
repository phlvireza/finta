# Finta

A personal finance tracker built with Flutter. Local-first: everything lives in a
SQLite database on the device, with no account, cloud sync, or server required.

## Features

- **Accounts & transfers** — track balances across multiple cash/bank/card/wallet
  accounts, with linked transfer transactions between them and a net worth summary.
- **Transactions** — income/expense entry with categories, sub-categories, merchant
  autocomplete (with smart category/account prefill from merchant history), notes,
  a full-text/amount search, and filtering.
- **Budgets** — per-category, per-group, or overall budgets on weekly/monthly/
  quarterly/yearly cycles, with optional rollover of unspent (or overspent) amounts
  into the next period.
- **Recurring transactions & subscriptions** — recurring templates that auto-post on
  schedule, with subscription tracking (monthly/annual cost totals, pause/resume,
  and renewal reminder notifications on Android/iOS/macOS).
- **Goals & debts** — savings goals with a projected completion date, and
  lent/borrowed debt tracking with an optional payoff calculator.
- **Analytics & trends** — category breakdowns, budget performance, a yearly report,
  a rolling 12-month cashflow chart, category spend trends, a spending heatmap
  calendar, and top-merchant rankings.
- **Intelligence layer** — on-device statistics only, no cloud calls: anomaly
  detection for unusually large transactions, end-of-period spend forecasting,
  rule-based spending insights, a financial health score, and a shareable monthly
  recap image.
- **Faster entry** — one-tap quick-add templates, transaction duplication, an
  in-form calculator, and bulk select/delete/recategorize in the transaction list.
- **Backup & data portability** — full-database backup/restore (zip export/import)
  and CSV import/export with column mapping.
- **Localization** — English and Bahasa Indonesia.

## Architecture

- **Database**: `sqflite` (mobile) / `sqflite_common_ffi` (desktop dev target),
  versioned schema migrations in `lib/core/database/migrations.dart` — one method
  per version bump, replayed sequentially on upgrade.
- **State management**: `provider`, with a strict Repository → Provider → Screen
  layering — screens never touch the database directly.
- **Business logic**: kept in pure, dependency-free functions under
  `lib/core/utils/` wherever possible (budget rollover, category rollup, trend
  comparisons, anomaly detection, forecasting, health score) so the actual math is
  unit-testable without a database or widget tree.

## Getting Started

Standard Flutter project layout. `flutter pub get` to install dependencies, then
`flutter run` to launch on a connected device or `flutter run -d windows` (etc.)
for a desktop target.
