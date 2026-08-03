import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/template_validation.dart';

void main() {
  group('missingTemplateFields', () {
    test('is empty when amount, category, and account are all set', () {
      expect(
        missingTemplateFields(amount: 50000, categoryId: 'cat1', accountId: 'acc1'),
        isEmpty,
      );
    });

    test('flags amount when it is zero', () {
      expect(
        missingTemplateFields(amount: 0, categoryId: 'cat1', accountId: 'acc1'),
        {MissingTemplateField.amount},
      );
    });

    test('flags amount when it is negative', () {
      expect(
        missingTemplateFields(amount: -1, categoryId: 'cat1', accountId: 'acc1'),
        {MissingTemplateField.amount},
      );
    });

    test('flags category when categoryId is null', () {
      expect(
        missingTemplateFields(amount: 50000, categoryId: null, accountId: 'acc1'),
        {MissingTemplateField.category},
      );
    });

    test('flags account when accountId is null', () {
      expect(
        missingTemplateFields(amount: 50000, categoryId: 'cat1', accountId: null),
        {MissingTemplateField.account},
      );
    });

    test('flags every missing field at once', () {
      expect(
        missingTemplateFields(amount: 0, categoryId: null, accountId: null),
        {MissingTemplateField.amount, MissingTemplateField.category, MissingTemplateField.account},
      );
    });
  });
}
