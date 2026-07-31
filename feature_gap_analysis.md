# Finta — Feature Gap Analysis, Layout Blueprint & Implementation Guide

> Benchmarked against the personal-finance apps people actually use daily: **YNAB**, **Monarch Money**, **Copilot**, **Money Manager (Realbyte)**, **Wallet by BudgetBakers**, **Money Lover**, **Spendee**, **Bluecoins**, **Toshl**, **PocketGuard**, **Actual Budget**, and **Cashew** (the closest open-source Flutter analogue).
>
> Everything in Section 1 was verified against the current source tree, not assumed. Sections 2–6 are the recommendations.

---

## Table of Contents

1. [Current State Audit](#1-current-state-audit)
2. [Feature Gaps](#2-feature-gaps)
3. [Layout & Information Architecture](#3-layout--information-architecture)
4. [Data Model & Migration Plan](#4-data-model--migration-plan)
5. [Implementation Playbook](#5-implementation-playbook)
6. [Release Roadmap](#6-release-roadmap)

---

## 1. Current State Audit

### 1.1 What is actually built

| Area | Status | Evidence |
| :--- | :--- | :--- |
| Local SQLite persistence | ✅ Done | `lib/core/database/database_helper.dart` — 4 tables, 3 indexes, seeded categories |
| Provider + Repository architecture | ✅ Clean | 6 providers, 4 repositories, no DB calls from widgets |
| Onboarding (welcome → currency → payday) | ✅ Done | `lib/screens/onboarding/` |
| Add/edit transaction, auto-comma amount input | ✅ Done | `add_transaction_screen.dart`, `currency_formatter.dart` |
| Categories: default + custom, icon & color picker | ✅ Done | `lib/screens/categories/` |
| Budgets per category + 75%/100% alerts | ✅ Done | `budget_provider.dart` (`BudgetStatus`, `checkBudgetAlert`) |
| Recurring transactions + auto-generation on launch | ✅ Done | `recurring_service.dart`, called from `app.dart:63` |
| Analytics: donut, category ranking, period compare | ✅ Done | `analytics_screen.dart` + widgets |
| Yearly report | ✅ Done | `screens/analytics/widgets/yearly_report.dart` |
| Dashboard calendar with per-day drill-down | ✅ Done | `dashboard_calendar.dart` (table_calendar) |
| Light/dark warm theme | ✅ Done | `app_theme.dart`, `app_colors.dart` |
| i18n scaffolding (EN + ID) | ⚠️ Partial | ARB files exist; many strings still hardcoded |
| CSV export | ⚠️ Broken in practice | See 1.2 |
| Transaction search & filter | ⚠️ Partial | Note-text + type only |

### 1.2 Defects and debt found during the audit

These are worth fixing *before* new features, because several of them will be baked into the migration path.

1. **No `onUpgrade` handler.** `database_helper.dart:27-32` opens the DB at `version: 1` with only an `onCreate` callback. `database_migration_guide.md` documents the correct pattern but it was never wired up. **The moment you ship a schema change to a real user, the app crashes on launch.** This is the single highest-priority fix in this document.

2. **CSV export writes raw IDs and hides the file.** `settings_screen.dart:349` writes `tx.categoryId` into the "Category" column — a UUID, useless to the user. The file is saved to `getApplicationDocumentsDirectory()`, which is app-private on Android/iOS; the snackbar shows a path the user cannot open. Needs category-name resolution and a share sheet.

3. **`BudgetOverview` is dead code.** `screens/dashboard/widgets/budget_overview.dart` is fully implemented but imported nowhere — the dashboard renders `BalanceCard → SummaryRow → DashboardCalendar → RecentTransactions`. The PRD's "Dashboard Budget Section" therefore does not exist in the shipped UI.

4. **Search cannot find what users search for.** `_getFilteredTransactions` (`transaction_history_screen.dart:45-63`) matches the note field only. Users type a category name or an amount. The comment in the code acknowledges this.

5. **No date-range or category filter** in history, despite being in scope in the PRD (§2E).

6. **Debug affordance in production UI.** "Reset Onboarding (Debug)" is a live tile in Settings → Data.

7. **Hardcoded strings bypass the l10n layer** — `'Period'`, `'Weekly'`, `'Bi-Weekly'`, `'Monthly'`, `'Yearly Report'`, `'Backup your data'`, `'Failed to load data'`, `'Select Payday'`, `'No transactions on this day'`, `'% more/less than last period'`. Indonesian users see a half-translated app.

8. **Settings is only reachable from the Dashboard app bar.** From Transactions, Analytics, or Budgets there is no path to Settings — a dead end on 3 of 4 tabs.

9. **Nav bar index 2 is a `SizedBox` placeholder inside an `IndexedStack`** (`app.dart:31-37`). It works, but it is fragile; a real 5th destination will require restructuring anyway (see §3.1).

10. **Test coverage is a single default `widget_test.dart`.** Money math (budget ratios, payday period boundaries, recurring generation) is exactly the code that must not silently break.

---

## 2. Feature Gaps

Ranked by impact-to-effort. Each entry states what the benchmark apps do, why it matters, and how it should work in Finta specifically.

### Tier 1 — Finta is not credible as a daily driver without these

#### 2.1 Accounts / Wallets (and transfers)

**Benchmarks:** every app in the list has this. Money Manager and Bluecoins make the account picker the second field on the entry form; Monarch and Copilot lead the dashboard with net worth across accounts.

**Why it matters:** Today Finta computes one global balance from income minus expenses. A user with cash, a bank account, and a credit card cannot answer "how much cash do I have right now?" — and every expense from a credit card is currently indistinguishable from one that drained their checking account. This is the top item on your own `v2_roadmap.md`, and it is correct.

**How it should work in Finta:**
- Account types: `cash`, `bank`, `credit_card`, `e_wallet`, `savings`, `investment`.
- Each account has an **opening balance**; current balance = opening + Σ(income) − Σ(expense) − Σ(transfers out) + Σ(transfers in).
- Credit cards invert the display sign: a positive computed balance shows as "Rp 2.400.000 owed" in the expense color, and they are **excluded from "available cash"** but included in net worth.
- Accounts can be `isArchived` (hidden from pickers, still in history) rather than deleted.
- A **transfer** is not a new transaction type. Model it as a *pair* of transactions linked by `transferId`: an `expense` on the source account and an `income` on the destination account, both with `isTransfer = 1`. This keeps every existing query working — but every analytics/budget aggregation must add `WHERE isTransfer = 0`, otherwise moving money between your own accounts inflates both income and expenses.
- Dashboard gains an account carousel; balance card becomes "Net Worth" with an expandable account list.
- Add-transaction form gains an account chip row directly under the amount field, defaulting to the most-recently-used account.

**Effort:** L. Touches schema, every repository aggregate, dashboard, and the entry form. Do it first, because every later feature (goals, debt, net worth trend) depends on the account table existing.

#### 2.2 Merchant / payee field + smart autofill

**Benchmarks:** Copilot and Monarch treat the merchant as the primary label of a transaction; the category is secondary metadata. Money Lover autocompletes from history.

**Why it matters:** Finta's transaction list currently reads as "Food & Drinks — Rp 45.000" for every meal. There is no way to answer "how much do I spend at Starbucks?" The note field is free text and nobody fills it consistently.

**How it should work:**
- Add `merchant TEXT` to `transactions`, surfaced as the second form field with an autocomplete built from `SELECT DISTINCT merchant ... ORDER BY COUNT(*) DESC`.
- On selecting a known merchant, **pre-fill category and account** from that merchant's most frequent pairing. This is 20 lines of SQL and feels like magic — it is the cheapest "smart" feature available.
- Transaction tile shows `merchant` as the title with the category as the subtitle, falling back to the category name when merchant is empty.

**Effort:** S. Highest delight-per-line-of-code in this document.

#### 2.3 Real search & filtering

**Benchmarks:** Bluecoins and Wallet both ship a full filter sheet: date range, accounts, categories, amount range, type, tags.

**How it should work:** Replace the three type chips with a persistent search field plus a **filter sheet** and a row of removable active-filter chips (`Jul 1–31 ×`, `Food & Drinks ×`).
- Search matches merchant, note, **category name**, and amount (typing `45000` finds Rp 45.000).
- Filters: date range (with presets: this period, last period, last 3 months, custom), type, accounts (multi), categories (multi), amount min/max, "has attachment".
- Persist the last-used filter in memory for the session; show a running "**12 transactions · Rp 1.240.000**" summary bar above the results — this is what turns history into an analysis tool.

**Effort:** M.

#### 2.4 Attachments (receipt photos)

**Benchmarks:** universal; Wallet and Bluecoins both attach images to transactions.

**How it should work:** `image_picker` (camera + gallery) → copy the file into the app documents directory under `receipts/<txId>_<n>.jpg` → store relative paths in a new `attachments` table (never absolute paths — iOS container UUIDs change between builds and will orphan every image). Show a thumbnail strip on the transaction detail sheet with a full-screen viewer. Delete files when the transaction is deleted.

Your migration guide already uses `image_path` as its worked example — this is the intended next step.

**Effort:** M.

#### 2.5 Backup, restore & CSV import

**Benchmarks:** Money Manager and Bluecoins live and die on their local backup/restore, because they are also account-free apps.

**Why it matters:** Finta is local-first with **no cloud sync**. Right now a lost phone equals total data loss, and there is no way out of the app. That is an unacceptable risk profile for a finance app and the fastest way to lose a user permanently.

**How it should work:**
- **Export backup:** zip `finta.db` plus the `receipts/` directory into `finta_backup_YYYYMMDD.zip`, hand it to the OS share sheet (`share_plus`) so it can go to Drive/Files/WhatsApp.
- **Import backup:** `file_picker` → validate a `meta.json` schema version → close the DB → replace the file → restart the app shell. Refuse to import a backup whose schema version is *newer* than the running app.
- **Fix CSV export** (see 1.2) and add **CSV import** with a column-mapping step; auto-create categories that do not exist. Import is how you win users away from a spreadsheet or another app.
- **Optional auto-backup:** weekly local snapshot, keep last 5.

**Effort:** M.

#### 2.6 App lock (PIN + biometrics)

**Benchmarks:** table stakes across the category.

**How it should work:** `local_auth` for Face ID/fingerprint, with a **PIN fallback** (never biometric-only — biometrics fail and you must not lock a user out of their own data). Store a salted PIN hash in `flutter_secure_storage`, never in `SharedPreferences`. Lock on `AppLifecycleState.paused` past a configurable grace period (Immediately / 1 min / 5 min). Add a "hide balances" blur toggle for shoulder-surfing, plus `FLAG_SECURE` on Android to keep balances out of the app switcher.

**Effort:** S–M.

---

### Tier 2 — What separates a good tracker from a great one

#### 2.7 Savings goals & sinking funds

**Benchmarks:** Monarch's goals, Money Lover's savings jars, YNAB's targets.

**How it should work:** A goal has a name, target amount, optional target date, icon/color, and an optional linked account. Contributions are transactions tagged with `goalId` (either transfers into a savings account or "virtual" allocations if no account is linked). The goal card shows a progress ring, "Rp 4.2M of Rp 20M (21%)", and a **projected completion date** derived from the average of the last 3 months' contributions — that projection is the feature people screenshot and share.

**Effort:** M.

#### 2.8 Debt & loan tracking

**Benchmarks:** Bluecoins, Wallet, Money Manager all have a debt ledger; PocketGuard added payoff planning.

**Why it matters:** Nearly universal need in Finta's likely market (credit cards, paylater, "kasbon" between friends), and completely unserved today. A credit-card *account* covers the balance, but not "I lent Budi Rp 500.000".

**How it should work:** A `debts` table (`type: lent | borrowed`, counterparty, principal, optional due date, optional interest). Repayments are transactions linked by `debtId` that reduce the outstanding balance. A summary card shows "You are owed Rp 1.2M / You owe Rp 3.4M". Optional payoff calculator (snowball vs avalanche) for credit cards.

**Effort:** M.

#### 2.9 Cashflow & trend analytics

**Benchmarks:** Copilot's monthly cashflow bars, Monarch's Sankey, YNAB's age-of-money.

**Why it matters:** Finta's analytics answer "where did money go *this period*" (a donut) but never "**am I getting better?**" A donut chart cannot show a trend. This is the biggest analytical gap.

**How it should work — add four views to the Analytics tab:**
1. **Cashflow bars** — income vs expense per month for the last 12 months, with a net line overlay.
2. **Category trend** — tap any category to see its monthly spend over 6–12 months, plus "**Rp 320k above your 6-month average**".
3. **Daily burn rate** — average spend/day this period, projected end-of-period total against budget, and "safe to spend per day" for the remaining days. This single number is PocketGuard's entire value proposition.
4. **Spending heatmap calendar** — day cells tinted by spend intensity. You already have `table_calendar` on the dashboard; reuse the same widget with a different day-builder.

**Effort:** M. Mostly aggregation SQL plus `fl_chart`, which is already a dependency.

#### 2.10 Subscriptions & upcoming bills

**Benchmarks:** Emma and Copilot built their marketing on subscription detection.

**Why it matters:** Recurring templates exist in Finta but are buried in Settings → Recurring, and generate silently. Users never see "you spend Rp 480.000/month on subscriptions".

**How it should work:** A dedicated Subscriptions view (a section on the dashboard plus a full screen) listing active recurring items with next-due dates, a **total monthly + annualised cost** header, and days-until-charge badges. Add **local notifications** 1–3 days before a charge. Add a "pause" state distinct from delete. Optionally auto-detect candidates: same merchant + similar amount + ~30-day spacing, 3+ occurrences → "Is this a subscription?".

**Effort:** M.

#### 2.11 Budget system upgrades

Current budgets are one flat monthly amount per category, one row per category (`UNIQUE(categoryId)`), tied to the payday cycle. Gaps versus the benchmarks:

- **Period flexibility** — weekly / monthly / quarterly / yearly / custom, per budget (Wallet, Toshl).
- **Rollover (sinking funds)** — unspent budget carries to next period; overspend carries as a negative. This is YNAB's core mechanic and the reason people pay for it.
- **Total/overall budget** — one cap across all spending, not just per-category.
- **Group budgets** — one budget spanning several categories ("Lifestyle" = Entertainment + Shopping + Dining).
- **Budget templates** — copy last period's budgets forward in one tap; today every new period requires manual re-entry.
- **Pace indicator** — "You're 60% through the month but 85% through this budget." A progress bar without a time reference is misleading, and this is a 10-line change with outsized value.

**Effort:** M (schema change to `budgets` plus a rollover ledger).

#### 2.12 Tags / labels

**Benchmarks:** Toshl's tags are its defining feature; Bluecoins has labels; Spendee has hashtags.

**Why it matters:** Categories are a single hierarchy and force false choices. Tags cut across it: `#bali-trip`, `#reimbursable`, `#work`. "How much did the Bali trip cost?" is unanswerable today.

**How it should work:** Many-to-many `tags` + `transaction_tags`. A chip input on the entry form with autocomplete. A tag report screen showing total per tag over a date range. Parse `#hashtags` out of the note field automatically — free input UX.

**Effort:** S–M.

#### 2.13 Sub-categories

Already in `v2_roadmap.md` §3. Add `parentId TEXT` to `categories` and enforce exactly two levels — infinite nesting is a support nightmare and nobody uses depth 3. Analytics roll up to parents by default with a toggle to expand. Migration is trivial (nullable column), but every category picker and aggregation query needs a grouping pass.

**Effort:** M.

#### 2.14 Faster entry

The single most repeated action in the app deserves the most optimisation:
- **Quick-add sheet** — bottom sheet with amount pad + last-used category, saveable in ~3 taps, instead of a full-screen form.
- **Templates / favourites** — "Morning coffee Rp 25.000" as a one-tap entry.
- **Duplicate transaction** — long-press → duplicate.
- **In-form calculator** — `12500 + 30000` evaluated in the amount field. Money Manager and Cashew both do this and users love it.
- **Home-screen widget / quick-settings tile** for entry without opening the app.
- **Bulk actions** in history — multi-select to delete or recategorise.

**Effort:** S each; collectively transformative for retention.

---

### Tier 3 — Differentiators, once the foundation is solid

| Feature | Notes |
| :--- | :--- |
| **Receipt OCR** | `google_mlkit_text_recognition`, fully on-device (privacy-preserving, no API cost). Extract total, date, merchant → pre-fill the form. Already in your roadmap §5; keep it *after* attachments ship, since it reuses that pipeline. |
| **Cloud sync** | Roadmap §2. Genuinely large: auth, conflict resolution, offline queue. If pursued, use Supabase (Postgres, generous free tier, straightforward row-level security) and treat SQLite as the offline cache with a `syncedAt`/`isDirty` column per row. **Do not start this before backup/restore ships** — backup solves 80% of the pain for 10% of the cost. |
| **Multi-currency with conversion** | Per-account currency, per-transaction rate stored at entry time (never re-convert history), one base currency for reporting. Rates from a free API with a cached fallback. Essential for travellers; large blast radius on every aggregate. |
| **Shared / household budgets** | Requires cloud sync first. |
| **Bank sync (Open Banking)** | Region-dependent, expensive, requires legal review. Out of scope for the foreseeable future — and Finta's "no bank connection" stance is a genuine privacy selling point worth keeping. |
| **Financial health score** | A single 0–100 composite (savings rate, budget adherence, income stability). Cheap to compute, very engaging as a monthly notification. |
| **Monthly recap** | An auto-generated "Your July" summary card, shareable as an image. Spotify-Wrapped mechanics applied to money. You already compute nearly all of these numbers in `yearly_report.dart`. |

---

## 3. Layout & Information Architecture

### 3.1 Navigation

**Problem with the current shell:** 5 nav slots where slot 2 is a dummy `SizedBox` inside an `IndexedStack`; Budgets occupies a top-level tab it does not earn (it is a low-frequency configuration surface); Settings is orphaned on 3 of 4 tabs.

**Recommended structure — 4 destinations + centre FAB:**

```
┌──────────────────────────────────────────────┐
│  🏠 Home    📋 Records   [ + ]   📊 Insights   👤 More │
└──────────────────────────────────────────────┘
```

- **Home** — net worth, accounts, this period's pulse, budgets, upcoming, recent.
- **Records** — the full transaction ledger with search and filters.
- **[+]** — centre FAB opening the quick-add sheet (long-press → transfer / income / template).
- **Insights** — analytics, trends, reports.
- **More** — accounts, budgets, goals, debts, subscriptions, categories, settings. This hub is what fixes the Settings dead end and gives every Tier-2 feature a home without adding tabs.

This is the layout Money Manager, Wallet, and Money Lover all converged on — for good reason: it keeps the two highest-frequency surfaces (view / log) one tap away and pushes configuration into a hub.

### 3.2 Home

The current dashboard puts a full month calendar in the middle of the primary scroll — that is a *browsing* tool occupying premium *at-a-glance* real estate. Move it into Records as a view toggle. Home should answer three questions in one screen: how much do I have, am I on track, what's coming.

```
┌───────────────────────────────────────────────┐
│  Good evening, Reza            🔔  👤          │
│                                               │
│  NET WORTH                          ▾ hide    │
│  Rp 24.850.000                                │
│  ▲ Rp 1.2M this month                         │
│                                               │
│  ┌────────┐ ┌────────┐ ┌────────┐ ┌───────┐  │
│  │ 💵 Cash│ │🏦 BCA  │ │💳 Card │ │   +   │  │  ← horizontal
│  │  450k  │ │ 22.4M  │ │ -1.8M  │ │  Add  │  │    carousel
│  └────────┘ └────────┘ └────────┘ └───────┘  │
│                                               │
│  THIS PERIOD          Jul 25 – Aug 24  ▾      │
│  ┌─────────────────┐ ┌─────────────────┐     │
│  │ ↓ Income        │ │ ↑ Expense       │     │
│  │ Rp 8.500.000    │ │ Rp 5.240.000    │     │
│  └─────────────────┘ └─────────────────┘     │
│  ▓▓▓▓▓▓▓▓▓▓▓▓░░░░░  62% of income spent      │
│  Safe to spend: Rp 108k/day for 14 days      │  ← burn rate (§2.9)
│                                               │
│  BUDGETS                            See all → │
│  🍔 Food & Drinks    ▓▓▓▓▓▓▓▓░░  85% ⚠       │
│  🚗 Transport        ▓▓▓▓░░░░░░  40%          │
│  🛍 Shopping         ▓▓▓▓▓▓▓▓▓▓ 112% ⛔      │
│                                               │
│  UPCOMING                           See all → │
│  📺 Netflix        in 2 days     Rp 186.000   │
│  🏠 Rent           in 6 days     Rp 3.500.000 │
│                                               │
│  RECENT                             See all → │
│  Starbucks · Food & Drinks · BCA   -45.000    │
│  Salary · Income · BCA          +8.500.000    │
└───────────────────────────────────────────────┘
```

Key changes: net worth replaces a bare balance; accounts are visible and tappable; `BudgetOverview` (already written, currently dead) gets mounted; upcoming bills surface recurring items that are invisible today; recent transactions lead with **merchant**, not category.

### 3.3 Records

```
┌───────────────────────────────────────────────┐
│  Records              [🔍]  [☰ filter]  [📅]  │  ← list / calendar toggle
│  ┌─────────────────────────────────────────┐ │
│  │ 🔍 Search merchant, note, category…     │ │
│  └─────────────────────────────────────────┘ │
│  [Jul 25–Aug 24 ×] [Expense ×] [+ Filter]    │  ← active filter chips
│                                               │
│  12 transactions · Rp 1.240.000               │  ← running summary
│                                               │
│  ── TODAY ──────────────── Rp 245.000 ──      │  ← per-day subtotal
│  🍔 Starbucks                       -45.000   │
│     Food & Drinks · BCA · #work               │
│  🚗 Gojek                          -200.000   │
│     Transport · Cash                          │
│                                               │
│  ── YESTERDAY ──────────── Rp 8.500.000 ──    │
│  💰 Salary                       +8.500.000   │
│     Income · BCA · 🔁                          │
└───────────────────────────────────────────────┘
```

Add: per-day subtotals in the sticky headers (present in Money Manager, absent in Finta), the account name on each row, tag chips, and a calendar-view toggle that reuses `DashboardCalendar`.

### 3.4 Quick-add sheet (replaces the full-screen form for the common case)

```
┌───────────────────────────────────────────────┐
│              ═══                              │
│   [ Expense ]  Income   Transfer              │
│                                               │
│              Rp 45.000                        │  ← large, tabular figures
│                                               │
│  💳 BCA ▾        🍔 Food & Drinks ▾            │  ← MRU defaults
│  📅 Today ▾      🏪 Starbucks                  │  ← merchant autocomplete
│                                               │
│  ┌───┬───┬───┬───┐                            │
│  │ 1 │ 2 │ 3 │ ← │                            │
│  ├───┼───┼───┼───┤                            │
│  │ 4 │ 5 │ 6 │ + │   ← in-sheet calculator    │
│  ├───┼───┼───┼───┤                            │
│  │ 7 │ 8 │ 9 │ − │                            │
│  ├───┼───┼───┼───┤                            │
│  │ . │ 0 │000│ ✓ │                            │
│  └───┴───┴───┴───┘                            │
│  📷 Receipt   🏷 Tags   📝 Note   🔁 Repeat    │  ← progressive disclosure
└───────────────────────────────────────────────┘
```

Three taps from FAB to saved. The existing `AddTransactionScreen` stays as the "detailed" path reachable from the "more fields" row and from edit.

### 3.5 Insights

Replace the current two-tab (Expense / Income) donut screen with a scrollable report composed of sections, keeping the period selector pinned:

```
Period: [ Week | Month | Quarter | Year | Custom ]

1. Cashflow            — 12-month income/expense bars + net line
2. Where it went       — donut + ranked list (existing, keep)
3. Trends              — per-category line over 6 months
4. Budget performance  — budget vs actual (existing, promote)
5. Heatmap             — calendar tinted by daily spend
6. Top merchants       — new, enabled by §2.2
7. Reports             — Yearly report, Monthly recap, Tag report
```

### 3.6 Visual system

The PRD's warm palette and anti-slop checklist are good and are largely honoured in code. Additions worth specifying now that new surfaces are coming:

- **Account colour coding** — each account gets a colour used consistently in the carousel, on transaction rows, and in charts.
- **Sign convention** — always `−` for money out and `+` for money in, everywhere, in the income/expense colours, never bare numbers.
- **Tabular figures everywhere** — already specified in the PRD; enforce it on the new account cards and per-day subtotals so columns align.
- **Empty states with a primary action** — every new surface (accounts, goals, debts, subscriptions) ships with an illustration plus a "Create your first…" button, not a bare message.
- **Skeleton loaders** instead of `CircularProgressIndicator` on the dashboard and insights; spinners on a data-dense screen read as jank.
- **Balance blur toggle** — a privacy affordance and a nice piece of visual polish.

---

## 4. Data Model & Migration Plan

### 4.1 Fix the migration mechanism first

`database_helper.dart` currently opens the DB with `onCreate` only. Before any schema work:

```dart
// lib/core/database/database_helper.dart
static const int _dbVersion = 2; // bump on every schema change

return openDatabase(
  path,
  version: _dbVersion,
  onCreate: _onCreate,
  onUpgrade: _onUpgrade,
  onConfigure: (db) async {
    await db.execute('PRAGMA foreign_keys = ON'); // currently not enforced
  },
);

Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
  // Sequential, non-exclusive ifs so v1 → v4 replays every step in order.
  if (oldVersion < 2) await _migrateV2Accounts(db);
  if (oldVersion < 3) await _migrateV3MerchantsTags(db);
  if (oldVersion < 4) await _migrateV4GoalsDebts(db);
}
```

Two rules, both from `database_migration_guide.md` and both worth restating because violating them destroys user data: **never `DROP TABLE`**, and **`_onCreate` must produce a schema byte-identical to the one reached by replaying every `_onUpgrade` step** — otherwise new installs and upgraded installs diverge and bugs appear only in production.

### 4.2 New and changed tables

```sql
-- ── v2: Accounts ────────────────────────────────────────────
CREATE TABLE accounts (
  id             TEXT PRIMARY KEY,
  name           TEXT    NOT NULL,
  type           TEXT    NOT NULL,   -- cash|bank|credit_card|e_wallet|savings|investment
  openingBalance REAL    NOT NULL DEFAULT 0,
  currencyCode   TEXT    NOT NULL DEFAULT 'IDR',
  icon           TEXT    NOT NULL,
  color          TEXT    NOT NULL,
  creditLimit    REAL,               -- credit cards only
  isArchived     INTEGER NOT NULL DEFAULT 0,
  includeInTotal INTEGER NOT NULL DEFAULT 1,
  sortOrder      INTEGER NOT NULL DEFAULT 0,
  createdAt      TEXT    NOT NULL
);

ALTER TABLE transactions ADD COLUMN accountId  TEXT;
ALTER TABLE transactions ADD COLUMN transferId TEXT;   -- pairs the two legs
ALTER TABLE transactions ADD COLUMN isTransfer INTEGER NOT NULL DEFAULT 0;
CREATE INDEX idx_transactions_accountId ON transactions(accountId);

-- ── v3: Merchants, tags, attachments, sub-categories ───────
ALTER TABLE transactions ADD COLUMN merchant TEXT;
ALTER TABLE categories   ADD COLUMN parentId TEXT;     -- 2 levels max

CREATE TABLE tags (
  id TEXT PRIMARY KEY, name TEXT NOT NULL UNIQUE,
  color TEXT NOT NULL, createdAt TEXT NOT NULL
);
CREATE TABLE transaction_tags (
  transactionId TEXT NOT NULL, tagId TEXT NOT NULL,
  PRIMARY KEY (transactionId, tagId),
  FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE,
  FOREIGN KEY (tagId)         REFERENCES tags(id)         ON DELETE CASCADE
);
CREATE TABLE attachments (
  id TEXT PRIMARY KEY, transactionId TEXT NOT NULL,
  relativePath TEXT NOT NULL,          -- relative, never absolute
  createdAt TEXT NOT NULL,
  FOREIGN KEY (transactionId) REFERENCES transactions(id) ON DELETE CASCADE
);

-- ── v4: Goals & debts ───────────────────────────────────────
CREATE TABLE goals (
  id TEXT PRIMARY KEY, name TEXT NOT NULL,
  targetAmount REAL NOT NULL, targetDate TEXT,
  linkedAccountId TEXT, icon TEXT NOT NULL, color TEXT NOT NULL,
  isCompleted INTEGER NOT NULL DEFAULT 0, createdAt TEXT NOT NULL
);
CREATE TABLE debts (
  id TEXT PRIMARY KEY, type TEXT NOT NULL,  -- lent|borrowed
  counterparty TEXT NOT NULL, principal REAL NOT NULL,
  dueDate TEXT, isSettled INTEGER NOT NULL DEFAULT 0,
  note TEXT, createdAt TEXT NOT NULL
);
ALTER TABLE transactions ADD COLUMN goalId TEXT;
ALTER TABLE transactions ADD COLUMN debtId TEXT;

-- ── Budget upgrades (v4) ────────────────────────────────────
ALTER TABLE budgets ADD COLUMN period       TEXT    NOT NULL DEFAULT 'monthly';
ALTER TABLE budgets ADD COLUMN rolloverMode TEXT    NOT NULL DEFAULT 'none'; -- none|positive|full
ALTER TABLE budgets ADD COLUMN name         TEXT;    -- for group budgets
CREATE TABLE budget_categories (              -- replaces the 1:1 UNIQUE(categoryId)
  budgetId TEXT NOT NULL, categoryId TEXT NOT NULL,
  PRIMARY KEY (budgetId, categoryId)
);
```

> ⚠️ `budgets.categoryId` currently carries `UNIQUE`. SQLite cannot drop a constraint with `ALTER TABLE`, so relaxing it to support group budgets requires the **12-step table rebuild**: create `budgets_new` → `INSERT INTO budgets_new SELECT …` → `DROP TABLE budgets` → `ALTER TABLE budgets_new RENAME TO budgets`, wrapped in a transaction. This is the one place where a `DROP TABLE` is legitimate — the data has already been copied. Test it against a populated v1 database before shipping.

### 4.3 Backfill for existing users

Migration v2 must not leave existing transactions orphaned:

```dart
Future<void> _migrateV2Accounts(Database db) async {
  await db.transaction((txn) async {
    await txn.execute(_createAccountsTable);
    await txn.execute('ALTER TABLE transactions ADD COLUMN accountId TEXT');
    await txn.execute('ALTER TABLE transactions ADD COLUMN transferId TEXT');
    await txn.execute(
      'ALTER TABLE transactions ADD COLUMN isTransfer INTEGER NOT NULL DEFAULT 0',
    );

    // Every pre-existing transaction belongs to an implicit single wallet.
    const defaultId = 'account_default';
    await txn.insert('accounts', {
      'id': defaultId, 'name': 'My Wallet', 'type': 'cash',
      'openingBalance': 0, 'currencyCode': 'IDR',
      'icon': 'wallet', 'color': '#C87941',
      'isArchived': 0, 'includeInTotal': 1, 'sortOrder': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await txn.update('transactions', {'accountId': defaultId},
        where: 'accountId IS NULL');
  });
}
```

The user opens the update and sees their existing balance sitting in "My Wallet" — nothing lost, nothing to reconcile.

### 4.4 Aggregation invariant

Once transfers exist, **every** income/expense aggregate must exclude them. Centralise it rather than repeating the predicate:

```dart
// lib/repositories/transaction_repository.dart
static const String _excludeTransfers = 'isTransfer = 0';
// every SUM/GROUP BY query in analytics, budgets, and the dashboard appends this
```

A missed `isTransfer = 0` is the classic bug of this feature: moving Rp 5M from BCA to Cash reports Rp 5M of income *and* Rp 5M of expenses, and blows the user's Food budget for reasons they cannot explain.

---

## 5. Implementation Playbook

### 5.1 Packages to add

| Package | Purpose | Notes |
| :--- | :--- | :--- |
| `share_plus` | Share exports/backups | Fixes the inaccessible-file bug in 1.2 |
| `file_picker` | Import backups & CSV | |
| `image_picker` | Receipt capture | |
| `local_auth` | Biometric unlock | Pair with a PIN fallback |
| `flutter_secure_storage` | PIN hash storage | Never `SharedPreferences` for secrets |
| `flutter_local_notifications` | Bill reminders, budget alerts | Needs `timezone` for scheduling |
| `archive` | Zip backup bundles | Pure Dart, no platform channels |
| `csv` | Robust CSV read/write | Hand-rolled escaping already broke once |
| `google_mlkit_text_recognition` | Receipt OCR (Tier 3) | On-device; adds ~15 MB to APK — consider a split build |

Everything else is already in `pubspec.yaml`; `fl_chart` covers every chart in §3.5.

### 5.2 Architecture guidance for the new surface area

The Provider + Repository pattern is holding up well. Keep it, with three adjustments:

1. **Cross-provider coupling is growing.** `add_transaction_screen.dart` already reads five providers and manually re-triggers `budgetProvider` and `analyticsProvider` reloads after a save. As accounts, goals, and debts join, this becomes unmaintainable. Introduce a lightweight event bus or `ChangeNotifierProxyProvider` so that `TransactionProvider` mutations broadcast a single `onTransactionsChanged` that dependent providers subscribe to — the screen should not be orchestrating cache invalidation.

2. **Move aggregation into SQL.** `BudgetProvider._calculateStatuses` and the analytics provider aggregate in Dart over loaded lists. At a few thousand transactions this becomes visibly slow on mid-range Android. `SUM()/GROUP BY` in the repository, with the date-range predicate pushed down, is both faster and less code.

3. **Adopt `sqflite`'s `batch()`** for the recurring generator and any import path. Generating 12 months of a daily recurring template is currently 365 individual inserts.

### 5.3 Worked example — transfers

```dart
// lib/providers/transaction_provider.dart
Future<void> addTransfer({
  required String fromAccountId,
  required String toAccountId,
  required double amount,
  required DateTime date,
  String? note,
}) async {
  if (fromAccountId == toAccountId) {
    throw ArgumentError('Source and destination must differ');
  }
  final transferId = _uuid.v4();
  final now = DateTime.now();

  // Two legs, one id. Both excluded from income/expense aggregates.
  await _repository.insertBatch([
    TransactionModel(
      id: _uuid.v4(), type: 'expense', amount: amount,
      categoryId: SeedData.transferCategoryId, accountId: fromAccountId,
      transferId: transferId, isTransfer: true,
      date: date, note: note, createdAt: now, updatedAt: now,
    ),
    TransactionModel(
      id: _uuid.v4(), type: 'income', amount: amount,
      categoryId: SeedData.transferCategoryId, accountId: toAccountId,
      transferId: transferId, isTransfer: true,
      date: date, note: note, createdAt: now, updatedAt: now,
    ),
  ]);
  notifyListeners();
}
```

Deleting either leg must delete both — handle it in the repository by `DELETE WHERE transferId = ?`, not in the UI.

### 5.4 Worked example — budget pace indicator (§2.11)

Cheap, and it makes every existing progress bar meaningful:

```dart
/// 1.0 = spending exactly in step with elapsed time.
/// >1.0 = burning faster than the period allows.
double get pace {
  final elapsed = DateTime.now().difference(periodStart).inDays + 1;
  final total   = periodEnd.difference(periodStart).inDays + 1;
  final timeRatio = (elapsed / total).clamp(0.01, 1.0);
  return ratio / timeRatio;
}

String get paceLabel => pace > 1.15
    ? 'Ahead of pace'          // warning colour
    : pace < 0.85 ? 'Under pace' : 'On track';
```

Render it as a thin vertical tick on the existing `BudgetProgressBar` at the `timeRatio` position — the user instantly sees whether the bar is where it should be.

### 5.5 Testing the money math

Before this much surface area lands, add unit tests for the logic that silently corrupts numbers when it breaks:

- Payday period boundaries — payday 31 in February; payday 1; leap years.
- Recurring generation — monthly on the 31st, DST transitions, catching up after the app was closed for 3 months, and **idempotency** (running the generator twice must not double-post).
- Budget ratios — zero-amount budgets, over-100% clamping, rollover carry-forward.
- Transfer exclusion — income/expense totals must be unchanged by any transfer.
- Migrations — build a v1 DB fixture, run `_onUpgrade`, assert the schema matches a fresh `_onCreate` and that no rows were lost.

`sqflite_common_ffi` is already a dependency, so all of this runs headless on the desktop test runner.

---

## 6. Release Roadmap

### v1.1 — Foundation & Trust (~2 weeks)
*Nothing new for the user to look at, everything that makes shipping safe.*
- [ ] Wire `onUpgrade` + `PRAGMA foreign_keys` (§4.1) — **blocking for every later release**
- [ ] Fix CSV export (category names, share sheet); add backup/restore zip (§2.5)
- [ ] Mount the dead `BudgetOverview` on the dashboard (§1.2 #3)
- [ ] Real search: merchant/note/category/amount + date-range and category filters (§2.3)
- [ ] Finish localisation; remove the debug reset tile; add Settings to the More hub
- [ ] Unit tests for period, recurring, and budget math (§5.5)

### v1.2 — Accounts (~3 weeks)
- [ ] `accounts` table + v2 migration with backfill (§4.3)
- [ ] Account CRUD, carousel on Home, account chip in the entry form
- [ ] Transfers with `isTransfer` exclusion audited across every aggregate (§4.4)
- [ ] Net worth card replacing the single balance
- [ ] Credit-card semantics (inverted display, excluded from available cash)

### v1.3 — Daily Driver (~3 weeks)
- [ ] Merchant field + autocomplete + smart category/account prefill (§2.2)
- [ ] Quick-add sheet with calculator keypad (§2.14)
- [ ] Receipt attachments (§2.4)
- [ ] Tags with `#hashtag` parsing (§2.12)
- [ ] App lock: biometrics + PIN + balance blur (§2.6)
- [ ] Navigation restructure to Home / Records / + / Insights / More (§3.1)

### v1.4 — Intelligence (~3 weeks)
- [ ] Cashflow, category trends, burn rate, heatmap (§2.9)
- [ ] Subscriptions dashboard + local notifications for upcoming bills (§2.10)
- [ ] Budget upgrades: periods, rollover, groups, templates, pace indicator (§2.11)
- [ ] Sub-categories (§2.13)

### v1.5 — Goals & Debt (~2 weeks)
- [ ] Savings goals with projected completion (§2.7)
- [ ] Debt/loan ledger with repayment linking (§2.8)
- [ ] Monthly recap card, shareable as an image

### v2.0 — Beyond local (scoped separately)
- [ ] Receipt OCR (on-device ML Kit)
- [ ] Cloud sync + multi-device (Supabase; only after backup/restore has proven the export path)
- [ ] Multi-currency with stored historical rates
- [ ] Home-screen widget

---

### The one-paragraph summary

Finta's V1 is a well-architected, genuinely complete single-wallet expense tracker — the Provider/Repository separation is clean and the warm design system is a real differentiator against generic Material clones. What it lacks is not polish but **scope**: it models one pot of money, one dimension of classification (category), one time horizon (this period), and one copy of the data (this phone). The four moves that close the distance to Money Manager or Wallet, in order, are: **make migrations safe**, **make the data escapable (backup/export)**, **add accounts and transfers**, and **add merchant + fast entry**. Trends, goals, debts, and subscriptions are valuable but all sit downstream of those four. Cloud sync — the headline item on the current V2 roadmap — should be last, not first: backup/restore removes most of its urgency at a fraction of its cost.
