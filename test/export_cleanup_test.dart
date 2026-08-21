import 'package:flutter_test/flutter_test.dart';
import 'package:finta/core/utils/export_cleanup.dart';

void main() {
  group('staleExportFiles', () {
    const backups = [
      'finta_backup_1000.zip',
      'finta_backup_2000.zip',
      'finta_export_1000.csv',
      'finta_recap_2026-08-01.png',
      'finta.db',
      'notes.txt',
    ];

    test('matches only files with both the prefix and the extension', () {
      expect(
        staleExportFiles(backups, prefix: 'finta_backup_', extension: '.zip'),
        ['finta_backup_1000.zip', 'finta_backup_2000.zip'],
      );
    });

    test('leaves the other export families alone', () {
      expect(
        staleExportFiles(backups, prefix: 'finta_export_', extension: '.csv'),
        ['finta_export_1000.csv'],
      );
      expect(
        staleExportFiles(backups, prefix: 'finta_recap_', extension: '.png'),
        ['finta_recap_2026-08-01.png'],
      );
    });

    // The live database sits in the same directory as the exports.
    test('never matches the database or unrelated files', () {
      final all = [
        ...staleExportFiles(backups, prefix: 'finta_backup_', extension: '.zip'),
        ...staleExportFiles(backups, prefix: 'finta_export_', extension: '.csv'),
        ...staleExportFiles(backups, prefix: 'finta_recap_', extension: '.png'),
      ];
      expect(all, isNot(contains('finta.db')));
      expect(all, isNot(contains('notes.txt')));
    });

    test('excludes the file the caller is keeping', () {
      expect(
        staleExportFiles(
          backups,
          prefix: 'finta_backup_',
          extension: '.zip',
          keep: 'finta_backup_2000.zip',
        ),
        ['finta_backup_1000.zip'],
      );
    });

    test('requires something between the prefix and the extension', () {
      expect(
        staleExportFiles(['finta_backup_.zip'], prefix: 'finta_backup_', extension: '.zip'),
        isEmpty,
      );
    });

    // An empty prefix would match every file in the documents directory,
    // including the database. Guarded rather than left to the caller.
    test('matches nothing when the prefix is empty', () {
      expect(staleExportFiles(backups, prefix: '', extension: '.zip'), isEmpty);
    });

    test('returns an empty list for an empty directory', () {
      expect(
        staleExportFiles(const [], prefix: 'finta_backup_', extension: '.zip'),
        isEmpty,
      );
    });

    test('does not match a prefix appearing later in the name', () {
      expect(
        staleExportFiles(
          ['copy_of_finta_backup_1000.zip'],
          prefix: 'finta_backup_',
          extension: '.zip',
        ),
        isEmpty,
      );
    });
  });
}
