import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/debt_payoff.dart';

void main() {
  group('monthsToPayOff', () {
    test('an already-settled debt takes zero months', () {
      expect(monthsToPayOff(outstanding: 0, monthlyPayment: 100000), 0);
      expect(monthsToPayOff(outstanding: -500, monthlyPayment: 100000), 0);
    });

    test('zero-interest: exact division', () {
      expect(monthsToPayOff(outstanding: 1000000, monthlyPayment: 200000), 5);
    });

    test('zero-interest: a remainder rounds up to another full month', () {
      expect(monthsToPayOff(outstanding: 1000000, monthlyPayment: 300000), 4);
    });

    test('a non-positive payment never pays off the debt', () {
      expect(monthsToPayOff(outstanding: 1000000, monthlyPayment: 0), isNull);
      expect(monthsToPayOff(outstanding: 1000000, monthlyPayment: -100), isNull);
    });

    test('with interest, more months are needed than the zero-interest case', () {
      final withInterest = monthsToPayOff(
        outstanding: 1000000,
        monthlyPayment: 200000,
        monthlyInterestRate: 0.02,
      );
      final withoutInterest = monthsToPayOff(outstanding: 1000000, monthlyPayment: 200000);
      expect(withInterest, isNotNull);
      expect(withInterest! > withoutInterest!, isTrue);
    });

    test('a payment that does not outpace interest never pays off the debt', () {
      // 1% growth on 1,000,000 is 10,000/month — a 5,000 payment can't keep up.
      final result = monthsToPayOff(
        outstanding: 1000000,
        monthlyPayment: 5000,
        monthlyInterestRate: 0.01,
      );
      expect(result, isNull);
    });
  });
}
