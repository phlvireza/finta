import 'dart:io';

/// Housekeeping for the share/export files the app writes into its temporary
/// directory.
///
/// Backups, CSV exports and recap images are all written under a timestamped
/// name and handed to the OS share sheet. Nothing ever removed the previous
/// one, so every share left another copy behind and the app's storage grew
/// without bound — a user who backs up weekly for a year accumulates fifty-two
/// copies of their entire database.
///
/// The share sheet reads the file it was given, so the previous generation is
/// only pruned when a new one is about to be written.

/// Names in [fileNames] that are earlier generations of the same export.
///
/// A file matches when it starts with [prefix] and ends with [extension].
/// [keep] is excluded so the file just written is never a candidate.
///
/// Kept separate from the IO below so the matching rule can be tested without
/// touching a filesystem — and so an over-broad prefix can never quietly take
/// a user's own files with it.
List<String> staleExportFiles(
  Iterable<String> fileNames, {
  required String prefix,
  required String extension,
  String? keep,
}) {
  if (prefix.isEmpty) return const [];
  return fileNames
      .where((name) =>
          name != keep &&
          name.startsWith(prefix) &&
          name.endsWith(extension) &&
          name.length > prefix.length + extension.length)
      .toList();
}

/// Deletes earlier generations of an export from [directory].
///
/// Best-effort: a file that cannot be deleted is skipped rather than failing
/// the export the caller is about to perform. Losing an old copy matters far
/// less than losing the backup the user asked for.
Future<void> pruneExports(
  Directory directory, {
  required String prefix,
  required String extension,
  String? keep,
}) async {
  try {
    if (!await directory.exists()) return;
    final names = await directory
        .list(followLinks: false)
        .where((entity) => entity is File)
        .map((entity) => entity.uri.pathSegments.last)
        .toList();

    for (final name in staleExportFiles(
      names,
      prefix: prefix,
      extension: extension,
      keep: keep,
    )) {
      try {
        await File('${directory.path}/$name').delete();
      } on FileSystemException {
        // Locked or already gone — nothing to do.
      }
    }
  } on FileSystemException {
    // Listing the directory failed; the export itself still proceeds.
  }
}
