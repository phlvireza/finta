import '../../l10n/app_localizations.dart';
import '../../models/category_model.dart';

/// The name to show for [category] in the active locale.
///
/// Seeded categories are stored under their English names because those names
/// are load-bearing: `Migrations.seedCategoryRecolours` and
/// `SeedData.shippedColorFor` both match on them, and the CSV export writes
/// them so a re-import can find the same category again. Translating them in
/// the database would break all three, and would have to re-translate every
/// row each time the user switched language.
///
/// So the stored name stays canonical and only the display is localized. A
/// category the user created is shown exactly as they typed it — their words
/// are not ours to translate.
String categoryDisplayName(CategoryModel category, AppLocalizations loc) {
  if (!category.isDefault) return category.name;
  return seedCategoryDisplayName(category.name, loc) ?? category.name;
}

/// [categoryDisplayName] for a lookup that may not have resolved, returning
/// [fallback] when it didn't.
///
/// Almost every caller reads a category out of `getCategoryById`, which is
/// nullable — a transaction can outlive a hard-deleted category. Without this
/// each of them spells the same null check out longhand.
String categoryDisplayNameOr(
  CategoryModel? category,
  AppLocalizations loc, {
  required String fallback,
}) {
  return category == null ? fallback : categoryDisplayName(category, loc);
}

/// The translation for a seeded category's canonical English name, or null if
/// [canonicalName] isn't one the app seeds.
///
/// Falling back to null (and, in [categoryDisplayName], to the stored name)
/// rather than to a placeholder matters for a default the user somehow
/// renamed: showing their text is right, showing "???" is not.
String? seedCategoryDisplayName(String canonicalName, AppLocalizations loc) {
  switch (canonicalName) {
    // Expense — SeedData.defaultExpenseCategories, in order.
    case 'Food & Drinks':
      return loc.seedCategoryFoodDrinks;
    case 'Transport':
      return loc.seedCategoryTransport;
    case 'Shopping':
      return loc.seedCategoryShopping;
    case 'Bills & Utilities':
      return loc.seedCategoryBillsUtilities;
    case 'Entertainment':
      return loc.seedCategoryEntertainment;
    case 'Health':
      return loc.seedCategoryHealth;
    case 'Education':
      return loc.seedCategoryEducation;
    case 'Groceries':
      return loc.seedCategoryGroceries;
    // Shared by the expense and income lists — both are "Other", and every
    // language the app supports uses one word for both.
    case 'Other':
      return loc.seedCategoryOther;

    // Income — SeedData.defaultIncomeCategories, in order.
    case 'Salary':
      return loc.seedCategorySalary;
    case 'Freelance':
      return loc.seedCategoryFreelance;
    case 'Gift':
      return loc.seedCategoryGift;
    case 'Investment':
      return loc.seedCategoryInvestment;

    // The fixed-id seeds.
    case 'Transfer':
      return loc.seedCategoryTransfer;
    case 'Savings & Goals':
      return loc.seedCategorySavingsGoals;
    case 'Debt Payments':
      return loc.seedCategoryDebtPayments;
    case 'Debt Repayments':
      return loc.seedCategoryDebtRepayments;
    case 'Donation':
      return loc.seedCategoryDonation;

    default:
      return null;
  }
}
