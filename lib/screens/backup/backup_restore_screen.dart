import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/exceptions/app_exceptions.dart';
import '../../core/services/backup_service.dart';
import '../../core/services/csv_export_service.dart';
import '../../providers/account_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../widgets/section_card.dart';
import '../../widgets/tinted_icon.dart';
import '../../l10n/app_localizations.dart';
import 'csv_import_screen.dart';
import 'restart_required_screen.dart';

/// Hub for all four data-portability flows.
///
/// They are grouped by *scope*, not by file format, because scope is the
/// thing users were getting wrong: a backup is the entire database and
/// restoring it replaces everything, while a CSV is transactions only and
/// importing one adds to what is already there. Presented apart — CSV
/// export used to sit in Settings labelled "Backup your data", with CSV
/// import buried down here — the two read as interchangeable, and choosing
/// wrong either loses the rest of the user's data or fails to move it.
class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final _backupService = BackupService();
  final _csvExportService = CsvExportService();
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
        _showError(loc.backupIncompatible);
        return;
      }

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(loc.restoreBackupTitle),
          content: Text(
            loc.restoreBackupConfirm(
              DateFormat.yMMMd().add_jm().format(validation.exportedAt),
            ),
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

  Future<void> _exportCsv() async {
    final loc = AppLocalizations.of(context)!;
    final transactions = context.read<TransactionProvider>();
    final categories = context.read<CategoryProvider>();
    final accounts = context.read<AccountProvider>();
    setState(() => _busy = true);
    try {
      final all = await transactions.getAllTransactions();
      // Archived categories still resolve here — getCategoryById isn't
      // filtered, only the active-category pickers are — so an export never
      // silently loses the category of an older transaction.
      final csv = _csvExportService.buildCsv(
        all,
        (id) => categories.getCategoryById(id)?.name ?? loc.unknown,
        (id) => accounts.getAccountById(id)?.name ?? loc.unknown,
      );
      await _csvExportService.shareCsv(csv, loc.csvExportShareSubject);

      // A transfer's two legs are written as one row, so the file holds fewer
      // rows than the ledger has entries. Said here rather than discovered by
      // counting lines in the exported file and concluding a leg was dropped.
      if (mounted) {
        final transfers = CsvExportService.transferPairCount(all);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              transfers == 0
                  ? loc.csvExportedCount(all.length)
                  : loc.csvExportedCountWithTransfers(
                      all.length - transfers,
                      transfers,
                    ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) _showError(loc.errorFailedToExport);
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.csvImportedCount(imported))));
      }
    } catch (e) {
      if (mounted) _showError(loc.csvReadFailed);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.backupAndData)),
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
                    _SectionExplainer(loc.backupSectionExplainer),
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
                title: loc.csvSectionTitle,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _SectionExplainer(loc.csvSectionExplainer),
                    _ActionRow(
                      icon: Icons.download_outlined,
                      title: loc.exportCsv,
                      subtitle: loc.exportCsvSubtitle,
                      onTap: _exportCsv,
                    ),
                    const Divider(height: 1),
                    _ActionRow(
                      icon: Icons.upload_file_outlined,
                      title: loc.importCsv,
                      subtitle: loc.importCsvSubtitle,
                      onTap: _importCsv,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The one-line "what this section actually covers" note under a section
/// heading. Carries the distinction the labels alone were failing to make —
/// everything vs. transactions only — so it sits above the rows rather than
/// as a subtitle on one of them.
class _SectionExplainer extends StatelessWidget {
  final String text;

  const _SectionExplainer(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      // No top inset: SectionCard's header already pads below the title.
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        0,
        AppConstants.spacingMd,
        AppConstants.spacingSm,
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
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
