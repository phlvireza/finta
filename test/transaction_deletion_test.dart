import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/deletion_operation.dart';
import 'package:finta/l10n/app_localizations.dart';
import 'package:finta/screens/transactions/transaction_actions.dart';

void main() {
  test(
    'refresh failure retries only refresh after the write commits',
    () async {
      var writes = 0;
      var refreshes = 0;
      final operation = DeletionOperation(
        delete: () async {
          writes++;
        },
        refresh: () async {
          if (++refreshes == 1) throw StateError('offline');
        },
      );
      expect(await operation.run(), DeletionOutcome.committed);
      expect(operation.refreshed, isFalse);
      expect(await operation.run(), DeletionOutcome.committed);
      expect(operation.refreshed, isTrue);
      expect(writes, 1);
      expect(refreshes, 2);
    },
  );

  test('write failure does not refresh; a retry can write', () async {
    var writes = 0;
    var refreshes = 0;
    final operation = DeletionOperation(
      delete: () async {
        if (++writes == 1) throw StateError('write failed');
      },
      refresh: () async {
        refreshes++;
      },
    );
    expect(await operation.run(), DeletionOutcome.failed);
    expect(operation.committed, isFalse);
    expect(refreshes, 0);
    expect(await operation.run(), DeletionOutcome.committed);
    expect(writes, 2);
  });

  test('concurrent submissions cannot duplicate the write', () async {
    final gate = Completer<void>();
    var writes = 0;
    final operation = DeletionOperation(
      delete: () async {
        writes++;
        await gate.future;
      },
      refresh: () async {},
    );
    final first = operation.run();
    await operation.run();
    expect(writes, 1);
    gate.complete();
    expect(await first, DeletionOutcome.committed);
  });

  test('a committed provider error goes directly to refresh', () async {
    var writes = 0;
    final operation = DeletionOperation(
      delete: () async {
        writes++;
        throw DeletionCommittedException(StateError('existence read failed'));
      },
      refresh: () async {},
    );
    expect(await operation.run(), DeletionOutcome.committed);
    expect(operation.refreshed, isTrue);
    expect(writes, 1);
  });

  Future<void> openDialog(
    WidgetTester tester,
    DeletionOperation operation,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => TransactionDeleteDialog(
                  operation: operation,
                  title: 'Delete',
                  message: 'Delete this expense?',
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('cancel leaves transaction untouched', (tester) async {
    var writes = 0;
    await openDialog(
      tester,
      DeletionOperation(
        delete: () async {
          writes++;
        },
        refresh: () async {},
      ),
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(writes, 0);
    expect(find.byType(TransactionDeleteDialog), findsNothing);
  });

  testWidgets(
    'committed failure exposes refresh retry and prevents a second deletion',
    (tester) async {
      var writes = 0;
      var refreshes = 0;
      await openDialog(
        tester,
        DeletionOperation(
          delete: () async {
            writes++;
          },
          refresh: () async {
            if (++refreshes == 1) throw StateError('refresh failed');
          },
        ),
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
      await tester.pumpAndSettle();
      expect(find.text('Transaction deleted'), findsOneWidget);
      expect(find.text('Cancel'), findsNothing);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(writes, 1);
      expect(refreshes, 2);
      expect(find.byType(TransactionDeleteDialog), findsNothing);
    },
  );

  testWidgets('write error keeps confirmation open and permits cancellation', (
    tester,
  ) async {
    await openDialog(
      tester,
      DeletionOperation(
        delete: () async {
          throw StateError('write failed');
        },
        refresh: () async {},
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Failed to delete. Please try again.'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDeleteDialog), findsNothing);
  });

  testWidgets('confirmation disables its actions while the write is pending', (
    tester,
  ) async {
    final gate = Completer<void>();
    var writes = 0;
    await openDialog(
      tester,
      DeletionOperation(
        delete: () async {
          writes++;
          await gate.future;
        },
        refresh: () async {},
      ),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pump();
    expect(writes, 1);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TransactionDeleteDialog), findsNothing);
  });
}
