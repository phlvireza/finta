import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_id.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('id'),
  ];

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currency;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @payday.
  ///
  /// In en, this message translates to:
  /// **'Payday (Cycle Reset)'**
  String get payday;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @budgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgets;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurring;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Data'**
  String get data;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export as CSV'**
  String get exportCsv;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @totalBalance.
  ///
  /// In en, this message translates to:
  /// **'Total Balance'**
  String get totalBalance;

  /// No description provided for @netThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'Net This Period'**
  String get netThisPeriod;

  /// No description provided for @income.
  ///
  /// In en, this message translates to:
  /// **'Income'**
  String get income;

  /// No description provided for @expense.
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get expense;

  /// No description provided for @recentTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recent Transactions'**
  String get recentTransactions;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @noRecentTransactions.
  ///
  /// In en, this message translates to:
  /// **'No recent transactions'**
  String get noRecentTransactions;

  /// No description provided for @expenseBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Expense Breakdown'**
  String get expenseBreakdown;

  /// No description provided for @noDataForThisPeriod.
  ///
  /// In en, this message translates to:
  /// **'No data for this period'**
  String get noDataForThisPeriod;

  /// No description provided for @totalSpent.
  ///
  /// In en, this message translates to:
  /// **'Total Spent'**
  String get totalSpent;

  /// No description provided for @totalIncome.
  ///
  /// In en, this message translates to:
  /// **'Total Income'**
  String get totalIncome;

  /// No description provided for @totalExpense.
  ///
  /// In en, this message translates to:
  /// **'Total Expense'**
  String get totalExpense;

  /// No description provided for @addTransaction.
  ///
  /// In en, this message translates to:
  /// **'Add Transaction'**
  String get addTransaction;

  /// No description provided for @editTransaction.
  ///
  /// In en, this message translates to:
  /// **'Edit Transaction'**
  String get editTransaction;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @amount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get amount;

  /// No description provided for @date.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// No description provided for @saveTransaction.
  ///
  /// In en, this message translates to:
  /// **'Save Transaction'**
  String get saveTransaction;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @pleaseEnterValidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount'**
  String get pleaseEnterValidAmount;

  /// No description provided for @pleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get pleaseSelectCategory;

  /// No description provided for @moreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get moreOptions;

  /// No description provided for @manageCategories.
  ///
  /// In en, this message translates to:
  /// **'Manage Categories'**
  String get manageCategories;

  /// No description provided for @addCategory.
  ///
  /// In en, this message translates to:
  /// **'Add Category'**
  String get addCategory;

  /// No description provided for @editCategory.
  ///
  /// In en, this message translates to:
  /// **'Edit Category'**
  String get editCategory;

  /// No description provided for @categoryName.
  ///
  /// In en, this message translates to:
  /// **'Category Name'**
  String get categoryName;

  /// No description provided for @icon.
  ///
  /// In en, this message translates to:
  /// **'Icon'**
  String get icon;

  /// No description provided for @color.
  ///
  /// In en, this message translates to:
  /// **'Color'**
  String get color;

  /// No description provided for @manageBudgets.
  ///
  /// In en, this message translates to:
  /// **'Manage Budgets'**
  String get manageBudgets;

  /// No description provided for @addBudget.
  ///
  /// In en, this message translates to:
  /// **'Add Budget'**
  String get addBudget;

  /// No description provided for @editBudget.
  ///
  /// In en, this message translates to:
  /// **'Edit Budget'**
  String get editBudget;

  /// No description provided for @budgetAmount.
  ///
  /// In en, this message translates to:
  /// **'Budget Amount'**
  String get budgetAmount;

  /// No description provided for @spent.
  ///
  /// In en, this message translates to:
  /// **'Spent'**
  String get spent;

  /// No description provided for @remaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining'**
  String get remaining;

  /// No description provided for @recurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'Recurring Transactions'**
  String get recurringTransactions;

  /// No description provided for @addRecurring.
  ///
  /// In en, this message translates to:
  /// **'Add Recurring'**
  String get addRecurring;

  /// No description provided for @frequency.
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// No description provided for @daily.
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get daily;

  /// No description provided for @weekly.
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get weekly;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get yearly;

  /// No description provided for @nextDate.
  ///
  /// In en, this message translates to:
  /// **'Next Date'**
  String get nextDate;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @welcomeToFinta.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Finta'**
  String get welcomeToFinta;

  /// No description provided for @trackYourExpensesEasily.
  ///
  /// In en, this message translates to:
  /// **'Track your expenses easily.'**
  String get trackYourExpensesEasily;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this?'**
  String get confirmDelete;

  /// No description provided for @archive.
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get archive;

  /// No description provided for @archiveCategory.
  ///
  /// In en, this message translates to:
  /// **'Archive Category'**
  String get archiveCategory;

  /// No description provided for @confirmDeleteCategory.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This category has no transactions, so it can be safely removed.'**
  String confirmDeleteCategory(String name);

  /// No description provided for @confirmArchiveCategory.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is used by {count} transaction(s). It will be hidden from new entries but those transactions will keep their category label — nothing is deleted.'**
  String confirmArchiveCategory(String name, int count);

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @yearlyReport.
  ///
  /// In en, this message translates to:
  /// **'Yearly Report'**
  String get yearlyReport;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @netSavings.
  ///
  /// In en, this message translates to:
  /// **'Net Savings'**
  String get netSavings;

  /// No description provided for @searchNotes.
  ///
  /// In en, this message translates to:
  /// **'Search notes...'**
  String get searchNotes;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noTransactionsFound.
  ///
  /// In en, this message translates to:
  /// **'No transactions found'**
  String get noTransactionsFound;

  /// No description provided for @tryAdjustingSearch.
  ///
  /// In en, this message translates to:
  /// **'Try adjusting your search'**
  String get tryAdjustingSearch;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t added any transactions yet'**
  String get noTransactionsYet;

  /// No description provided for @incomeAmount.
  ///
  /// In en, this message translates to:
  /// **'Income Amount'**
  String get incomeAmount;

  /// No description provided for @expenseAmount.
  ///
  /// In en, this message translates to:
  /// **'Expense Amount'**
  String get expenseAmount;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @selectACategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category...'**
  String get selectACategory;

  /// No description provided for @searchCategories.
  ///
  /// In en, this message translates to:
  /// **'Search categories...'**
  String get searchCategories;

  /// No description provided for @createNewCategory.
  ///
  /// In en, this message translates to:
  /// **'Create New Category'**
  String get createNewCategory;

  /// No description provided for @noCategoriesFound.
  ///
  /// In en, this message translates to:
  /// **'No categories found'**
  String get noCategoriesFound;

  /// No description provided for @makeThisRecurring.
  ///
  /// In en, this message translates to:
  /// **'Make this recurring?'**
  String get makeThisRecurring;

  /// No description provided for @biweekly.
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get biweekly;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterName;

  /// No description provided for @noBudgetsYet.
  ///
  /// In en, this message translates to:
  /// **'No budgets yet'**
  String get noBudgetsYet;

  /// No description provided for @setMonthlyLimits.
  ///
  /// In en, this message translates to:
  /// **'Set monthly limits to track your spending'**
  String get setMonthlyLimits;

  /// No description provided for @ofString.
  ///
  /// In en, this message translates to:
  /// **'of'**
  String get ofString;

  /// No description provided for @deleteBudget.
  ///
  /// In en, this message translates to:
  /// **'Delete Budget'**
  String get deleteBudget;

  /// No description provided for @removeBudgetFor.
  ///
  /// In en, this message translates to:
  /// **'Remove the budget for {category}?'**
  String removeBudgetFor(String category);

  /// No description provided for @newBudget.
  ///
  /// In en, this message translates to:
  /// **'New Budget'**
  String get newBudget;

  /// No description provided for @saveBudget.
  ///
  /// In en, this message translates to:
  /// **'Save Budget'**
  String get saveBudget;

  /// No description provided for @budgetAlreadyExistsForCategory.
  ///
  /// In en, this message translates to:
  /// **'A budget already exists for this category'**
  String get budgetAlreadyExistsForCategory;

  /// No description provided for @used.
  ///
  /// In en, this message translates to:
  /// **'used'**
  String get used;

  /// No description provided for @spentString.
  ///
  /// In en, this message translates to:
  /// **'spent'**
  String get spentString;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get left;

  /// No description provided for @noRecurringTransactions.
  ///
  /// In en, this message translates to:
  /// **'No recurring transactions'**
  String get noRecurringTransactions;

  /// No description provided for @enableRecurringWhenAdding.
  ///
  /// In en, this message translates to:
  /// **'Enable \"recurring\" when adding a transaction'**
  String get enableRecurringWhenAdding;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @stopRecurring.
  ///
  /// In en, this message translates to:
  /// **'Stop Recurring'**
  String get stopRecurring;

  /// No description provided for @stopRecurringMessage.
  ///
  /// In en, this message translates to:
  /// **'This will stop future transactions from being generated automatically. Existing transactions will remain.'**
  String get stopRecurringMessage;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @trackYourMoney.
  ///
  /// In en, this message translates to:
  /// **'Track your money,\nnot your stress'**
  String get trackYourMoney;

  /// No description provided for @chooseYourCurrency.
  ///
  /// In en, this message translates to:
  /// **'Choose your currency'**
  String get chooseYourCurrency;

  /// No description provided for @currencyDisplayOnly.
  ///
  /// In en, this message translates to:
  /// **'This is just for display — no conversion'**
  String get currencyDisplayOnly;

  /// No description provided for @whenDoYouGetPaid.
  ///
  /// In en, this message translates to:
  /// **'When do you get paid?'**
  String get whenDoYouGetPaid;

  /// No description provided for @paydayDescription.
  ///
  /// In en, this message translates to:
  /// **'Your tracking period resets on this day each month'**
  String get paydayDescription;

  /// No description provided for @startTracking.
  ///
  /// In en, this message translates to:
  /// **'Start Tracking'**
  String get startTracking;

  /// No description provided for @budgetExceededAlert.
  ///
  /// In en, this message translates to:
  /// **'You\'ve exceeded your budget for this category'**
  String get budgetExceededAlert;

  /// No description provided for @budgetWarningAlert.
  ///
  /// In en, this message translates to:
  /// **'Heads up — you\'ve used {pct}% of your budget'**
  String budgetWarningAlert(Object pct);

  /// No description provided for @errorFailedToSave.
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Please try again.'**
  String get errorFailedToSave;

  /// No description provided for @errorFailedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete. Please try again.'**
  String get errorFailedToDelete;

  /// No description provided for @categoryAlreadyExists.
  ///
  /// In en, this message translates to:
  /// **'A category with this name already exists'**
  String get categoryAlreadyExists;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @overBudget.
  ///
  /// In en, this message translates to:
  /// **'Over Budget!'**
  String get overBudget;

  /// No description provided for @backupYourData.
  ///
  /// In en, this message translates to:
  /// **'Backup your data'**
  String get backupYourData;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @dueToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dueToday;

  /// No description provided for @dueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get dueTomorrow;

  /// No description provided for @dueInDays.
  ///
  /// In en, this message translates to:
  /// **'in {days} days'**
  String dueInDays(int days);

  /// No description provided for @showAllCount.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count})'**
  String showAllCount(int count);

  /// No description provided for @createFirstBudget.
  ///
  /// In en, this message translates to:
  /// **'Create your first budget'**
  String get createFirstBudget;

  /// No description provided for @addTransactionCta.
  ///
  /// In en, this message translates to:
  /// **'Add a transaction'**
  String get addTransactionCta;

  /// No description provided for @createCategory.
  ///
  /// In en, this message translates to:
  /// **'Create a category'**
  String get createCategory;

  /// No description provided for @createFirstRecurring.
  ///
  /// In en, this message translates to:
  /// **'Set up recurring transactions'**
  String get createFirstRecurring;

  /// No description provided for @quarter.
  ///
  /// In en, this message translates to:
  /// **'Quarter'**
  String get quarter;

  /// No description provided for @year.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get year;

  /// No description provided for @noTransactionsOnThisDay.
  ///
  /// In en, this message translates to:
  /// **'No transactions on this day'**
  String get noTransactionsOnThisDay;

  /// No description provided for @period.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get period;

  /// No description provided for @paceAhead.
  ///
  /// In en, this message translates to:
  /// **'Ahead of pace'**
  String get paceAhead;

  /// No description provided for @paceOnTrack.
  ///
  /// In en, this message translates to:
  /// **'On track'**
  String get paceOnTrack;

  /// No description provided for @paceUnder.
  ///
  /// In en, this message translates to:
  /// **'Under pace'**
  String get paceUnder;

  /// No description provided for @safeToSpendPerDay.
  ///
  /// In en, this message translates to:
  /// **'Safe to spend: {amount}/day for {days} more days'**
  String safeToSpendPerDay(String amount, int days);

  /// No description provided for @percentOfIncomeSpent.
  ///
  /// In en, this message translates to:
  /// **'{percent} of income spent'**
  String percentOfIncomeSpent(String percent);

  /// No description provided for @filters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filters;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get clearFilters;

  /// No description provided for @dateRange.
  ///
  /// In en, this message translates to:
  /// **'Date range'**
  String get dateRange;

  /// No description provided for @anyTime.
  ///
  /// In en, this message translates to:
  /// **'Any time'**
  String get anyTime;

  /// No description provided for @thisPeriod.
  ///
  /// In en, this message translates to:
  /// **'This period'**
  String get thisPeriod;

  /// No description provided for @lastPeriod.
  ///
  /// In en, this message translates to:
  /// **'Last period'**
  String get lastPeriod;

  /// No description provided for @last3Months.
  ///
  /// In en, this message translates to:
  /// **'Last 3 months'**
  String get last3Months;

  /// No description provided for @customRange.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get customRange;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @amountRange.
  ///
  /// In en, this message translates to:
  /// **'Amount range'**
  String get amountRange;

  /// No description provided for @minAmount.
  ///
  /// In en, this message translates to:
  /// **'Min'**
  String get minAmount;

  /// No description provided for @maxAmount.
  ///
  /// In en, this message translates to:
  /// **'Max'**
  String get maxAmount;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply filters'**
  String get applyFilters;

  /// No description provided for @transactionsSummary.
  ///
  /// In en, this message translates to:
  /// **'{count} transactions · {total}'**
  String transactionsSummary(int count, String total);

  /// No description provided for @whereItWent.
  ///
  /// In en, this message translates to:
  /// **'Where it went'**
  String get whereItWent;

  /// No description provided for @budgetPerformance.
  ///
  /// In en, this message translates to:
  /// **'Budget performance'**
  String get budgetPerformance;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @paceInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending pace'**
  String get paceInfoTitle;

  /// No description provided for @paceExplanation.
  ///
  /// In en, this message translates to:
  /// **'Compares how much of the budget you\'ve spent to how far through the period you are. The tick on the bar marks today — if the colored fill has passed it, you\'re spending faster than the days are passing (ahead of pace); if it hasn\'t reached the tick yet, you\'re spending slower (under pace).'**
  String get paceExplanation;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @manageAccounts.
  ///
  /// In en, this message translates to:
  /// **'Manage Accounts'**
  String get manageAccounts;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get editAccount;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Account Name'**
  String get accountName;

  /// No description provided for @accountType.
  ///
  /// In en, this message translates to:
  /// **'Account Type'**
  String get accountType;

  /// No description provided for @openingBalance.
  ///
  /// In en, this message translates to:
  /// **'Opening Balance'**
  String get openingBalance;

  /// No description provided for @creditLimitOptional.
  ///
  /// In en, this message translates to:
  /// **'Credit Limit (optional)'**
  String get creditLimitOptional;

  /// No description provided for @includeInTotal.
  ///
  /// In en, this message translates to:
  /// **'Include in totals'**
  String get includeInTotal;

  /// No description provided for @includeInTotalDescription.
  ///
  /// In en, this message translates to:
  /// **'Counts toward net worth and available cash'**
  String get includeInTotalDescription;

  /// No description provided for @netWorth.
  ///
  /// In en, this message translates to:
  /// **'Net Worth'**
  String get netWorth;

  /// No description provided for @selectAnAccount.
  ///
  /// In en, this message translates to:
  /// **'Select an account'**
  String get selectAnAccount;

  /// No description provided for @noAccountsYet.
  ///
  /// In en, this message translates to:
  /// **'No accounts yet'**
  String get noAccountsYet;

  /// No description provided for @noAccountsYetMessage.
  ///
  /// In en, this message translates to:
  /// **'Add an account to start tracking balances across your wallets, banks, and cards'**
  String get noAccountsYetMessage;

  /// No description provided for @archiveAccount.
  ///
  /// In en, this message translates to:
  /// **'Archive Account'**
  String get archiveAccount;

  /// No description provided for @confirmArchiveAccountUnused.
  ///
  /// In en, this message translates to:
  /// **'Archive \"{name}\"? It will be hidden from new entries.'**
  String confirmArchiveAccountUnused(String name);

  /// No description provided for @confirmArchiveAccount.
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" is used by {count} transaction(s). It will be hidden from new entries but those transactions will keep their account label — nothing is deleted.'**
  String confirmArchiveAccount(String name, int count);

  /// No description provided for @amountOwed.
  ///
  /// In en, this message translates to:
  /// **'{amount} owed'**
  String amountOwed(String amount);

  /// No description provided for @accountTypeCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get accountTypeCash;

  /// No description provided for @accountTypeBank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get accountTypeBank;

  /// No description provided for @accountTypeCreditCard.
  ///
  /// In en, this message translates to:
  /// **'Credit Card'**
  String get accountTypeCreditCard;

  /// No description provided for @accountTypeEWallet.
  ///
  /// In en, this message translates to:
  /// **'E-Wallet'**
  String get accountTypeEWallet;

  /// No description provided for @accountTypeSavings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get accountTypeSavings;

  /// No description provided for @accountTypeInvestment.
  ///
  /// In en, this message translates to:
  /// **'Investment'**
  String get accountTypeInvestment;

  /// No description provided for @transfer.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transfer;

  /// No description provided for @transferAmount.
  ///
  /// In en, this message translates to:
  /// **'Transfer Amount'**
  String get transferAmount;

  /// No description provided for @fromAccount.
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get fromAccount;

  /// No description provided for @toAccount.
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get toAccount;

  /// No description provided for @deleteTransfer.
  ///
  /// In en, this message translates to:
  /// **'Delete Transfer'**
  String get deleteTransfer;

  /// No description provided for @confirmDeleteTransfer.
  ///
  /// In en, this message translates to:
  /// **'Delete this transfer? Both sides of the transfer will be removed.'**
  String get confirmDeleteTransfer;

  /// No description provided for @transferOutOf.
  ///
  /// In en, this message translates to:
  /// **'Out of {account}'**
  String transferOutOf(String account);

  /// No description provided for @transferIntoAccount.
  ///
  /// In en, this message translates to:
  /// **'Into {account}'**
  String transferIntoAccount(String account);

  /// No description provided for @merchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get merchant;

  /// No description provided for @merchantHint.
  ///
  /// In en, this message translates to:
  /// **'Where did you spend?'**
  String get merchantHint;

  /// No description provided for @parentCategoryOptional.
  ///
  /// In en, this message translates to:
  /// **'Parent category (optional)'**
  String get parentCategoryOptional;

  /// No description provided for @noneTopLevel.
  ///
  /// In en, this message translates to:
  /// **'None — top-level category'**
  String get noneTopLevel;

  /// No description provided for @groupSubcategories.
  ///
  /// In en, this message translates to:
  /// **'Group sub-categories'**
  String get groupSubcategories;

  /// No description provided for @showSubcategories.
  ///
  /// In en, this message translates to:
  /// **'Show sub-categories'**
  String get showSubcategories;

  /// No description provided for @overallBudget.
  ///
  /// In en, this message translates to:
  /// **'Overall Budget'**
  String get overallBudget;

  /// No description provided for @groupBudget.
  ///
  /// In en, this message translates to:
  /// **'Group Budget'**
  String get groupBudget;

  /// No description provided for @budgetScope.
  ///
  /// In en, this message translates to:
  /// **'Budget covers'**
  String get budgetScope;

  /// No description provided for @budgetScopeCategory.
  ///
  /// In en, this message translates to:
  /// **'One category'**
  String get budgetScopeCategory;

  /// No description provided for @budgetScopeGroup.
  ///
  /// In en, this message translates to:
  /// **'Group of categories'**
  String get budgetScopeGroup;

  /// No description provided for @budgetScopeOverall.
  ///
  /// In en, this message translates to:
  /// **'Everything'**
  String get budgetScopeOverall;

  /// No description provided for @budgetName.
  ///
  /// In en, this message translates to:
  /// **'Budget name'**
  String get budgetName;

  /// No description provided for @budgetNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Budget name (optional)'**
  String get budgetNameOptional;

  /// No description provided for @budgetPeriod.
  ///
  /// In en, this message translates to:
  /// **'Period'**
  String get budgetPeriod;

  /// No description provided for @budgetRollover.
  ///
  /// In en, this message translates to:
  /// **'Rollover'**
  String get budgetRollover;

  /// No description provided for @budgetRolloverExplanation.
  ///
  /// In en, this message translates to:
  /// **'Carry unspent (or overspent) budget into the next period.'**
  String get budgetRolloverExplanation;

  /// No description provided for @rolloverNone.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get rolloverNone;

  /// No description provided for @rolloverPositiveOnly.
  ///
  /// In en, this message translates to:
  /// **'Unspent only'**
  String get rolloverPositiveOnly;

  /// No description provided for @rolloverFull.
  ///
  /// In en, this message translates to:
  /// **'Unspent or overspent'**
  String get rolloverFull;

  /// No description provided for @selectAtLeastTwoCategories.
  ///
  /// In en, this message translates to:
  /// **'Select at least two categories'**
  String get selectAtLeastTwoCategories;

  /// No description provided for @rolledOverPositive.
  ///
  /// In en, this message translates to:
  /// **'{amount} rolled over from last period'**
  String rolledOverPositive(String amount);

  /// No description provided for @rolledOverNegative.
  ///
  /// In en, this message translates to:
  /// **'{amount} over from last period'**
  String rolledOverNegative(String amount);

  /// No description provided for @backupAndRestore.
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupAndRestore;

  /// No description provided for @backupAndRestoreSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Back up your data, or import from a CSV file'**
  String get backupAndRestoreSubtitle;

  /// No description provided for @backupSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup'**
  String get backupSectionTitle;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get createBackup;

  /// No description provided for @createBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save a full copy of your data to share or store safely'**
  String get createBackupSubtitle;

  /// No description provided for @restoreFromBackup.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get restoreFromBackup;

  /// No description provided for @restoreFromBackupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Replace your data with a previously saved backup'**
  String get restoreFromBackupSubtitle;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @backupFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to create backup'**
  String get backupFailed;

  /// No description provided for @backupIncompatible.
  ///
  /// In en, this message translates to:
  /// **'This backup was made with a newer version of Finta and can\'t be restored here'**
  String get backupIncompatible;

  /// No description provided for @backupInvalidFile.
  ///
  /// In en, this message translates to:
  /// **'That file isn\'t a valid Finta backup'**
  String get backupInvalidFile;

  /// No description provided for @restoreBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore this backup?'**
  String get restoreBackupTitle;

  /// No description provided for @restoreBackupConfirm.
  ///
  /// In en, this message translates to:
  /// **'This will replace all current data with the backup from {date}. This can\'t be undone.'**
  String restoreBackupConfirm(String date);

  /// No description provided for @restoreFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore backup'**
  String get restoreFailed;

  /// No description provided for @restoreCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Backup restored'**
  String get restoreCompleteTitle;

  /// No description provided for @restoreCompleteMessage.
  ///
  /// In en, this message translates to:
  /// **'Please close and reopen Finta to finish loading your restored data.'**
  String get restoreCompleteMessage;

  /// No description provided for @csvImportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get csvImportSectionTitle;

  /// No description provided for @importCsv.
  ///
  /// In en, this message translates to:
  /// **'Import from CSV'**
  String get importCsv;

  /// No description provided for @importCsvSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bring in transactions from Finta or another app\'s export'**
  String get importCsvSubtitle;

  /// No description provided for @csvReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read that CSV file'**
  String get csvReadFailed;

  /// No description provided for @mapCsvColumns.
  ///
  /// In en, this message translates to:
  /// **'Map columns'**
  String get mapCsvColumns;

  /// No description provided for @reviewImport.
  ///
  /// In en, this message translates to:
  /// **'Review import'**
  String get reviewImport;

  /// No description provided for @csvRowsFound.
  ///
  /// In en, this message translates to:
  /// **'{count} rows found in this file'**
  String csvRowsFound(int count);

  /// No description provided for @csvColumnDate.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get csvColumnDate;

  /// No description provided for @csvColumnAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get csvColumnAmount;

  /// No description provided for @csvColumnType.
  ///
  /// In en, this message translates to:
  /// **'Type (income/expense)'**
  String get csvColumnType;

  /// No description provided for @csvColumnCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get csvColumnCategory;

  /// No description provided for @csvColumnMerchant.
  ///
  /// In en, this message translates to:
  /// **'Merchant'**
  String get csvColumnMerchant;

  /// No description provided for @csvColumnNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get csvColumnNote;

  /// No description provided for @csvImportToAccount.
  ///
  /// In en, this message translates to:
  /// **'Import into account'**
  String get csvImportToAccount;

  /// No description provided for @previewImport.
  ///
  /// In en, this message translates to:
  /// **'Preview import'**
  String get previewImport;

  /// No description provided for @csvImportSummary.
  ///
  /// In en, this message translates to:
  /// **'{ready} ready to import, {skipped} skipped'**
  String csvImportSummary(int ready, int skipped);

  /// No description provided for @csvRowNumber.
  ///
  /// In en, this message translates to:
  /// **'Row {number}'**
  String csvRowNumber(int number);

  /// No description provided for @csvNoErrors.
  ///
  /// In en, this message translates to:
  /// **'Every row looks good'**
  String get csvNoErrors;

  /// No description provided for @confirmImportCount.
  ///
  /// In en, this message translates to:
  /// **'Import {count} transactions'**
  String confirmImportCount(int count);

  /// No description provided for @csvImportedCount.
  ///
  /// In en, this message translates to:
  /// **'Imported {count} transactions'**
  String csvImportedCount(int count);

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// No description provided for @importedCategoryName.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get importedCategoryName;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'id'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'id':
      return AppLocalizationsId();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
