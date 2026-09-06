import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:finta/core/theme/app_theme.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/screens/transactions/widgets/date_picker_field.dart';

void main() {
  setUpAll(initializeDateFormatting);
  for (final offset in [-10, 0, 10]) {
    for (final language in ['en', 'id']) {
      testWidgets(
        'date picker preserves imported date offset=$offset locale=$language',
        (tester) async {
          final now = DateTime.now();
          final selected = DateTime(now.year + offset, 6, 15, 18, 30);
          DateTime? saved;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale(language),
              home: Scaffold(
                body: DatePickerField(
                  selectedDate: selected,
                  onDateSelected: (date) => saved = date,
                ),
              ),
            ),
          );
          await tester.tap(find.byType(InkWell).first);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(find.byType(DatePickerDialog), findsOneWidget);
          final dialog = tester.widget<DatePickerDialog>(
            find.byType(DatePickerDialog),
          );
          final day = DateTime(selected.year, selected.month, selected.day);
          expect(dialog.initialDate, day);
          expect(dialog.firstDate.isAfter(day), isFalse);
          expect(dialog.lastDate.isBefore(day), isFalse);
          final context = tester.element(find.byType(DatePickerDialog));
          await tester.tap(
            find.text(MaterialLocalizations.of(context).okButtonLabel),
          );
          await tester.pumpAndSettle();
          expect(saved, day);
          expect(find.byType(DatePickerDialog), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
