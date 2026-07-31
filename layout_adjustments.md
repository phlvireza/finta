# Finta — Layout Adjustments

Third document in the set. [`feature_gap_analysis.md`](feature_gap_analysis.md) covers *what to build*, [`improvement_plan.md`](improvement_plan.md) covers *what to fix in the logic*. **This one covers what to change in the UI layout** — screen composition, information hierarchy, and component consistency — benchmarked against **Money Manager (Realbyte)**, **Wallet by BudgetBakers**, **Money Lover**, **Bluecoins**, **Spendee**, **Monarch**, **Copilot**, **YNAB**, and **Cashew**.

Every "today" claim below was read out of the current source, including the changes just shipped in v1.1.

---

## Table of Contents

1. [Benchmark comparison at a glance](#1-benchmark-comparison-at-a-glance)
2. [Tier A — Structural](#tier-a--structural)
3. [Tier B — Screen-level](#tier-b--screen-level)
4. [Tier C — Component consistency](#tier-c--component-consistency)
5. [Before / after wireframes](#5-before--after-wireframes)
6. [Sequencing](#6-sequencing)

---

## 1. Benchmark comparison at a glance

| Pattern | What the benchmarks do | Finta today | Verdict |
| :--- | :--- | :--- | :--- |
| Headline number | Running balance / net worth across accounts | Period income − expense, labelled "Total Balance" | ❌ **Mislabelled** (A-1) |
| Period navigation | Swipe or tap ◀ ▶ to any past period | Static date-range text, current period only | ❌ Missing (A-2) |
| Nav destinations | 4 + centre FAB; config in a "More" hub | 5 with a dummy slot; Settings on 1 of 4 tabs | ❌ (A-3) |
| Transaction row label | Merchant first, category as metadata | Category name only | ❌ (B-3) |
| Date group headers | Header + per-day subtotal | Bare label ("Today") | ❌ (B-4) |
| At-a-glance home | Balance → accounts → budgets → upcoming → recent | Balance → summary → budgets → **calendar** → recent | ⚠️ Calendar misplaced (A-4) |
| Entry speed | 3-tap quick-add sheet w/ numpad | Full-screen form, no autofocus | ⚠️ (B-5) |
| Budget bar | Progress + time-pace reference | Progress only | ⚠️ (B-6) |
| Empty states | Illustration + primary CTA | Icon + text, no CTA (slot exists, unused) | ⚠️ (C-1) |
| Row component | One tile reused everywhere | Two divergent implementations | ⚠️ (C-2) |
| Loading | Skeleton placeholders | `CircularProgressIndicator` | ⚠️ (C-5) |
| Warm, non-aggressive palette | — | Already good, honours the PRD | ✅ Keep |
| Tabular figures on amounts | — | `AppTypography.amountStyle` used consistently | ✅ Keep |
| Card style (border, no shadow) | — | Consistent via `cardTheme` | ✅ Keep |

---

## Tier A — Structural

### A-1 · "Total Balance" is not a balance

**The single highest-impact layout defect in the app.**

[balance_card.dart:42-53](lib/screens/dashboard/widgets/balance_card.dart#L42-L53) renders `transactions.balance`, which is defined as `_totalIncome - _totalExpense` **for the current payday period only** ([transaction_provider.dart:32](lib/providers/transaction_provider.dart#L32)). It is labelled `loc.totalBalance` → *"Total Balance"* / *"Total Saldo"*.

So a user who has been tracking for eight months and happens to spend more than they earned this period sees:

```
Total Balance
- Rp 1.240.000        ← reads as "you have negative money"
Jul 25, 2026 — Aug 24, 2026
```

They do not have negative money. They have a negative *cash flow this period*. Every benchmark app either shows a true running balance (Money Manager, Bluecoins, Wallet) or labels the period figure honestly ("Cash flow", "This month net").

**Adjustment — two options, pick by whether accounts have shipped:**

*Before accounts (do now, cheap):* relabel and restructure so the hierarchy states what the number actually is.

```
┌──────────────────────────────────┐
│  NET THIS PERIOD                 │   ← was "Total Balance"
│  − Rp 1.240.000                  │
│  Jul 25 – Aug 24        ◀  ▶     │   ← + period nav (A-2)
└──────────────────────────────────┘
```

Add `netThisPeriod` to both ARB files; keep `totalBalance` for when a real balance exists.

*After accounts land:* the card becomes **Net Worth** (sum of account balances, all-time) with the period net demoted to a subline — matching Monarch/Copilot and the layout in [`feature_gap_analysis.md` §3.2](feature_gap_analysis.md).

Also shorten the date range: `formatFull` twice yields *"Jul 25, 2026 — Aug 24, 2026"*. Drop the year when both ends are in the current year → *"Jul 25 – Aug 24"*.

---

### A-2 · No way to view a previous period

The dashboard is hard-wired to `getCurrentPeriod(payday)` ([balance_card.dart:23](lib/screens/dashboard/widgets/balance_card.dart#L23), [transaction_provider.dart:46](lib/providers/transaction_provider.dart#L46)). There is no UI to reach last month. The data is all there — `getPreviousPeriod` exists and is already used by analytics — but the user cannot see it on the home screen.

Every benchmark makes this a primary gesture: Money Manager and Bluecoins put ◀ ▶ arrows in the app bar, Wallet and Spendee let you swipe the balance card horizontally.

**Adjustment:** add a period offset to `TransactionProvider` and drive it from arrows on the balance card.

```dart
// transaction_provider.dart
int _periodOffset = 0;   // 0 = current, -1 = previous, …

Future<void> loadTransactions({required int payday, int offset = 0}) async {
  _periodOffset = offset;
  var period = AppDateUtils.getCurrentPeriod(payday);
  for (var i = 0; i > offset; i--) {
    period = AppDateUtils.getPreviousPeriod(period);
  }
  _period = period;
  …
}
```

Disable ▶ at `offset == 0` so the user can't page into an empty future, and show a "Back to current" affordance whenever `offset != 0`.

---

### A-3 · Navigation: 5 slots, one of them fake

[app.dart:31-37](lib/app/app.dart#L31-L37) builds an `IndexedStack` where index 2 is a `SizedBox()` placeholder behind the centre FAB, and `_onTabTapped` special-cases index 2 ([app.dart:76-83](lib/app/app.dart#L76-L83)). Meanwhile **Budgets** occupies a top-level tab despite being a low-frequency configuration surface, and **Settings** is reachable only from the dashboard app bar ([dashboard_screen.dart:31-41](lib/screens/dashboard/dashboard_screen.dart#L31-L41)) — a dead end on the other three tabs.

**Adjustment — 4 real destinations + FAB:**

```
🏠 Home    📋 Records    [ + ]    📊 Insights    ⋯ More
```

`More` is a simple hub screen listing Budgets, Categories, Recurring, Export, and Settings. This removes the fake slot, gives every current and planned surface (accounts, goals, debts, subscriptions) a home without adding tabs, and fixes the Settings dead end permanently. It is also exactly what Money Manager, Wallet, and Money Lover converged on.

---

### A-4 · The calendar sits in prime real estate

Dashboard order is currently `BalanceCard → SummaryRow → BudgetOverview → DashboardCalendar → RecentTransactions` ([dashboard_screen.dart:79-89](lib/screens/dashboard/dashboard_screen.dart#L79-L89)).

`DashboardCalendar` renders a full `table_calendar` month grid — roughly 300–350 px. It is a *browsing* tool (tap a day → bottom sheet of that day's transactions), and it pushes recent transactions well below the fold on a typical phone. No benchmark app puts a month grid in the middle of the home scroll; they put it behind a list/calendar toggle on the transactions screen (Money Manager, Bluecoins) or on its own tab.

**Adjustment:** move `DashboardCalendar` to the Records screen as a view-mode toggle in the app bar (`[☰ list] [📅 calendar]`), and use the freed space for the **Upcoming** section (next recurring charges), which is currently invisible in the UI despite the data existing.

```dart
// dashboard_screen.dart — after the move
children: const [
  BalanceCard(),
  SizedBox(height: AppConstants.spacingLg),
  SummaryRow(),
  SizedBox(height: AppConstants.spacingXxxl),
  BudgetOverview(),
  SizedBox(height: AppConstants.spacingXxxl),
  UpcomingBills(),          // new — see feature_gap_analysis §2.10
  SizedBox(height: AppConstants.spacingXxxl),
  RecentTransactions(),
],
```

---

## Tier B — Screen-level

### B-1 · The dashboard app bar wastes the most valuable row

[dashboard_screen.dart:23-42](lib/screens/dashboard/dashboard_screen.dart#L23-L42) renders the title *"Finta"* plus a settings gear. The user knows which app they opened. Benchmarks use this row for period navigation (Money Manager), a greeting + avatar (Monarch), or a search field (Copilot).

**Adjustment:** replace the static title with the **period selector** from A-2, and move the gear into the More tab (A-3).

---

### B-2 · Budgets screen: the chart never scrolls away

[manage_budgets_screen.dart:43-97](lib/screens/budgets/manage_budgets_screen.dart#L43-L97) is a `Column` of `_BudgetChart` (a ~180 px donut plus `spacingXl` padding on all sides) then an `Expanded` `ListView`. The donut is pinned; on a small screen the actual budget list is squeezed into what's left and never regains the space.

**Adjustment:** make the chart the first item *inside* the scroll view, or use a `SliverAppBar` with `FlexibleSpaceBar` so it collapses as the user scrolls into the list.

Two further defects inside `_BudgetChart` while you're there:

- **Line [169](lib/screens/budgets/manage_budgets_screen.dart#L169)** is a no-op ternary — both branches return `theme.colorScheme.surfaceVariant`, and `surfaceVariant` is deprecated (the analyzer flags it). Collapse to `theme.colorScheme.surfaceContainerHighest`.
- **Line [168](lib/screens/budgets/manage_budgets_screen.dart#L168)** paints the spent arc `AppColors.warning` **unconditionally**. A user at 20% of budget sees an amber ring implying a warning. Drive the colour off the aggregate ratio using the same thresholds as everything else (`AppConstants.budgetWarningThreshold` / `budgetExceededThreshold`).

---

### B-3 · Transaction rows lead with the category, not the payee

Both row implementations render `category?.name` as the title ([transaction_tile.dart:77](lib/screens/transactions/widgets/transaction_tile.dart#L77), [recent_transactions.dart:106](lib/screens/dashboard/widgets/recent_transactions.dart#L106)) with the optional note underneath. Ten lunches produce ten identical rows reading "Food & Drinks".

**Adjustment:** once `merchant` exists (already added to the schema in migration v2), make the title `merchant ?? category.name` and demote the category to the subtitle alongside the account. This is the single change that makes the ledger scannable, and it is why Copilot and Monarch structure the row this way.

```
🍔  Starbucks                        − Rp 45.000
    Food & Drinks · BCA
```

---

### B-4 · Date groups have no subtotals

`recent_transactions.dart:53-56` and `transaction_history_screen.dart:193-196` both render the group label alone. Money Manager, Bluecoins, and Wallet all put the day's net in the header — it is the cheapest possible analytical affordance.

**Adjustment:**

```
── TODAY ─────────────────── − Rp 245.000 ──
── YESTERDAY ─────────────── + Rp 8.255.000 ──
```

`getGroupedTransactions` already returns `Map<String, List<TransactionModel>>`, so the subtotal is a `fold` over the existing value list — no new queries.

---

### B-5 · Add-transaction form is slower than it needs to be

[add_transaction_screen.dart:214-302](lib/screens/transactions/add_transaction_screen.dart#L214-L302) orders the form: type toggle → amount → category → date → note → recurring. The amount field is not autofocused, so every entry costs an extra tap before the keyboard appears.

**Adjustments (ordered by value):**

1. **Autofocus the amount field.** One line, removes a tap from the most repeated action in the app.
2. **Quick-add sheet** as the default FAB target, with the full-screen form kept behind a "more options" affordance and for editing — see the wireframe in [`feature_gap_analysis.md` §3.4](feature_gap_analysis.md).
3. **Move the date field up** next to the amount. Date is changed far more often than the note, but currently sits below the category picker.

---

### B-6 · Budget bars have no time reference

`BudgetProgressBar` ([budget_progress_bar.dart:73-81](lib/screens/budgets/widgets/budget_progress_bar.dart#L73-L81)) and the dashboard's `_BudgetItem` both render a bare `LinearProgressIndicator`. "85% used" means something completely different on day 3 than on day 27, and the UI cannot tell them apart.

**Adjustment:** overlay a thin vertical tick at the elapsed-time position, plus a pace label. The maths is in [`improvement_plan.md` §5.4](improvement_plan.md).

```
🍔 Food & Drinks                    85% used
   ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓┊░░░  ← tick = 62% of period elapsed
   Rp 1.7M spent      Ahead of pace · Rp 300k left
```

---

### B-7 · Analytics truncates silently and hides the yearly view

- `CategoryRankList` hard-caps at five rows (`data.take(5)`, [category_rank_list.dart:24](lib/screens/analytics/widgets/category_rank_list.dart#L24)) with no indication that more exist and no "See all". A user with 12 expense categories cannot see 7 of them.
- The period dropdown offers only Weekly / Bi-Weekly / Monthly ([analytics_screen.dart:134-138](lib/screens/analytics/analytics_screen.dart#L134-L138)) even though `AnalyticsPeriod` defines `yearly`; the yearly report is instead hidden behind an unlabelled bar-chart icon in the app bar.

**Adjustment:** add a "Show all (12)" row under the rank list, and promote the period control to a segmented `[ Week | Month | Quarter | Year ]` row that includes Year — folding the separate report screen in as the Year view, per [`feature_gap_analysis.md` §3.5](feature_gap_analysis.md).

---

### B-8 · The dashboard comparison can silently change meaning

`_SummaryCard` compares `transactions.totalIncome` (always the **payday period**) against `analytics.previousTotalIncome` ([summary_row.dart:31](lib/screens/dashboard/widgets/summary_row.dart#L31), [:42](lib/screens/dashboard/widgets/summary_row.dart#L42)) — but that value is computed from whatever period the user last selected **on the Analytics screen** ([analytics_provider.dart:113-137](lib/providers/analytics_provider.dart#L113-L137)).

Default is `monthly`, so it usually matches. But if the user switches Analytics to Weekly, the dashboard's "% vs last" quietly starts comparing a month against a week — with no visible change to the label. It is a display bug that only manifests after visiting another screen.

**Adjustment:** have the dashboard compute its own previous-period totals against its own period (and against the offset from A-2), rather than borrowing `AnalyticsProvider`'s state. Label it explicitly: *"vs last period"* → *"vs Jun 25 – Jul 24"*.

---

## Tier C — Component consistency

These are small, mechanical, and collectively responsible for the app feeling less coherent than its design system deserves.

### C-1 · Empty states are dead ends

`EmptyState` exposes an `action` slot ([empty_state.dart:9](lib/widgets/empty_state.dart#L9), [:56-59](lib/widgets/empty_state.dart#L56-L59)) — and **not one of the five call sites passes it** (analytics, budgets, recent transactions, recurring, history). A new user's first screen is an icon, a sentence, and nothing to tap.

**Adjustment:** give every empty state a primary CTA. "No budgets yet" → **Create your first budget**. "No transactions yet" → **Add a transaction**. The widget already supports it.

### C-2 · Two transaction rows, drifting apart

The same visual element exists twice:

| | [transaction_tile.dart](lib/screens/transactions/widgets/transaction_tile.dart) | [recent_transactions.dart](lib/screens/dashboard/widgets/recent_transactions.dart) (inline) |
| :--- | :--- | :--- |
| Icon box | 48×48, `radiusMd` | 40×40, `radiusSm` |
| Icon size | 24 | 20 |
| Title style | `titleMedium` (15/w500) | `titleSmall` (14/w500) |
| Amount size | 15 | 14 |
| Recurring badge | 14 px | 12 px |
| Horizontal padding | `spacingLg` | none (inherits) |

Same information, two implementations, already visibly divergent. Any future change (merchant title, account chip, tags) must be made twice or the screens drift further.

**Adjustment (DRY):** delete the inline row and reuse `TransactionTile` with a `dense` flag:

```dart
class TransactionTile extends StatelessWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final bool dense;   // dashboard = true, history = false
  …
  double get _iconSize => dense ? 40 : 48;
}
```

### C-3 · Two different meanings for the same budget bar colour

For a budget in its **normal** state, `BudgetProgressBar` paints the bar `theme.colorScheme.primary` (terracotta, [budget_progress_bar.dart:36](lib/screens/budgets/widgets/budget_progress_bar.dart#L36)) while the dashboard's `_BudgetItem` paints it `category.colorValue` ([budget_overview.dart:56](lib/screens/dashboard/widgets/budget_overview.dart#L56)). Warning and exceeded states agree; only the normal state diverges — so the same budget is two different colours on two screens.

**Adjustment:** pick one (category colour is more informative and matches Wallet/Spendee) and extract the threshold→colour mapping into a single helper both widgets call. Right now that if/else if/else ladder is duplicated verbatim in both files.

```dart
// lib/core/constants/app_colors.dart
static Color budgetBarColor(BudgetStatus status, Color categoryColor, bool isDark) => …
```

### C-4 · FAB shape is inconsistent across screens

[app.dart:120](lib/app/app.dart#L120) forces `shape: const CircleBorder()`, but `floatingActionButtonTheme` specifies `RoundedRectangleBorder(radiusLg)` ([app_theme.dart:109-111](lib/core/theme/app_theme.dart#L109-L111)), which is what the Budgets and Categories FABs render. The user sees a circular FAB on the main shell and a squircle FAB on sub-screens.

**Adjustment:** delete the local `shape` override and let the theme decide — or change the theme to `CircleBorder()` if the circle is the intent. Either way, one source of truth.

### C-5 · Spinners where skeletons belong

`CircularProgressIndicator` is used for full-screen loads on the app shell ([app.dart:99](lib/app/app.dart#L99)), analytics ([analytics_screen.dart:98](lib/screens/analytics/analytics_screen.dart#L98)), and history ([transaction_history_screen.dart:161](lib/screens/transactions/transaction_history_screen.dart#L161)). On a data-dense screen a centred spinner reads as a stall; every benchmark uses skeleton placeholders that preserve the page's shape.

**Adjustment:** a small `SkeletonBox` widget (grey rounded rect with a subtle shimmer) composed into card/row-shaped placeholders.

### C-6 · FAB clearance is a magic number, copy-pasted

`EdgeInsets.only(bottom: 100)` appears in [analytics_screen.dart:121](lib/screens/analytics/analytics_screen.dart#L121), [manage_budgets_screen.dart:51](lib/screens/budgets/manage_budgets_screen.dart#L51), [transaction_history_screen.dart:178](lib/screens/transactions/transaction_history_screen.dart#L178), plus `fromLTRB(…, 100)` in the dashboard and settings — and `bottom: 80` in [manage_categories_screen.dart:88](lib/screens/categories/manage_categories_screen.dart#L88), which is simply wrong by 20 px. [PRD.md §8](PRD.md) explicitly forbids magic numbers.

**Adjustment:**

```dart
// app_constants.dart
/// Bottom padding so scrollable content clears the FAB and nav bar.
static const double fabClearance = 100.0;
```

### C-7 · Deprecated `surfaceVariant` (8 call sites)

`flutter analyze` flags `colorScheme.surfaceVariant` as deprecated in `manage_budgets_screen`, `category_form`, `icon_picker`, `add_transaction_screen`, `category_picker` (×2), `date_picker_field`, and `recurring_toggle`. The theme already exposes the replacement as `surfaceContainerHighest` ([app_theme.dart:58](lib/core/theme/app_theme.dart#L58)).

**Adjustment:** mechanical find-and-replace to `surfaceContainerHighest`; clears 8 of the 22 outstanding analyzer issues.

---

## 5. Before / after wireframes

### Home

```
        BEFORE (today)                        AFTER
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ Finta                    ⚙   │   │ ◀   Jul 25 – Aug 24      ▶   │  A-2, B-1
├──────────────────────────────┤   ├──────────────────────────────┤
│ ┌──────────────────────────┐ │   │ ┌──────────────────────────┐ │
│ │ Total Balance            │ │   │ │ NET THIS PERIOD          │ │  A-1
│ │ − Rp 1.240.000     ← lie │ │   │ │ − Rp 1.240.000           │ │
│ │ Jul 25, 2026 — Aug 24,…  │ │   │ │ Net worth  Rp 24.850.000 │ │
│ └──────────────────────────┘ │   │ └──────────────────────────┘ │
│ ┌─────────┐ ┌─────────┐      │   │ ┌─────────┐ ┌─────────┐      │
│ │ Income  │ │ Expense │      │   │ │ Income  │ │ Expense │      │
│ └─────────┘ └─────────┘      │   │ └─────────┘ └─────────┘      │  B-8
│                              │   │                              │
│ Budgets                      │   │ Budgets            See all → │
│ 🍔 ▓▓▓▓▓▓▓▓░░  85%           │   │ 🍔 ▓▓▓▓▓▓▓┊░░  85% ⚠ ahead   │  B-6
│                              │   │                              │
│ ┌──────────────────────────┐ │   │ Upcoming           See all → │  A-4
│ │                          │ │   │ 📺 Netflix  in 2d   186.000  │
│ │   MONTH CALENDAR GRID    │ │   │ 🏠 Rent     in 6d  3.500.000 │
│ │   (~330px, browsing UI   │ │   │                              │
│ │    in an at-a-glance     │ │   │ Recent             See all → │
│ │    surface)              │ │   │ 🍔 Starbucks        −45.000  │  B-3
│ │                          │ │   │    Food & Drinks · BCA       │
│ └──────────────────────────┘ │   │ 💰 Salary        +8.500.000  │
│                              │   │    Income · BCA              │
│ Recent  ← below the fold     │   │                              │
├──────────────────────────────┤   ├──────────────────────────────┤
│ 🏠  📋  [+]  📊  💰          │   │ 🏠  📋  [+]  📊  ⋯           │  A-3
└──────────────────────────────┘   └──────────────────────────────┘
```

### Records

```
        BEFORE                                AFTER
┌──────────────────────────────┐   ┌──────────────────────────────┐
│ History                      │   │ Records      🔍  ☰filter  📅 │  A-4, B-7
│ ┌──────────────────────────┐ │   │ ┌──────────────────────────┐ │
│ │ 🔍 Search notes…         │ │   │ │ 🔍 merchant, category…   │ │
│ └──────────────────────────┘ │   │ └──────────────────────────┘ │
│ [ All ][Expense][ Income ]   │   │ [Jul 25–Aug 24 ×][Expense ×] │
│                              │   │ 12 transactions · Rp 1.24M   │
│ Today                        │   │ ── TODAY ────── −Rp 245.000 ─│  B-4
│ 🍔 Food & Drinks    −45.000  │   │ 🍔 Starbucks         −45.000 │  B-3
│ 🚗 Transport       −200.000  │   │    Food & Drinks · BCA       │
└──────────────────────────────┘   └──────────────────────────────┘
```

---

## 6. Sequencing

Ordered so each step is independently shippable. Tier C is deliberately first — it is a day of mechanical work that makes every later change land in a consistent codebase.

| # | Change | Items | Effort |
| :--- | :--- | :--- | :--- |
| 1 | **Consistency sweep** | C-2 unify tile · C-3 shared budget colour · C-4 FAB shape · C-6 `fabClearance` · C-7 `surfaceVariant` | S |
| 2 | **Honest headline** | A-1 relabel + short date range · B-8 dashboard owns its comparison | S |
| 3 | **Period navigation** | A-2 offset + ◀ ▶ · B-1 app bar hosts the selector | M |
| 4 | **Home recomposition** | A-4 calendar → Records · Upcoming section · C-1 empty-state CTAs | M |
| 5 | **Navigation restructure** | A-3 four destinations + More hub | M |
| 6 | **Screen polish** | B-2 budgets chart scrolls + colour fix · B-7 analytics show-all + Year · B-5 autofocus | S |
| 7 | **Row & bar upgrades** | B-3 merchant-first (needs merchant UI) · B-4 day subtotals · B-6 pace tick | M |
| 8 | **Perceived performance** | C-5 skeleton loaders | S |

Steps 1, 2, 6 and 8 depend on nothing and could ship this week. Step 7's merchant half depends on the merchant field's entry UI; the `merchant` column already exists from migration v2, so nothing is blocked at the schema level.

---

### Summary

The visual system is genuinely good — warm palette, tabular figures, bordered flat cards, consistent spacing scale — and it should be kept as-is. The layout problems are not about styling; they are about **hierarchy and honesty**: the headline number claims to be something it isn't (A-1), the most valuable screen row is spent on the app's own name (B-1), a browsing widget occupies the at-a-glance slot (A-4), the user cannot navigate to last month at all (A-2), and one navigation slot is a placeholder (A-3). Fix those five and Finta reads like Money Manager or Wallet rather than a well-styled MVP — the remaining Tier C items are the mechanical debt that keeps it feeling that way as it grows.
