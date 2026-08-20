import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:finta/core/database/database_helper.dart';
import 'package:finta/core/exceptions/app_exceptions.dart';
import 'package:finta/core/services/backup_service.dart';

/// Builds a fake backup zip on disk without touching the real database —
/// [BackupService.validate] only reads the archive's manifest, so it's
/// testable in isolation from the sqlite-backed parts of the service.
Future<File> _writeFakeBackup(
  Directory dir, {
  required int schemaVersion,
  bool includeDb = true,
  bool includeMeta = true,
  bool? encrypted,
}) async {
  final archive = Archive();
  if (includeDb) {
    final dbBytes = utf8.encode('not a real sqlite file, just needs to be non-empty');
    archive.addFile(ArchiveFile('finta.db', dbBytes.length, dbBytes));
  }
  if (includeMeta) {
    final meta = jsonEncode({
      'schemaVersion': schemaVersion,
      'exportedAt': '2026-07-01T12:00:00.000',
      'app': 'finta',
      // Omitted entirely when null, which is how archives written before the
      // field existed look.
      if (encrypted != null) 'encrypted': encrypted,
    });
    final metaBytes = utf8.encode(meta);
    archive.addFile(ArchiveFile('meta.json', metaBytes.length, metaBytes));
  }
  final zipBytes = ZipEncoder().encode(archive)!;
  final file = File(p.join(dir.path, 'fake_backup.zip'));
  await file.writeAsBytes(zipBytes);
  return file;
}

void main() {
  late Directory tempDir;
  late BackupService service;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('finta_backup_test');
    service = BackupService();
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('a backup at the current schema version is compatible', () async {
    final file = await _writeFakeBackup(tempDir, schemaVersion: DatabaseHelper.dbVersion);
    final result = await service.validate(file);
    expect(result.isCompatible, isTrue);
    expect(result.schemaVersion, DatabaseHelper.dbVersion);
  });

  test('an older backup is compatible — onUpgrade handles it on next open', () async {
    final file = await _writeFakeBackup(tempDir, schemaVersion: DatabaseHelper.dbVersion - 1);
    final result = await service.validate(file);
    expect(result.isCompatible, isTrue);
  });

  test('a backup from a newer app version is refused, not silently accepted', () async {
    final file = await _writeFakeBackup(tempDir, schemaVersion: DatabaseHelper.dbVersion + 1);
    final result = await service.validate(file);
    expect(result.isCompatible, isFalse);
  });

  test('a zip missing meta.json is rejected as invalid rather than crashing', () async {
    final file = await _writeFakeBackup(tempDir, schemaVersion: DatabaseHelper.dbVersion, includeMeta: false);
    expect(() => service.validate(file), throwsA(isA<ValidationException>()));
  });

  test('a zip missing finta.db is rejected as invalid', () async {
    final file = await _writeFakeBackup(tempDir, schemaVersion: DatabaseHelper.dbVersion, includeDb: false);
    expect(() => service.validate(file), throwsA(isA<ValidationException>()));
  });

  test('a file that is not a zip at all is rejected as invalid', () async {
    final file = File(p.join(tempDir.path, 'not_a_zip.zip'));
    await file.writeAsString('this is definitely not a zip archive');
    expect(() => service.validate(file), throwsA(isA<ValidationException>()));
  });

  group('encrypted marker', () {
    test('an archive predating the field reads as plaintext, not unknown', () async {
      final file = await _writeFakeBackup(tempDir, schemaVersion: DatabaseHelper.dbVersion);
      final result = await service.validate(file);
      expect(result.isEncrypted, isFalse);
      expect(result.isCompatible, isTrue);
    });

    test('an archive marked encrypted:false is compatible', () async {
      final file = await _writeFakeBackup(
        tempDir,
        schemaVersion: DatabaseHelper.dbVersion,
        encrypted: false,
      );
      final result = await service.validate(file);
      expect(result.isEncrypted, isFalse);
      expect(result.isCompatible, isTrue);
    });

    test('an encrypted archive is refused even at the current schema version', () async {
      // This build has no key, so restoring would overwrite a working database
      // with bytes sqlite cannot open. Refusing is the whole point of the field.
      final file = await _writeFakeBackup(
        tempDir,
        schemaVersion: DatabaseHelper.dbVersion,
        encrypted: true,
      );
      final result = await service.validate(file);
      expect(result.isEncrypted, isTrue);
      expect(result.isCompatible, isFalse);
    });
  });
}
