import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/merchant_utils.dart';

/// Merchant is free text, so the same shop arrives spelled several ways.
/// These tests pin the fold that makes "Netflix", "netflix" and "Netflix "
/// one merchant — and, just as importantly, that it happens *before* any
/// top-N cut, which is the part a naive implementation gets wrong.
void main() {
  group('normalizeMerchant', () {
    test('lowercases', () {
      expect(normalizeMerchant('Netflix'), 'netflix');
      expect(normalizeMerchant('NETFLIX'), 'netflix');
    });

    test('trims surrounding whitespace', () {
      expect(normalizeMerchant('  Netflix '), 'netflix');
    });

    test('collapses internal whitespace', () {
      expect(normalizeMerchant('Kopi  Kenangan'), 'kopi kenangan');
      expect(normalizeMerchant('Kopi\tKenangan'), 'kopi kenangan');
    });

    test('all three variants land on the same key', () {
      const variants = ['Netflix', 'netflix ', ' NETFLIX', 'Net  flix'];
      // The last one is genuinely different — two words, not one — and must
      // NOT fold in with the rest.
      expect(variants.take(3).map(normalizeMerchant).toSet(), hasLength(1));
      expect(normalizeMerchant(variants.last), isNot('netflix'));
    });

    test('an empty or whitespace-only name normalizes to empty', () {
      expect(normalizeMerchant(''), '');
      expect(normalizeMerchant('   '), '');
    });
  });

  group('hasMerchant', () {
    test('rejects null, empty and whitespace-only', () {
      expect(hasMerchant(null), isFalse);
      expect(hasMerchant(''), isFalse);
      expect(hasMerchant('  '), isFalse);
    });

    test('accepts anything with a visible character', () {
      expect(hasMerchant('a'), isTrue);
      expect(hasMerchant(' Netflix '), isTrue);
    });
  });

  group('foldMerchantTotals', () {
    test('adds variants of the same merchant together', () {
      final result = foldMerchantTotals([
        (merchant: 'Netflix', total: 100, count: 1),
        (merchant: 'netflix', total: 50, count: 2),
        (merchant: ' NETFLIX ', total: 25, count: 1),
      ]);

      expect(result, hasLength(1));
      expect(result.single.total, 175);
      expect(result.single.count, 4);
      expect(result.single.key, 'netflix');
    });

    test('shows the spelling used most often', () {
      final result = foldMerchantTotals([
        (merchant: 'NETFLIX', total: 10, count: 1),
        (merchant: 'netflix', total: 30, count: 3),
      ]);

      expect(result.single.merchant, 'netflix');
    });

    test('breaks a frequency tie towards mixed case, not shouting', () {
      // Regression guard: with no tie-break beyond source order this was
      // decided by however the database returned the rows, so the same data
      // could render as "NETFLIX" or "Netflix" on different runs.
      final shoutingFirst = foldMerchantTotals([
        (merchant: 'NETFLIX', total: 10, count: 1),
        (merchant: 'Netflix', total: 10, count: 1),
        (merchant: 'netflix', total: 10, count: 1),
      ]);
      final shoutingLast = foldMerchantTotals([
        (merchant: 'netflix', total: 10, count: 1),
        (merchant: 'Netflix', total: 10, count: 1),
        (merchant: 'NETFLIX', total: 10, count: 1),
      ]);

      expect(shoutingFirst.single.merchant, 'Netflix');
      expect(shoutingLast.single.merchant, 'Netflix');
    });

    test('frequency outranks capitalisation', () {
      final result = foldMerchantTotals([
        (merchant: 'Netflix', total: 10, count: 1),
        (merchant: 'NETFLIX', total: 50, count: 5),
      ]);

      expect(result.single.merchant, 'NETFLIX');
    });

    test('tidies whitespace in the displayed name', () {
      final result = foldMerchantTotals([
        (merchant: '  Kopi   Kenangan ', total: 10, count: 1),
      ]);

      expect(result.single.merchant, 'Kopi Kenangan');
    });

    test('keeps genuinely different names apart', () {
      // "sbux" and "SBUX Coffee" are two words versus one — different
      // merchants, not two spellings of the same one.
      final result = foldMerchantTotals([
        (merchant: 'sbux', total: 10, count: 1),
        (merchant: 'SBUX Coffee', total: 10, count: 1),
      ]);

      expect(result, hasLength(2));
    });

    test('ranks by total, highest first', () {
      final result = foldMerchantTotals([
        (merchant: 'Small', total: 10, count: 1),
        (merchant: 'Big', total: 900, count: 1),
        (merchant: 'Medium', total: 100, count: 1),
      ]);

      expect(result.map((m) => m.merchant).toList(), ['Big', 'Medium', 'Small']);
    });

    test('folds before applying the limit, not after', () {
      // Split three ways, Netflix outspends everything. Ranked on raw
      // spellings first it would place 4th, 5th and 6th and be cut entirely.
      final result = foldMerchantTotals([
        (merchant: 'Netflix', total: 40, count: 1),
        (merchant: 'netflix', total: 40, count: 1),
        (merchant: 'NETFLIX', total: 40, count: 1),
        (merchant: 'Alfamart', total: 90, count: 1),
        (merchant: 'Indomaret', total: 80, count: 1),
      ], limit: 2);

      expect(result.map((m) => m.merchant).toList(), ['Netflix', 'Alfamart']);
      expect(result.first.total, 120);
    });

    test('drops blank merchants rather than inventing an empty-named one', () {
      final result = foldMerchantTotals([
        (merchant: '', total: 500, count: 3),
        (merchant: '   ', total: 500, count: 3),
        (merchant: 'Alfamart', total: 10, count: 1),
      ]);

      expect(result.map((m) => m.merchant).toList(), ['Alfamart']);
    });

    test('an empty input folds to an empty list', () {
      expect(foldMerchantTotals(const []), isEmpty);
    });

    test('a limit larger than the data returns everything', () {
      final result = foldMerchantTotals([
        (merchant: 'Alfamart', total: 10, count: 1),
      ], limit: 10);

      expect(result, hasLength(1));
    });
  });
}
