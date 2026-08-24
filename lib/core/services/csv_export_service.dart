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
  static const header = 'Date,Type,Amount,Category,Note';

  /// Serializes [transactions] to CSV. [categoryNameFor] resolves a category
  /// id to its display name — passed in rather than looked up here so this
  /// stays free of any provider or database dependency.
  String buildCsv(
    List<TransactionModel> transactions,
    String Function(String categoryId) categoryNameFor,
  ) {
    final buffer = StringBuffer()..writeln(header);

    for (final tx in transactions) {
      buffer.writeln(
        [
          tx.date.toIso8601String().substring(0, 10),
          tx.type,
          tx.amount,
          categoryNameFor(tx.categoryId),
          tx.note ?? '',
        ].map(csvField).join(','),
      );
    }

    return buffer.toString();
  }

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
