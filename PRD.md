# Finta — Financial Tracking App
## Product & Architecture Specification (MVP)

---

## 1. Product Vision

Finta is a personal financial tracking app built with Flutter. It helps users log income and expenses quickly, see where their money goes, and stay on top of their budget — all without connecting to a bank or creating an account.

The app is local-first (SQLite via `sqflite`). No server, no login. A short onboarding flow gets users set up on first launch, then they're straight into tracking.

---

## 2. Core Features

### A. Dashboard (Home Screen)

- **Current Balance** — total income minus total expenses for the active period, displayed prominently at the top.
- **Income / Expense Summary** — two cards below the balance showing total income and total expenses for the current month.
- **Recent Transactions** — a scrollable list of the 10 most recent transactions, grouped by date with sticky headers ("Today", "Yesterday", "Jul 20").

### B. Transaction Logging

- **Add Income / Add Expense** — accessed via the floating `+` button on the bottom navigation bar. User picks "Income" or "Expense" first, then fills the form.
- **Transaction Form Fields:**
  1. **Amount** (required)
     - Numeric-only input. No letters, no special characters beyond the decimal separator.
     - Auto-formats with thousand-separator commas as the user types (e.g. typing `1500000` displays `1,500,000`).
     - Stored internally as a raw integer/double without formatting.
  2. **Category** (required)
     - User must select a category before saving. The field is not optional.
     - Shows a scrollable grid of category icons. Separate lists for income categories and expense categories.
  3. **Date** (defaults to today, user can change)
  4. **Note / Memo** (optional, free-text)
- **Edit / Delete** — swipe-left on a transaction row to delete (with confirmation). Tap a transaction to open the edit form pre-filled with existing data.

### C. Categories

- **Default Categories (Expense):** Food & Drinks, Transport, Shopping, Bills & Utilities, Entertainment, Health, Education, Groceries, Other.
- **Default Categories (Income):** Salary, Freelance, Gift, Investment, Other.
- **Custom Categories:**
  - Users can create new categories from a "Manage Categories" screen accessible via Settings.
  - Each custom category requires: a **name**, an **icon** (chosen from a curated icon picker), and a **color**.
  - Custom categories can be edited or deleted. Deleting a category does not delete transactions — those transactions keep their category label as archived text.
  - Categories are separated into two tabs: Income and Expense. A custom category must belong to one type.

### D. Analytics

- **Expense Breakdown Chart** — a donut/pie chart showing expense distribution by category for the selected period.
- **Income Breakdown Chart** — same treatment for income.
- **Period Selector** — toggle between Week / Month / Year views.
- **Category List** — below the chart, a ranked list of categories by total amount, with percentage bars.

### E. Transaction History

- **Full History Screen** — all transactions in reverse-chronological order, grouped by date.
- **Sticky Date Headers** — "Today", "Yesterday", or formatted date strings.
- **Search & Filter** — filter by category, type (income/expense), or date range.

### F. Settings

- **Currency Selection** — pick a display currency symbol (Rp, $, €, £, ¥). This is cosmetic only (no conversion).
- **Manage Categories** — create, edit, reorder, or delete custom categories.
- **Manage Budgets** — create, edit, or delete budget limits per category.
- **Theme** — Light / Dark / System. Defaults to System.
- **Payday Configuration** — set the day of the month when tracking resets (e.g. the 25th). The dashboard period runs from payday to payday.
- **Export Data** — export transactions as CSV.
- **About** — app version, credits.

### G. Onboarding Flow (First Launch Only)

A short, skippable 3-screen tutorial shown once on first app launch. The goal is to orient new users and capture essential preferences without creating friction.

- **Screen 1 — Welcome:** App name, tagline ("Track your money, not your stress"), and a warm illustration. Single "Get Started" button.
- **Screen 2 — Currency Setup:** Pick a display currency (Rp, $, €, £, ¥). Defaults to the device locale if detectable.
- **Screen 3 — Payday Setup:** Set the day of the month when the tracking cycle resets. Option to skip (defaults to the 1st).
- After completing or skipping onboarding, the user lands on the Dashboard. A `hasCompletedOnboarding` flag is saved locally so the flow never shows again.
- **No account creation, no sign-up.** The onboarding is purely configuration.

### H. Recurring Transactions

Users can set up transactions that repeat automatically on a schedule.

- **Create Recurring:** From the "Add Transaction" form, toggle a "Repeat" switch to turn a one-time transaction into a recurring one.
- **Frequency Options:** Daily, Weekly, Biweekly, Monthly, Yearly.
- **Start Date:** Defaults to today. User can set a future start date.
- **End Date (optional):** If set, the recurrence stops after this date. If not set, it repeats indefinitely.
- **Auto-Generation:** When the app opens, it checks for any recurring transactions due since the last app launch and generates the individual transaction entries automatically. These appear in the transaction history like normal entries but are tagged with a small repeat icon.
- **Manage Recurring:** A "Recurring Transactions" list accessible from Settings or the Transaction History screen. Users can edit the template (changes apply to future occurrences only) or delete the recurrence (past generated transactions are kept).
- **Examples:** Monthly salary, weekly grocery budget, yearly insurance premium, daily coffee allowance.

### I. Budget Limits & Alerts

Users can set spending limits per category and get visual warnings when approaching or exceeding them.

- **Set Budget:** From "Manage Budgets" in Settings, user picks an expense category and sets a monthly spending limit (e.g. Food & Drinks: Rp 2,000,000).
- **Budget Period:** Follows the same payday cycle as the dashboard. Resets when the new period starts.
- **Visual Progress:** On the Dashboard, categories with budgets show a progress bar under the category name:
  - **0–75%** — normal state (uses the category color).
  - **75–100%** — warning state (amber/warm orange indicator).
  - **100%+** — exceeded state (dusty rose / soft red indicator, never aggressive red).
- **Dashboard Budget Section:** Below the income/expense summary, a "Budgets" section shows the top 3–5 active budgets with their progress bars. Tappable to see the full list.
- **Alert on Transaction Save:** When saving an expense that pushes a category over 75% or 100% of its budget, show a brief, non-blocking toast/snackbar: "Heads up — you've used 85% of your Food & Drinks budget this month."
- **No push notifications.** Alerts are in-app only.
- **Analytics Integration:** The Analytics screen shows budget vs. actual spending per category as an additional view mode.

### J. Yearly Summary Report

An annual overview screen that gives users a clear picture of their financial year.

- **Access:** From the Analytics screen via a "Yearly Report" button, or from Settings.
- **Report Contents:**
  - **Total Income vs. Total Expenses** — headline numbers for the selected year with net savings/deficit.
  - **Month-by-Month Trend** — a bar chart or line chart showing income and expense totals per month across the year.
  - **Top Expense Categories** — ranked list of the 5 highest expense categories for the year with totals and percentages.
  - **Top Income Sources** — same treatment for income categories.
  - **Average Monthly Spending** — total expenses ÷ number of months with data.
  - **Highest / Lowest Spending Months** — callout cards highlighting the peak and quietest months.
  - **Budget Performance** — if budgets are set, show how many months the user stayed within budget vs. exceeded.
- **Year Selector:** Dropdown or horizontal scroll to switch between years (only years with data are shown).
- **Shareable:** Option to export the report as a styled PDF or image for sharing.

---

## 3. UI / UX Design Direction

### Design Philosophy

Finta should feel like a well-made notebook — **warm, calm, and trustworthy**. Not a fintech dashboard. Not a generic Material Design app. The goal is a UI that people actually enjoy opening every day, not one that screams "AI generated this."

### Color Palette (Warm & Earthy)

| Token              | Light Mode             | Dark Mode              | Usage                            |
| :----------------- | :--------------------- | :--------------------- | :------------------------------- |
| `background`       | `#FAF7F2` (warm cream) | `#1A1816` (warm black) | App background                   |
| `surface`          | `#FFFFFF`              | `#242120`              | Cards, sheets, inputs            |
| `surfaceVariant`   | `#F0EBE3` (light tan)  | `#2E2A27`              | Secondary surfaces, dividers     |
| `primary`          | `#C87941` (terracotta) | `#D4956A` (soft amber) | Primary actions, FAB, active tab |
| `onPrimary`        | `#FFFFFF`              | `#1A1816`              | Text/icons on primary color      |
| `textPrimary`      | `#2C2520` (dark brown) | `#EDE8E2`              | Headings, body text              |
| `textSecondary`    | `#8A7E74` (muted tan)  | `#9C8E82`              | Labels, captions, hints          |
| `income`           | `#5B8C5A` (sage green) | `#7DB87C`              | Income amounts, income badges    |
| `expense`          | `#C2665A` (dusty rose) | `#D4887E`              | Expense amounts, expense badges  |
| `border`           | `#E5DED5`              | `#3A3533`              | Card borders, input outlines     |

### Typography

- **Font Family:** `Inter` (from Google Fonts via `google_fonts` package).
- **Weights:** 400 (body), 500 (labels), 600 (subheadings), 700 (headings/balance).
- **Minimum Size:** 13sp for captions, 15sp for body, 24sp+ for the main balance display.
- **No ALL-CAPS except for very short labels** (e.g. "INCOME", "EXPENSE" badges).

### Layout Principles

- **Cards with rounded corners** (12–16dp radius), subtle borders instead of heavy shadows.
- **Generous whitespace** — breathing room between sections. Dense lists are fine; dense dashboards are not.
- **Bottom-heavy interaction** — the FAB, navigation bar, and input sheets live in the bottom 50% of the screen for easy thumb access.
- **No aggressive reds** for expenses. Use the muted dusty-rose palette instead — financial apps shouldn't make you feel guilty.
- **Subtle animations** — 200–300ms ease-out transitions for sheet entry, page transitions, and chart rendering. No bouncy spring physics, no unnecessary looping animations.

### Anti-Slop Checklist

- [ ] Every screen has a unique layout structure. Do not copy-paste card grids across screens.
- [ ] No gratuitous gradient backgrounds. Flat warm tones only.
- [ ] Icons are consistent — all from the same icon set (Lucide or Phosphor), same stroke weight.
- [ ] No placeholder "Lorem ipsum" anywhere in production.
- [ ] Chart colors are hand-picked from the warm palette, not random MaterialColor shades.
- [ ] Empty states have friendly illustrations or messages, not blank white screens.
- [ ] Amount text uses tabular (monospaced) number figures so digits align vertically in lists.

---

## 4. Amount Input Behavior (Detail Spec)

This is critical to get right since it's used on every single transaction.

### Rules

1. **Numeric only.** The keyboard type is `number`. The input field rejects all non-numeric characters.
2. **Auto-comma formatting.** As the user types, the displayed value is formatted with thousand-separator commas:
   - `1` → `1`
   - `15` → `15`
   - `150` → `150`
   - `1500` → `1,500`
   - `15000` → `15,000`
   - `150000` → `150,000`
   - `1500000` → `1,500,000`
3. **Decimal support.** If the selected currency uses decimals, allow a single decimal point followed by up to 2 digits. The comma formatting applies only to the integer portion.
4. **Max length.** Cap input at 15 digits (before decimal) to prevent overflow.
5. **Storage.** Store the raw numeric value in the database. Display with commas and currency symbol in the UI.
6. **Validation.** The "Save" button is disabled until the amount is greater than zero and a category is selected.

### Implementation Approach

Use a custom `TextInputFormatter` in Flutter:
- Strip all commas from the current value.
- Validate that the remaining string is a valid number.
- Re-insert commas at every 3rd digit from the right.
- Return the formatted string and adjust the cursor position.

---

## 5. Technology Stack

| Layer              | Technology                         | Notes                                          |
| :----------------- | :--------------------------------- | :--------------------------------------------- |
| **Framework**      | Flutter 3.x (Dart)                 | Cross-platform: Android, iOS, Windows, macOS   |
| **Local Database** | `sqflite` + `path_provider`        | SQLite for local storage. No server dependency. |
| **State Mgmt**     | `provider`                         | Simple, well-documented, sufficient for MVP.    |
| **Charts**         | `fl_chart`                         | Lightweight, customizable Flutter charts.       |
| **Fonts**          | `google_fonts`                     | Inter font family.                             |
| **Icons**          | `lucide_icons` or `phosphor_icons` | Consistent stroke-weight icon set.             |
| **Intl**           | `intl`                             | Number formatting, date formatting.            |
| **UUID**           | `uuid`                             | Unique IDs for transactions and categories.    |
| **Local Prefs**    | `shared_preferences`               | Onboarding flag, currency, theme, payday day.  |

---

## 6. Data Model

### Transaction Table (`transactions`)

| Column       | Type    | Constraints                   |
| :----------- | :------ | :---------------------------- |
| `id`         | TEXT    | Primary key (UUID)            |
| `type`       | TEXT    | `'income'` or `'expense'`     |
| `amount`     | REAL    | > 0, stored as raw number     |
| `categoryId` | TEXT    | FK → categories.id (required) |
| `date`       | TEXT    | ISO 8601 date string          |
| `note`       | TEXT    | Nullable                      |
| `createdAt`  | TEXT    | ISO 8601 timestamp            |
| `updatedAt`  | TEXT    | ISO 8601 timestamp            |

### Category Table (`categories`)

| Column      | Type    | Constraints                    |
| :---------- | :------ | :----------------------------- |
| `id`        | TEXT    | Primary key (UUID)             |
| `name`      | TEXT    | Not null                       |
| `type`      | TEXT    | `'income'` or `'expense'`      |
| `icon`      | TEXT    | Icon identifier string         |
| `color`     | TEXT    | Hex color string (e.g. `#C87941`) |
| `isDefault` | INTEGER | 1 = pre-installed, 0 = custom  |
| `sortOrder` | INTEGER | Display order                  |
| `createdAt` | TEXT    | ISO 8601 timestamp             |

### Recurring Transaction Table (`recurring_transactions`)

| Column       | Type    | Constraints                              |
| :----------- | :------ | :--------------------------------------- |
| `id`         | TEXT    | Primary key (UUID)                       |
| `type`       | TEXT    | `'income'` or `'expense'`                |
| `amount`     | REAL    | > 0                                      |
| `categoryId` | TEXT    | FK → categories.id                       |
| `note`       | TEXT    | Nullable                                 |
| `frequency`  | TEXT    | `'daily'`, `'weekly'`, `'biweekly'`, `'monthly'`, `'yearly'` |
| `startDate`  | TEXT    | ISO 8601 date                            |
| `endDate`    | TEXT    | Nullable — null means indefinite         |
| `lastRunDate`| TEXT    | Last date a transaction was auto-created  |
| `isActive`   | INTEGER | 1 = active, 0 = paused/deleted           |
| `createdAt`  | TEXT    | ISO 8601 timestamp                       |

### Budget Table (`budgets`)

| Column       | Type    | Constraints                   |
| :----------- | :------ | :---------------------------- |
| `id`         | TEXT    | Primary key (UUID)            |
| `categoryId` | TEXT    | FK → categories.id (unique per category) |
| `amount`     | REAL    | Monthly limit, > 0            |
| `isActive`   | INTEGER | 1 = active, 0 = disabled      |
| `createdAt`  | TEXT    | ISO 8601 timestamp            |
| `updatedAt`  | TEXT    | ISO 8601 timestamp            |

---

## 7. Folder Structure

```
lib/
├── main.dart                          # App entry point, MaterialApp setup, theme
├── app/
│   ├── app.dart                       # Root widget, navigation shell
│   └── routes.dart                    # Route definitions
│
├── core/
│   ├── constants/
│   │   ├── app_colors.dart            # Color palette tokens (light & dark)
│   │   ├── app_typography.dart        # Text styles
│   │   └── app_constants.dart         # Spacing, radius, durations
│   ├── database/
│   │   ├── database_helper.dart       # SQLite init, migrations, singleton
│   │   └── seed_data.dart             # Default categories seeding
│   ├── formatters/
│   │   └── currency_formatter.dart    # TextInputFormatter for auto-comma
│   ├── services/
│   │   └── recurring_service.dart     # Check & generate due recurring txns
│   ├── utils/
│   │   ├── date_utils.dart            # Date grouping, relative labels
│   │   └── number_utils.dart          # Parse/format helpers
│   └── theme/
│       └── app_theme.dart             # ThemeData for light & dark mode
│
├── models/
│   ├── transaction_model.dart         # Transaction data class
│   ├── category_model.dart            # Category data class
│   ├── recurring_transaction_model.dart # Recurring template data class
│   └── budget_model.dart              # Budget data class
│
├── providers/
│   ├── transaction_provider.dart      # Transaction CRUD + state
│   ├── category_provider.dart         # Category CRUD + state
│   ├── recurring_provider.dart        # Recurring transaction CRUD + state
│   ├── budget_provider.dart           # Budget CRUD + spending calc
│   ├── analytics_provider.dart        # Aggregation logic for charts
│   └── settings_provider.dart         # Currency, theme, payday prefs
│
├── repositories/
│   ├── transaction_repository.dart    # SQLite queries for transactions
│   ├── category_repository.dart       # SQLite queries for categories
│   ├── recurring_repository.dart      # SQLite queries for recurring txns
│   └── budget_repository.dart         # SQLite queries for budgets
│
├── screens/
│   ├── onboarding/
│   │   ├── onboarding_screen.dart     # PageView shell for onboarding
│   │   └── widgets/
│   │       ├── welcome_page.dart       # Screen 1: Welcome
│   │       ├── currency_page.dart      # Screen 2: Currency setup
│   │       └── payday_page.dart        # Screen 3: Payday setup
│   ├── dashboard/
│   │   ├── dashboard_screen.dart      # Home screen layout
│   │   └── widgets/
│   │       ├── balance_card.dart       # Current balance display
│   │       ├── summary_row.dart        # Income/Expense totals
│   │       ├── budget_overview.dart    # Top budgets with progress bars
│   │       └── recent_transactions.dart
│   ├── transactions/
│   │   ├── add_transaction_screen.dart # Add/Edit transaction form
│   │   ├── transaction_history_screen.dart
│   │   └── widgets/
│   │       ├── transaction_tile.dart
│   │       ├── amount_input_field.dart  # Auto-comma numeric input
│   │       ├── category_picker.dart     # Category grid selector
│   │       ├── date_picker_field.dart
│   │       └── recurring_toggle.dart   # Repeat switch + frequency picker
│   ├── recurring/
│   │   └── recurring_list_screen.dart  # Manage recurring transactions
│   ├── budgets/
│   │   ├── manage_budgets_screen.dart  # List all budgets
│   │   └── widgets/
│   │       ├── budget_form.dart         # Create/edit budget
│   │       └── budget_progress_bar.dart # Visual spending bar
│   ├── analytics/
│   │   ├── analytics_screen.dart
│   │   └── widgets/
│   │       ├── breakdown_chart.dart
│   │       ├── category_rank_list.dart
│   │       ├── budget_vs_actual.dart    # Budget comparison view
│   │       └── yearly_report.dart       # Yearly summary report screen
│   ├── categories/
│   │   ├── manage_categories_screen.dart
│   │   └── widgets/
│   │       ├── category_form.dart       # Create/edit category
│   │       └── icon_picker.dart         # Icon selection grid
│   └── settings/
│       └── settings_screen.dart
│
└── widgets/
    ├── app_bottom_nav.dart             # Bottom navigation bar
    ├── empty_state.dart                # Friendly empty-state placeholder
    └── confirm_dialog.dart             # Reusable delete confirmation
```

---

## 8. Architecture & Code Guidelines

### Pattern: Provider + Repository

```
UI (Screen / Widget)
    ↓ reads state from
Provider (ChangeNotifier)
    ↓ calls methods on
Repository (Data Access)      ←── Services (recurring_service)
    ↓ queries
SQLite Database
```

- **Screens** only build UI. No direct database calls.
- **Providers** hold state, call repositories, and notify listeners.
- **Repositories** are pure data-access classes. One per table. No UI logic.
- **Models** are plain Dart data classes with `toMap()` / `fromMap()` serialization.

### Coding Standards

- `camelCase` for variables, functions, parameters.
- `PascalCase` for classes, enums, typedefs.
- `snake_case` for file names.
- **Max file length:** 300 lines. If a screen exceeds this, extract widgets into a `widgets/` subfolder.
- **No magic numbers.** Use named constants from `app_constants.dart`.
- **DRY:** Centralize formatting (currency, dates) in `core/utils/` and `core/formatters/`.
- **KISS:** Flat widget trees. Avoid deeply nested builders. Extract early.

---

## 9. Scope Boundaries

### In Scope (Build This)

- Local SQLite storage (no server, no login)
- Onboarding flow (3 screens: welcome, currency, payday — first launch only)
- Dashboard with balance, income/expense summary, budget overview, recent transactions
- Add / edit / delete transactions with mandatory category selection
- Auto-comma amount input with number-only validation
- Recurring transactions (daily, weekly, biweekly, monthly, yearly) with auto-generation
- Budget limits per expense category with visual progress bars and in-app alerts
- Default + custom categories with icon and color picker
- Analytics screen with donut chart, category ranking, and budget vs. actual view
- Yearly summary report with month-by-month trends, top categories, and budget performance
- Transaction history with date grouping and search
- Settings: currency symbol, theme toggle, payday day, manage categories, manage budgets, manage recurring, CSV export
- Light and dark theme with warm earthy palette

### Out of Scope (v2 / Future)

- User authentication / accounts
- Cloud sync / Firebase backend
- Multi-wallet / account support (cash, bank, credit card)
- Transfers between wallets
- CSV import
- App lock (PIN / biometrics)
- Receipt photo attachments
- Calendar view
- Multi-currency conversion
- Bank API integrations
- Push notifications
- Investment / stock tracking
