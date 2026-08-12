import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/transaction_display.dart';

void main() {
  group('transactionTitle', () {
    test('leads with the note, then the merchant', () {
      expect(
        transactionTitle(
          note: 'Two lattes',
          merchant: 'Starbucks',
          categoryName: 'Food & Drinks',
        ),
        'Two lattes · Starbucks',
      );
    });

    test('falls back to the merchant alone when there is no note', () {
      expect(
        transactionTitle(
          note: null,
          merchant: 'Starbucks',
          categoryName: 'Food & Drinks',
        ),
        'Starbucks',
      );
    });

    test('falls back to the note alone when there is no merchant', () {
      expect(
        transactionTitle(
          note: 'Two lattes',
          merchant: null,
          categoryName: 'Food & Drinks',
        ),
        'Two lattes',
      );
    });

    test('falls back to the category when neither is set', () {
      expect(
        transactionTitle(note: null, merchant: null, categoryName: 'Transport'),
        'Transport',
      );
    });

    test('treats blank strings as absent', () {
      // Empty-but-not-null is what the forms actually store for a note the
      // user tabbed through, so it must not produce a leading separator.
      expect(
        transactionTitle(note: '   ', merchant: '', categoryName: 'Transport'),
        'Transport',
      );
      expect(
        transactionTitle(note: '  Lunch  ', merchant: '', categoryName: 'Food'),
        'Lunch',
      );
    });

    test('a transfer always shows the transfer label', () {
      expect(
        transactionTitle(
          note: 'Two lattes',
          merchant: 'Starbucks',
          categoryName: 'Transfer',
          isTransfer: true,
          transferLabel: 'Transfer',
        ),
        'Transfer',
      );
    });
  });

  group('transactionSubtitle', () {
    test('shows category and account', () {
      expect(
        transactionSubtitle(categoryName: 'Food & Drinks', accountName: 'My Wallet'),
        'Food & Drinks · My Wallet',
      );
    });

    test('omits a missing account', () {
      expect(
        transactionSubtitle(categoryName: 'Food & Drinks', accountName: null),
        'Food & Drinks',
      );
    });

    test('drops the category for a transfer, leaving the account', () {
      // Both transfer legs are filed under the system Transfer category,
      // which says nothing the title hasn't already said.
      expect(
        transactionSubtitle(
          categoryName: 'Transfer',
          accountName: 'Savings',
          isTransfer: true,
        ),
        'Savings',
      );
    });

    test('appends the goal or debt last, after the account', () {
      expect(
        transactionSubtitle(
          categoryName: 'Savings & Goals',
          accountName: 'My Wallet',
          goalOrDebtName: 'New Laptop',
        ),
        'Savings & Goals · My Wallet · New Laptop',
      );
    });

    test('an ordinary transaction reads exactly as it did before', () {
      // Regression guard: the goal part is opt-in, so the common case must be
      // byte-identical to the two-part subtitle.
      expect(
        transactionSubtitle(
          categoryName: 'Food & Drinks',
          accountName: 'My Wallet',
          goalOrDebtName: null,
        ),
        'Food & Drinks · My Wallet',
      );
    });

    test('treats a blank goal name as absent', () {
      expect(
        transactionSubtitle(
          categoryName: 'Food & Drinks',
          accountName: 'My Wallet',
          goalOrDebtName: '  ',
        ),
        'Food & Drinks · My Wallet',
      );
    });

    test('survives a missing account, keeping category and goal', () {
      expect(
        transactionSubtitle(
          categoryName: 'Savings & Goals',
          accountName: null,
          goalOrDebtName: 'New Laptop',
        ),
        'Savings & Goals · New Laptop',
      );
    });

    test('never repeats the note that the title already carries', () {
      // Regression guard: the note used to be the third subtitle part and
      // was the first thing lost to the single-line ellipsis.
      final subtitle = transactionSubtitle(
        categoryName: 'Food & Drinks',
        accountName: 'My Wallet',
      );
      expect(subtitle.contains('Two lattes'), isFalse);
    });
  });
}
