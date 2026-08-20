import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/services/backup_service.dart';
import '../../widgets/section_card.dart';
import '../../widgets/tinted_icon.dart';
import '../../l10n/app_localizations.dart';
import 'csv_import_screen.dart';
import 'restart_required_screen.dart';

/// Hub for the three data-portability flows: full-database backup/restore
/// (a zip of the live sqlite file — the safest round trip, since it's
/// exactly what the app has, not a hand-written re-serialization), and CSV
/// import from Finta's own export or another app's.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _backupService = BackupService();
  bool _busy = false;

  Future<void> _createBackup() async {
    final loc = AppLocalizations.of(context)!;
    setState(() => _busy = true);
    try {
      await _backupService.shareBackup(loc);
    } catch (e) {
      if (mounted) _showError(loc.backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final loc = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final file = File(path);
      final validation = await _backupService.validate(file);
      if (!mounted) return;
      setState(() => _busy = false);

      if (!validation.isCompatible) {
        // Two different reasons land here, and "made with a newer version"
        // would be wrong for the encrypted one.
        _showError(
          validation.isEncrypted ? loc.backupEncrypted : loc.backupIncompatible,
        );
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(loc.restoreBackupTitle),
          content: Text(
            loc.restoreBackupConfirm(DateFormat.yMMMd().add_jm().format(validation.exportedAt)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(loc.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(loc.restore),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;

      setState(() => _busy = true);
      await _backupService.restore(file);
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const RestartRequiredScreen()),
        (route) => false,
      );
    } on ValidationException {
      if (mounted) _showError(loc.backupInvalidFile);
    } catch (e) {
      if (mounted) _showError(loc.restoreFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importCsv() async {
    final loc = AppLocalizations.of(context)!;
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    try {
      final content = await File(path).readAsString();
      if (!mounted) return;
      final imported = await Navigator.of(context).push<int>(
        MaterialPageRoute(builder: (_) => CsvImportScreen(csvContent: content)),
      );
      if (imported != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.csvImportedCount(imported))),
        );
      }
    } catch (e) {
      if (mounted) _showError(loc.csvReadFailed);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.backupAndRestore)),
      body: AbsorbPointer(
        absorbing: _busy,
        child: Opacity(
          opacity: _busy ? 0.6 : 1,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppConstants.spacingLg,
              AppConstants.spacingMd,
              AppConstants.spacingLg,
              AppConstants.fabClearance,
            ),
            children: [
              SectionCard(
                title: loc.backupSectionTitle,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _ActionRow(
                      icon: Icons.backup_outlined,
                      title: loc.createBackup,
                      subtitle: loc.createBackupSubtitle,
                      onTap: _createBackup,
                    ),
                    const Divider(height: 1),
                    _ActionRow(
                      icon: Icons.restore_outlined,
                      title: loc.restoreFromBackup,
                      subtitle: loc.restoreFromBackupSubtitle,
                      onTap: _restoreBackup,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              SectionCard(
                title: loc.csvImportSectionTitle,
                padding: EdgeInsets.zero,
                child: _ActionRow(
                  icon: Icons.upload_file_outlined,
                  title: loc.importCsv,
                  subtitle: loc.importCsvSubtitle,
                  onTap: _importCsv,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: TintedIcon(icon: icon, color: theme.colorScheme.primary),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
