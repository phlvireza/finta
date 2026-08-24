import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/transaction_model.dart';
import '../utils/export_cleanup.dart';

/// Writes transactions out as Squirio's own CSV shape.
///
/// Split out of the settings screen so [buildCsv] is a pure string function:
/// the round trip this format promises — export a file, import it back — is
/// only assertable if the serializer can run without a widget tree. The
/// import half lives in `csv_import_service.dart` and is pure for the same
/// reason.
class CsvExportService {
  /// The header this export writes, and the one
  /// `CsvImportScreen._guessColumn` auto-detects on the way back in.
  ///
  /// A data-interchange contract, not UI copy: it must stay exactly this in
  /// every locale. Translating it would silently break column auto-detection
  /// for Indonesian users re-importing their own export, and any bank or
  /// spreadsheet tool reading the file.
  static const header =
      'Date,Type,Amount,Category,Account,To Account,Merchant,Note';

  /// Serializes [transactions] to CSV. [categoryNameFor] and [accountNameFor]
  /// resolve ids to display names — passed in rather than looked up here so
  /// this stays free of any provider or database dependency.
  ///
  /// A transfer is stored as two linked rows (an expense on the source account
  /// and an income on the destination, sharing a `transferId`). It is written
  /// out as a **single** row of type `transfer` naming both accounts, which is
  /// how a person reads it in a spreadsheet and — more importantly — cannot be
  /// half-deleted by hand into an orphan leg. The importer expands it back into
  /// the pair.
  String buildCsv(
    List<TransactionModel> transactions,
    String Function(String categoryId) categoryNameFor,
    String Function(String accountId) accountNameFor,
  ) {
    final buffer = StringBuffer()..writeln(header);

    // Legs are matched by transferId. Emitting at the position of the first leg
    // seen keeps the file in the order the caller supplied; `written` stops the
    // partner emitting a second row when the walk reaches it.
    final legsByTransfer = <String, List<TransactionModel>>{};
    for (final tx in transactions) {
      final id = tx.transferId;
      if (id != null) (legsByTransfer[id] ??= []).add(tx);
    }
    final written = <String>{};

    for (final tx in transactions) {
      final transferId = tx.transferId;
      final legs = transferId == null ? null : legsByTransfer[transferId];

      // A transferId with no partner should not exist, but a corrupted
      // database or a row predating the pairing could produce one. Fall
      // through and write it as an ordinary row rather than dropping it.
      if (legs != null && legs.length == 2) {
        if (!written.add(transferId!)) continue;
        final from = legs.firstWhere((l) => l.type == 'expense');
        final to = legs.firstWhere((l) => l.type == 'income');
        buffer.writeln(
          _row(
            date: tx.date,
            type: 'transfer',
            amount: tx.amount,
            category: categoryNameFor(tx.categoryId),
            account: accountNameFor(from.accountId),
            toAccount: accountNameFor(to.accountId),
            merchant: tx.merchant,
            note: tx.note,
          ),
        );
        continue;
      }

      buffer.writeln(
        _row(
          date: tx.date,
          type: tx.type,
          amount: tx.amount,
          category: categoryNameFor(tx.categoryId),
          account: accountNameFor(tx.accountId),
          toAccount: null,
          merchant: tx.merchant,
          note: tx.note,
        ),
      );
    }

    return buffer.toString();
  }

  String _row({
    required DateTime date,
    required String type,
    required double amount,
    required String category,
    required String account,
    required String? toAccount,
    required String? merchant,
    required String? note,
  }) => [
    date.toIso8601String().substring(0, 10),
    type,
    amount,
    category,
    account,
    toAccount ?? '',
    merchant ?? '',
    note ?? '',
  ].map(csvField).join(',');

  /// Quote a field only when it contains a character that would otherwise
  /// break column alignment, doubling any embedded quotes.
  static String csvField(Object value) {
    final s = value.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  /// Writes [csv] to the documents directory and opens the OS share sheet.
  ///
  /// [shareSubject] is passed in because this class has no [BuildContext] —
  /// the same arrangement `BackupService.shareBackup` uses.
  Future<void> shareCsv(String csv, String shareSubject) async {
    final directory = await getApplicationDocumentsDirectory();
    // Both prefixes: exports written before the Squirio rename still need
    // cleaning up, and a user who has been on the app across the rename has
    // generations under each.
    await pruneExports(directory, prefix: 'finta_export_', extension: '.csv');
    await pruneExports(directory, prefix: 'squirio_export_', extension: '.csv');

    final file = File(
      '${directory.path}/squirio_export_${DateTime.now().millisecondsSinceEpoch}.csv',
    );
    await file.writeAsString(csv);

    await Share.shareXFiles([XFile(file.path)], subject: shareSubject);
  }
}
