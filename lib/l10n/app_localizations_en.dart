// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get home => 'Home';

  @override
  String get analytics => 'Analytics';

  @override
  String get transactions => 'Transactions';

  @override
  String get settings => 'Settings';

  @override
  String get more => 'More';

  @override
  String get preferences => 'Preferences';

  @override
  String get currency => 'Currency';

  @override
  String get theme => 'Theme';

  @override
  String get language => 'Language';

  @override
  String get payday => 'Payday (Cycle Reset)';

  @override
  String get languageNameEnglish => 'English';

  @override
  String get languageNameIndonesian => 'Bahasa Indonesia';

  @override
  String appVersionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get appTagline => 'Built for you';

  @override
  String get csvExportShareSubject => 'Finta export';

  @override
  String get manage => 'Manage';

  @override
  String get categories => 'Categories';

  @override
  String get budgets => 'Budgets';

  @override
  String get recurring => 'Recurring';

  @override
  String get data => 'Data';

  @override
  String get exportCsv => 'Export as CSV';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get add => 'Add';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get system => 'System';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get totalBalance => 'Total Balance';

  @override
  String get netThisPeriod => 'Net This Period';

  @override
  String get income => 'Income';

  @override
  String get expense => 'Expense';

  @override
  String get recentTransactions => 'Recent Transactions';

  @override
  String get seeAll => 'See All';

  @override
  String get noRecentTransactions => 'No recent transactions';

  @override
  String get expenseBreakdown => 'Expense Breakdown';

  @override
  String get noDataForThisPeriod => 'No data for this period';

  @override
  String get totalSpent => 'Total Spent';

  @override
  String get chartTotal => 'Total';

  @override
  String get heatmapTapHint => 'Tap a day to see its transactions';

  @override
  String get totalIncome => 'Total Income';

  @override
  String get totalExpense => 'Total Expense';

  @override
  String get addTransaction => 'Add Transaction';

  @override
  String get editTransaction => 'Edit Transaction';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get amount => 'Amount';

  @override
  String get date => 'Date';

  @override
  String get saveTransaction => 'Save Transaction';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get pleaseEnterValidAmount => 'Please enter a valid amount';

  @override
  String get pleaseSelectCategory => 'Please select a category';

  @override
  String get moreOptions => 'More options';

  @override
  String get manageCategories => 'Manage Categories';

  @override
  String get addCategory => 'Add Category';

  @override
  String get editCategory => 'Edit Category';

  @override
  String get categoryName => 'Category Name';

  @override
  String get icon => 'Icon';

  @override
  String get color => 'Color';

  @override
  String get manageBudgets => 'Manage Budgets';

  @override
  String get addBudget => 'Add Budget';

  @override
  String get editBudget => 'Edit Budget';

  @override
  String get budgetAmount => 'Budget Amount';

  @override
  String get spent => 'Spent';

  @override
  String get remaining => 'Remaining';

  @override
  String get recurringTransactions => 'Recurring Transactions';

  @override
  String get addRecurring => 'Add Recurring';

  @override
  String get frequency => 'Frequency';

  @override
  String get daily => 'Daily';

  @override
  String get weekly => 'Weekly';

  @override
  String get monthly => 'Monthly';

  @override
  String get yearly => 'Yearly';

  @override
  String get nextDate => 'Next Date';

  @override
  String get active => 'Active';

  @override
  String get paused => 'Paused';

  @override
  String get welcomeToFinta => 'Welcome to Finta';

  @override
  String get trackYourExpensesEasily => 'Track your expenses easily.';

  @override
  String get getStarted => 'Get Started';

  @override
  String get confirmDelete => 'Are you sure you want to delete this?';

  @override
  String get archive => 'Archive';

  @override
  String archivedCount(int count) {
    return 'Archived ($count)';
  }

  @override
  String get deletePermanently => 'Delete permanently';

  @override
  String get archiveCategory => 'Archive Category';

  @override
  String confirmDeleteCategory(String name) {
    return 'Delete \"$name\"? This category has no transactions, so it can be safely removed.';
  }

  @override
  String confirmArchiveCategory(String name, int count) {
    return '\"$name\" is used by $count transaction(s). It will be hidden from new entries but those transactions will keep their category label — nothing is deleted.';
  }

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get history => 'History';

  @override
  String get yearlyReport => 'Yearly Report';

  @override
  String get summary => 'Summary';

  @override
  String get netSavings => 'Net Savings';

  @override
  String get searchNotes => 'Search notes...';

  @override
  String get all => 'All';

  @override
  String get noTransactionsFound => 'No transactions found';

  @override
  String get tryAdjustingSearch => 'Try adjusting your search';

  @override
  String get noTransactionsYet => 'You haven\'t added any transactions yet';

  @override
  String get incomeAmount => 'Income Amount';

  @override
  String get expenseAmount => 'Expense Amount';

  @override
  String get category => 'Category';

  @override
  String get defaultCategory => 'Default';

  @override
  String get selectACategory => 'Select a category...';

  @override
  String get searchCategories => 'Search categories...';

  @override
  String get createNewCategory => 'Create New Category';

  @override
  String get noCategoriesFound => 'No categories found';

  @override
  String get makeThisRecurring => 'Make this recurring?';

  @override
  String get biweekly => 'Every 2 weeks';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get noBudgetsYet => 'No budgets yet';

  @override
  String get setMonthlyLimits => 'Set monthly limits to track your spending';

  @override
  String get ofString => 'of';

  @override
  String get deleteBudget => 'Delete Budget';

  @override
  String removeBudgetFor(String category) {
    return 'Remove the budget for $category?';
  }

  @override
  String get newBudget => 'New Budget';

  @override
  String get saveBudget => 'Save Budget';

  @override
  String get budgetAlreadyExistsForCategory =>
      'A budget already exists for this category';

  @override
  String get used => 'used';

  @override
  String get spentString => 'spent';

  @override
  String get left => 'left';

  @override
  String get overString => 'over';

  @override
  String get noRecurringTransactions => 'No recurring transactions';

  @override
  String get enableRecurringWhenAdding =>
      'Enable \"recurring\" when adding a transaction';

  @override
  String get unknown => 'Unknown';

  @override
  String get next => 'Next';

  @override
  String get stopRecurring => 'Stop Recurring';

  @override
  String get stopRecurringMessage =>
      'This will stop future transactions from being generated automatically. Existing transactions will remain.';

  @override
  String get recurringStopped => 'Recurring transaction stopped';

  @override
  String get stop => 'Stop';

  @override
  String get skip => 'Skip';

  @override
  String get trackYourMoney => 'Track your money,\nnot your stress';

  @override
  String get chooseYourCurrency => 'Choose your currency';

  @override
  String get currencyDisplayOnly => 'This is just for display — no conversion';

  @override
  String get whenDoYouGetPaid => 'When do you get paid?';

  @override
  String get paydayDescription =>
      'Your tracking period resets on this day each month';

  @override
  String get startTracking => 'Start Tracking';

  @override
  String get budgetExceededAlert =>
      'You\'ve exceeded your budget for this category';

  @override
  String budgetWarningAlert(Object pct) {
    return 'Heads up — you\'ve used $pct% of your budget';
  }

  @override
  String get errorFailedToSave => 'Failed to save. Please try again.';

  @override
  String get errorFailedToDelete => 'Failed to delete. Please try again.';

  @override
  String get categoryAlreadyExists =>
      'A category with this name already exists';

  @override
  String get retry => 'Retry';

  @override
  String get overBudget => 'Over Budget!';

  @override
  String get backupYourData => 'Backup your data';

  @override
  String get upcoming => 'Upcoming';

  @override
  String get dueToday => 'Today';

  @override
  String get dueTomorrow => 'Tomorrow';

  @override
  String dueInDays(int days) {
    return 'in $days days';
  }

  @override
  String showAllCount(int count) {
    return 'Show all ($count)';
  }

  @override
  String get createFirstBudget => 'Create your first budget';

  @override
  String get addTransactionCta => 'Add a transaction';

  @override
  String get createCategory => 'Create a category';

  @override
  String get createFirstRecurring => 'Set up recurring transactions';

  @override
  String get year => 'Year';

  @override
  String get noTransactionsOnThisDay => 'No transactions on this day';

  @override
  String get period => 'Period';

  @override
  String get paceAhead => 'Ahead of pace';

  @override
  String get paceOnTrack => 'On track';

  @override
  String get paceUnder => 'Under pace';

  @override
  String get safeToSpendLabel => 'Safe to spend per day';

  @override
  String get hideBalances => 'Hide balances';

  @override
  String get showBalances => 'Show balances';

  @override
  String get currentPayPeriod => 'Current pay period';

  @override
  String get leftThisPeriod => 'Left this period';

  @override
  String spentOfTotal(String spent, String total) {
    return '$spent of $total spent';
  }

  @override
  String percentVsLast(String percent) {
    return '$percent% vs last';
  }

  @override
  String get filters => 'Filters';

  @override
  String get clearFilters => 'Clear all';

  @override
  String get dateRange => 'Date range';

  @override
  String get anyTime => 'Any time';

  @override
  String get thisPeriod => 'This period';

  @override
  String get lastPeriod => 'Last period';

  @override
  String get last3Months => 'Last 3 months';

  @override
  String get customRange => 'Custom';

  @override
  String get type => 'Type';

  @override
  String get amountRange => 'Amount range';

  @override
  String get minAmount => 'Min';

  @override
  String get maxAmount => 'Max';

  @override
  String get applyFilters => 'Apply filters';

  @override
  String transactionsSummary(int count, String total) {
    return '$count transactions · $total';
  }

  @override
  String get whereItWent => 'Where it went';

  @override
  String get reports => 'Reports';

  @override
  String get paceInfoTitle => 'Spending pace';

  @override
  String get paceExplanation =>
      'Compares how much of the budget you\'ve spent to how far through the period you are. The tick on the bar marks today — if the colored fill has passed it, you\'re spending faster than the days are passing (ahead of pace); if it hasn\'t reached the tick yet, you\'re spending slower (under pace).';

  @override
  String get gotIt => 'Got it';

  @override
  String get accounts => 'Accounts';

  @override
  String get account => 'Account';

  @override
  String get manageAccounts => 'Manage Accounts';

  @override
  String get addAccount => 'Add Account';

  @override
  String get editAccount => 'Edit Account';

  @override
  String get accountName => 'Account Name';

  @override
  String get accountType => 'Account Type';

  @override
  String get openingBalance => 'Opening Balance';

  @override
  String get creditLimitOptional => 'Credit Limit (optional)';

  @override
  String get includeInTotal => 'Include in totals';

  @override
  String get includeInTotalDescription =>
      'Counts toward net worth and available cash';

  @override
  String get netWorth => 'Net Worth';

  @override
  String get selectAnAccount => 'Select an account';

  @override
  String get noAccountsYet => 'No accounts yet';

  @override
  String get noAccountsYetMessage =>
      'Add an account to start tracking balances across your wallets, banks, and cards';

  @override
  String get archiveAccount => 'Archive Account';

  @override
  String confirmArchiveAccountUnused(String name) {
    return 'Archive \"$name\"? It will be hidden from new entries.';
  }

  @override
  String confirmArchiveAccount(String name, int count) {
    return '\"$name\" is used by $count transaction(s). It will be hidden from new entries but those transactions will keep their account label — nothing is deleted.';
  }

  @override
  String amountOwed(String amount) {
    return '$amount owed';
  }

  @override
  String get accountTypeCash => 'Cash';

  @override
  String get accountTypeBank => 'Bank';

  @override
  String get accountTypeCreditCard => 'Credit Card';

  @override
  String get accountTypeEWallet => 'E-Wallet';

  @override
  String get accountTypeSavings => 'Savings';

  @override
  String get accountTypeInvestment => 'Investment';

  @override
  String get transfer => 'Transfer';

  @override
  String get transferAmount => 'Transfer Amount';

  @override
  String get fromAccount => 'From';

  @override
  String get toAccount => 'To';

  @override
  String get deleteTransfer => 'Delete Transfer';

  @override
  String get confirmDeleteTransfer =>
      'Delete this transfer? Both sides of the transfer will be removed.';

  @override
  String transferOutOf(String account) {
    return 'Out of $account';
  }

  @override
  String transferIntoAccount(String account) {
    return 'Into $account';
  }

  @override
  String get merchant => 'Merchant';

  @override
  String get merchantHint => 'Where did you spend?';

  @override
  String get parentCategoryOptional => 'Parent category (optional)';

  @override
  String get noneTopLevel => 'None — top-level category';

  @override
  String get groupSubcategories => 'Group sub-categories';

  @override
  String get showSubcategories => 'Show sub-categories';

  @override
  String percentMoreThanLastPeriod(String percent) {
    return '$percent% more than last period';
  }

  @override
  String percentLessThanLastPeriod(String percent) {
    return '$percent% less than last period';
  }

  @override
  String get overallBudget => 'Overall Budget';

  @override
  String get groupBudget => 'Group Budget';

  @override
  String get budgetScope => 'Budget covers';

  @override
  String get budgetScopeCategory => 'One category';

  @override
  String get budgetScopeGroup => 'Group of categories';

  @override
  String get budgetScopeOverall => 'Everything';

  @override
  String get budgetName => 'Budget name';

  @override
  String get budgetNameOptional => 'Budget name (optional)';

  @override
  String get budgetPeriod => 'Period';

  @override
  String get budgetRepeat => 'Repeat every period';

  @override
  String budgetRepeatRenewsOn(String date) {
    return 'Renews $date.';
  }

  @override
  String budgetRepeatEndsOn(String date) {
    return 'Ends $date. Covers this period only.';
  }

  @override
  String get endedBudgets => 'Ended';

  @override
  String budgetEndedOn(String date) {
    return 'Ended $date';
  }

  @override
  String get budgetRollover => 'Rollover';

  @override
  String get budgetRolloverExplanation =>
      'Carry unspent (or overspent) budget into the next period.';

  @override
  String get rolloverNone => 'Off';

  @override
  String get rolloverPositiveOnly => 'Unspent only';

  @override
  String get rolloverFull => 'Unspent or overspent';

  @override
  String get selectAtLeastTwoCategories => 'Select at least two categories';

  @override
  String rolledOverPositive(String amount) {
    return '$amount rolled over from last period';
  }

  @override
  String rolledOverNegative(String amount) {
    return '$amount over from last period';
  }

  @override
  String get backupAndRestore => 'Backup & Restore';

  @override
  String get backupAndRestoreSubtitle =>
      'Back up your data, or import from a CSV file';

  @override
  String get backupSectionTitle => 'Backup';

  @override
  String get createBackup => 'Create backup';

  @override
  String get createBackupSubtitle =>
      'Save a full copy of your data to share or store safely';

  @override
  String get restoreFromBackup => 'Restore from backup';

  @override
  String get restoreFromBackupSubtitle =>
      'Replace your data with a previously saved backup';

  @override
  String get restore => 'Restore';

  @override
  String get backupFailed => 'Failed to create backup';

  @override
  String get backupIncompatible =>
      'This backup was made with a newer version of Finta and can\'t be restored here';

  @override
  String get backupInvalidFile => 'That file isn\'t a valid Finta backup';

  @override
  String get restoreBackupTitle => 'Restore this backup?';

  @override
  String restoreBackupConfirm(String date) {
    return 'This will replace all current data with the backup from $date. This can\'t be undone.';
  }

  @override
  String get restoreFailed => 'Failed to restore backup';

  @override
  String get restoreCompleteTitle => 'Backup restored';

  @override
  String get restoreCompleteMessage =>
      'Please close and reopen Finta to finish loading your restored data.';

  @override
  String get csvImportSectionTitle => 'Import';

  @override
  String get importCsv => 'Import from CSV';

  @override
  String get importCsvSubtitle =>
      'Bring in transactions from Finta or another app\'s export';

  @override
  String get csvReadFailed => 'Failed to read that CSV file';

  @override
  String get mapCsvColumns => 'Map columns';

  @override
  String get reviewImport => 'Review import';

  @override
  String csvRowsFound(int count) {
    return '$count rows found in this file';
  }

  @override
  String get csvColumnDate => 'Date';

  @override
  String get csvColumnAmount => 'Amount';

  @override
  String get csvColumnType => 'Type (income/expense)';

  @override
  String get csvColumnCategory => 'Category';

  @override
  String get csvColumnMerchant => 'Merchant';

  @override
  String get csvColumnNote => 'Note';

  @override
  String get csvImportToAccount => 'Import into account';

  @override
  String get previewImport => 'Preview import';

  @override
  String csvImportSummary(int ready, int skipped) {
    return '$ready ready to import, $skipped skipped';
  }

  @override
  String csvRowNumber(int number) {
    return 'Row $number';
  }

  @override
  String get csvNoErrors => 'Every row looks good';

  @override
  String confirmImportCount(int count) {
    return 'Import $count transactions';
  }

  @override
  String csvImportedCount(int count) {
    return 'Imported $count transactions';
  }

  @override
  String get importFailed => 'Import failed';

  @override
  String get importedCategoryName => 'Imported';

  @override
  String get goals => 'Goals';

  @override
  String get addGoal => 'Add goal';

  @override
  String get editGoal => 'Edit goal';

  @override
  String get deleteGoal => 'Delete goal';

  @override
  String get goalName => 'Goal name';

  @override
  String get targetAmount => 'Target amount';

  @override
  String get targetDateOptional => 'Target date (optional)';

  @override
  String get noDateSet => 'No date set';

  @override
  String get noGoalsYet => 'No goals yet';

  @override
  String get noGoalsYetMessage =>
      'Set a savings target and track your progress toward it';

  @override
  String get contribute => 'Contribute';

  @override
  String contributeToGoal(String name) {
    return 'Contribute to $name';
  }

  @override
  String goalProgressAmount(String current, String target) {
    return '$current of $target';
  }

  @override
  String get goalComplete => 'Goal reached!';

  @override
  String goalTargetDate(String date) {
    return 'Target: $date';
  }

  @override
  String goalProjectedDate(String date) {
    return 'Projected: $date';
  }

  @override
  String confirmDeleteGoal(String name) {
    return 'Delete \"$name\"? This can\'t be undone.';
  }

  @override
  String confirmDeleteGoalWithContributions(String name, int count) {
    return '\"$name\" has $count contribution(s). Keeping them archives the goal and leaves your account balances alone. Deleting them removes those transactions too and gives the money back.';
  }

  @override
  String get keepContributions => 'Keep contributions';

  @override
  String get deleteContributionsToo => 'Delete contributions too';

  @override
  String confirmPurgeGoal(String name, int count) {
    return 'Delete \"$name\" and its $count contribution(s)? Those transactions are removed and your account balances change. This can\'t be undone.';
  }

  @override
  String get contributions => 'Contributions';

  @override
  String get noContributionsYet => 'No contributions yet';

  @override
  String get noContributionsYetMessage =>
      'Every contribution you log shows up here with the wallet it came from';

  @override
  String get debts => 'Debts';

  @override
  String get addDebt => 'Add debt';

  @override
  String get editDebt => 'Edit debt';

  @override
  String get deleteDebt => 'Delete debt';

  @override
  String get debtTypeBorrowed => 'I borrowed';

  @override
  String get debtTypeLent => 'I lent';

  @override
  String get borrowedFrom => 'Borrowed from';

  @override
  String get lentTo => 'Lent to';

  @override
  String get principalAmount => 'Principal amount';

  @override
  String get interestRateOptional => 'Interest rate (optional)';

  @override
  String get dueDateOptional => 'Due date (optional)';

  @override
  String get noDebtsYet => 'No debts yet';

  @override
  String get noDebtsYetMessage =>
      'Track money you\'ve lent or borrowed and log repayments over time';

  @override
  String get owedToYou => 'Owed to you';

  @override
  String get youOwe => 'You owe';

  @override
  String get debtSettled => 'Settled';

  @override
  String debtOutstandingOfPrincipal(String outstanding, String principal) {
    return '$outstanding of $principal outstanding';
  }

  @override
  String debtDueDate(String date) {
    return 'Due $date';
  }

  @override
  String get logRepaymentAction => 'Log repayment';

  @override
  String logRepayment(String name) {
    return 'Log repayment for $name';
  }

  @override
  String confirmDeleteDebt(String name) {
    return 'Delete \"$name\"? This can\'t be undone.';
  }

  @override
  String confirmDeleteDebtWithRepayments(String name, int count) {
    return '\"$name\" has $count repayment(s). Keeping them archives the debt and leaves your account balances alone. Deleting them removes those transactions too and gives the money back.';
  }

  @override
  String get keepRepayments => 'Keep repayments';

  @override
  String get deleteRepaymentsToo => 'Delete repayments too';

  @override
  String confirmPurgeDebt(String name, int count) {
    return 'Delete \"$name\" and its $count repayment(s)? Those transactions are removed and your account balances change. This can\'t be undone.';
  }

  @override
  String get repayments => 'Repayments';

  @override
  String get noRepaymentsYet => 'No repayments yet';

  @override
  String get noRepaymentsYetMessage =>
      'Every repayment you log shows up here with the wallet it went through';

  @override
  String get payoffCalculator => 'Payoff calculator';

  @override
  String payoffOutstandingLabel(String amount) {
    return 'Outstanding: $amount';
  }

  @override
  String get monthlyPayment => 'Monthly payment';

  @override
  String get payoffNeverAtThisRate =>
      'This payment won\'t cover the interest — the balance will never clear';

  @override
  String payoffMonthsEstimate(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: 'Paid off in $months months',
      one: 'Paid off in 1 month',
    );
    return '$_temp0';
  }

  @override
  String get goalsAndDebts => 'Goals & Debts';

  @override
  String netDebtSummary(String owed, String owe) {
    return '$owed owed to you · $owe you owe';
  }

  @override
  String get markAsSubscription => 'Track as a subscription?';

  @override
  String get markAsSubscriptionHelp =>
      'Subscriptions show up on the Subscriptions screen with their total cost, and can remind you before they renew.';

  @override
  String get subscriptions => 'Subscriptions';

  @override
  String get noSubscriptionsTitle => 'No subscriptions tracked';

  @override
  String get noSubscriptionsSubtitle =>
      'Mark a recurring transaction as a subscription to track its cost and get renewal reminders';

  @override
  String get subscriptionSuggestions => 'Suggestions';

  @override
  String subscriptionSuggestionSubtitle(String amount, int count) {
    return '$amount/month · seen $count times';
  }

  @override
  String get yourSubscriptions => 'Your subscriptions';

  @override
  String get perMonth => 'Per month';

  @override
  String get perYear => 'Per year';

  @override
  String get dismiss => 'Dismiss';

  @override
  String get overdue => 'Overdue';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get setReminder => 'Set reminder';

  @override
  String get notASubscription => 'Not a subscription';

  @override
  String get reminderOff => 'No reminder';

  @override
  String reminderDaysBeforeOption(int days) {
    return '$days days before';
  }

  @override
  String get trends => 'Trends';

  @override
  String get cashflow => 'Cashflow';

  @override
  String netCashflowOverMonths(int months, String amount) {
    return 'Net over last $months months: $amount';
  }

  @override
  String get categoryTrend => 'Category trend';

  @override
  String categoryAboveAverage(String percent, int months) {
    return '$percent% above your $months-month average';
  }

  @override
  String categoryBelowAverage(String percent, int months) {
    return '$percent% below your $months-month average';
  }

  @override
  String get spendingHeatmap => 'Spending heatmap';

  @override
  String get topMerchants => 'Top merchants';

  @override
  String get noMerchantsForThisPeriod =>
      'No merchants recorded in this period. Fill in the Merchant field on an entry and it will show up here.';

  @override
  String timesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: '1 time',
    );
    return '$_temp0';
  }

  @override
  String get fillOutFormFirst => 'Fill out amount, category, and account first';

  @override
  String get saveAsTemplate => 'Save as template';

  @override
  String get saveAsTemplateHelp =>
      'Save this transaction as a reusable one-tap template';

  @override
  String get templateName => 'Template name';

  @override
  String templateSaved(String name) {
    return 'Saved \"$name\" as a template';
  }

  @override
  String get deleteTemplate => 'Delete template';

  @override
  String confirmDeleteTemplate(String name) {
    return 'Delete the \"$name\" template? This won\'t affect past transactions.';
  }

  @override
  String get invalidExpression => 'Not a valid expression';

  @override
  String get done => 'Done';

  @override
  String selectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get duplicate => 'Duplicate';

  @override
  String get recategorize => 'Recategorize';

  @override
  String confirmBulkDelete(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete these $count transactions?',
      one: 'Delete this transaction?',
    );
    return '$_temp0';
  }

  @override
  String get cannotDuplicateTransfers =>
      'Transfers can\'t be duplicated — select a regular transaction instead';

  @override
  String get cannotRecategorizeTransfers =>
      'Transfers can\'t be recategorized — select a regular transaction instead';

  @override
  String get selectSameTypeToRecategorize =>
      'Select only income or only expense transactions to recategorize together';

  @override
  String get unusualAmountTitle => 'Unusually large amount';

  @override
  String unusualAmountMessage(String amount, String category, String typical) {
    return '$amount is unusually large for $category — typical is around $typical. Continue?';
  }

  @override
  String get continueAnyway => 'Continue anyway';

  @override
  String get smartInsights => 'Smart Insights';

  @override
  String get financialHealthScore => 'Financial health score';

  @override
  String get outOfHundred => 'out of 100';

  @override
  String get healthScoreSavings => 'Savings rate';

  @override
  String get healthScoreBudget => 'Budget adherence';

  @override
  String get healthScoreStability => 'Income stability';

  @override
  String get spendingInsightsTitle => 'Insights';

  @override
  String get noInsightsYet => 'No notable changes from last period yet';

  @override
  String get unusualActivity => 'Unusual activity';

  @override
  String get noUnusualActivity => 'Nothing unusual in the last 30 days';

  @override
  String insightFastestGrowingTitle(String category) {
    return 'Fastest growing: $category';
  }

  @override
  String insightFastestGrowingBody(String percent) {
    return 'Up $percent% on last pay period';
  }

  @override
  String insightSpendingIncreasedTitle(String category) {
    return '$category is up';
  }

  @override
  String insightSpendingIncreasedBody(String percent) {
    return '$percent% more than last period';
  }

  @override
  String insightSpendingDecreasedTitle(String category) {
    return '$category is down';
  }

  @override
  String insightSpendingDecreasedBody(String percent) {
    return '$percent% less than last period';
  }

  @override
  String get periodRecap => 'Period Recap';

  @override
  String yourPeriodRecapTitle(String range) {
    return 'Your $range';
  }

  @override
  String periodInProgress(int day, int total) {
    return 'In progress · day $day of $total';
  }

  @override
  String get topCategories => 'Top categories';

  @override
  String get savingsRate => 'Savings rate';

  @override
  String get systemDefault => 'System Default';

  @override
  String get selectPayday => 'Select Payday';

  @override
  String get errorFailedToExport => 'Failed to export data';

  @override
  String get selectIcon => 'Select Icon';

  @override
  String get continueLabel => 'Continue';

  @override
  String get errorFailedToLoadData => 'Failed to load data';

  @override
  String confirmDeleteTransactionMessage(String type, String amount) {
    return 'Are you sure you want to delete this $type of $amount?';
  }

  @override
  String paydayDayLabel(int day) {
    return 'Day $day';
  }
}
