import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import '../exceptions/app_exceptions.dart';
import '../../l10n/app_localizations.dart';
import '../utils/export_cleanup.dart';

/// Result of validating a backup archive before restoring it.
class BackupValidation {
  final bool isCompatible;
  final int schemaVersion;
  final DateTime exportedAt;

  BackupValidation({
    required this.isCompatible,
    required this.schemaVersion,
    required this.exportedAt,
  });
}

/// Full-database backup: zips the sqlite file itself alongside a small
/// metadata manifest, rather than re-serializing every table to JSON. This
/// keeps backup/restore a byte-for-byte copy of exactly what the app has —
/// no risk of a hand-written export missing a column a future migration adds.
class BackupService {
  static const _metaFileName = 'meta.json';
  static const _dbFileName = 'finta.db';

  /// Builds a `finta_backup_<timestamp>.zip` in the app documents directory
  /// containing the live database file plus a manifest recording the
  /// schema version it was written at, and opens the OS share sheet for it.
  /// [loc] is passed in rather than resolved here: this class has no
  /// [BuildContext], and the CSV export path already localizes its own share
  /// subject the same way (see settings_screen.dart).
  Future<void> shareBackup(AppLocalizations loc) async {
    final archiveFile = await _createBackupArchive();
    await Share.shareXFiles(
      [XFile(archiveFile.path)],
      subject: loc.backupShareSubject,
    );
  }

  Future<File> _createBackupArchive() async {
    try {
      // Ensure every pending write is flushed to disk before copying —
      // sqflite keeps the file handle open for the app's lifetime, so a
      // dirty page cache could otherwise produce a truncated copy.
      final db = await DatabaseHelper.instance.database;
      final dbPath = db.path;

      final meta = jsonEncode({
        'schemaVersion': DatabaseHelper.dbVersion,
        'exportedAt': DateTime.now().toIso8601String(),
        'app': 'finta',
      });

      final archive = Archive();
      final dbBytes = await File(dbPath).readAsBytes();
      archive.addFile(ArchiveFile(_dbFileName, dbBytes.length, dbBytes));
      final metaBytes = utf8.encode(meta);
      archive.addFile(ArchiveFile(_metaFileName, metaBytes.length, metaBytes));

      final zipBytes = ZipEncoder().encode(archive);
      if (zipBytes == null) {
        throw const FormatException('zip encoding produced no output');
      }

      final dir = await getApplicationDocumentsDirectory();
      // Drop earlier backups first: each one is a full copy of the database,
      // so keeping every generation is the most expensive of the three exports.
      await pruneExports(dir, prefix: 'finta_backup_', extension: '.zip');
      final outFile = File(
        p.join(dir.path, 'finta_backup_${DateTime.now().millisecondsSinceEpoch}.zip'),
      );
      await outFile.writeAsBytes(zipBytes, flush: true);
      return outFile;
    } catch (e) {
      throw DatabaseException('Failed to create backup', cause: e);
    }
  }

  /// Reads a backup archive's manifest without touching the live database —
  /// callers should show this to the user (and refuse newer-than-running-app
  /// backups) before calling [restore].
  Future<BackupValidation> validate(File archiveFile) async {
    try {
      final bytes = await archiveFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final metaEntry = archive.files.firstWhere(
        (f) => f.name == _metaFileName,
        orElse: () => throw const FormatException('missing meta.json'),
      );
      final dbEntry = archive.files.firstWhere(
        (f) => f.name == _dbFileName,
        orElse: () => throw const FormatException('missing finta.db'),
      );
      if (dbEntry.content is! List<int> || (dbEntry.content as List<int>).isEmpty) {
        throw const FormatException('empty finta.db in archive');
      }

      final meta = jsonDecode(utf8.decode(metaEntry.content as List<int>)) as Map<String, dynamic>;
      final schemaVersion = meta['schemaVersion'] as int;
      return BackupValidation(
        // A backup from a *newer* app version may contain columns this
        // build doesn't know how to read — refuse it rather than corrupt
        // state silently. An older backup is always safe: onUpgrade runs
        // on the next open exactly as it would for a real old install.
        isCompatible: schemaVersion <= DatabaseHelper.dbVersion,
        schemaVersion: schemaVersion,
        exportedAt: DateTime.parse(meta['exportedAt'] as String),
      );
    } catch (e) {
      throw ValidationException('Not a valid Finta backup file', cause: e);
    }
  }

  /// Replaces the live database file with the one inside [archiveFile].
  /// Flutter has no supported way to restart its own process, so the
  /// caller must prompt the user to close and reopen the app — the restored
  /// file only takes effect on the next cold start.
  Future<void> restore(File archiveFile) async {
    try {
      final bytes = await archiveFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);
      final dbEntry = archive.files.firstWhere((f) => f.name == _dbFileName);
      final dbBytes = dbEntry.content as List<int>;

      final dbPath = (await DatabaseHelper.instance.database).path;
      await DatabaseHelper.instance.close();
      await File(dbPath).writeAsBytes(dbBytes, flush: true);
    } catch (e) {
      throw DatabaseException('Failed to restore backup', cause: e);
    }
  }
}
