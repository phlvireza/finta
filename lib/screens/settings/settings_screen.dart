import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/section_card.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import '../../l10n/app_localizations.dart';
import '../backup/backup_restore_screen.dart';

/// Settings screen — preferences, management links, and CSV export.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.settings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spacingLg,
          AppConstants.spacingMd,
          AppConstants.spacingLg,
          AppConstants.fabClearance,
        ),
        children: [
          SectionCard(
            title: loc.preferences,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.currency_exchange),
                  title: Text(loc.currency),
                  trailing: Text(
                    settings.currencyCode,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => _showCurrencyPicker(context, settings),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(loc.theme),
                  trailing: Text(
                    _themeModeName(loc, settings.themeMode),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => _showThemePicker(context, settings),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(loc.language),
                  trailing: Text(
                    settings.languageCode == 'en' ? loc.languageNameEnglish : loc.languageNameIndonesian,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => _showLanguagePicker(context, settings),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: Text(loc.payday),
                  trailing: Text(
                    loc.paydayDayLabel(settings.payday),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => _showPaydayPicker(context, settings),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),

          SectionCard(
            title: loc.data,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.download),
                  title: Text(loc.exportCsv),
                  subtitle: Text(loc.backupYourData),
                  onTap: () => _exportCsv(context),
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(loc.backupAndRestore),
                  subtitle: Text(loc.backupAndRestoreSubtitle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BackupRestoreScreen()),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),

          SectionCard(
            child: Center(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusLg),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 64,
                      height: 64,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text(
                    'Finta',
                    style: theme.textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${loc.appVersionLabel('1.0.0')}\n${loc.appTagline}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCurrencyPicker(BuildContext context, SettingsProvider settings) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: AppConstants.currencies.map((c) {
            return ListTile(
              leading: Text(c.symbol, style: Theme.of(context).textTheme.titleMedium),
              title: Text(c.name),
              trailing: settings.currencyCode == c.code
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                settings.setCurrency(c.code);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, SettingsProvider settings) {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              // Language names are shown in their own language, not
              // translated — a language picker only works if a user who
              // can't read the current locale can still spot their own.
              title: Text(loc.languageNameEnglish),
              trailing: settings.languageCode == 'en'
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                settings.setLanguage('en');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Text('🇮🇩', style: TextStyle(fontSize: 24)),
              title: Text(loc.languageNameIndonesian),
              trailing: settings.languageCode == 'id'
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                settings.setLanguage('id');
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(BuildContext context, SettingsProvider settings) {
    final loc = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: Text(loc.systemDefault),
              trailing: settings.themeMode == ThemeMode.system
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                settings.setThemeMode(ThemeMode.system);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: Text(loc.light),
              trailing: settings.themeMode == ThemeMode.light
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                settings.setThemeMode(ThemeMode.light);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: Text(loc.dark),
              trailing: settings.themeMode == ThemeMode.dark
                  ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
                  : null,
              onTap: () {
                settings.setThemeMode(ThemeMode.dark);
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showPaydayPicker(BuildContext context, SettingsProvider settings) {
    final loc = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(loc.selectPayday),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SizedBox(
            width: double.maxFinite,
            child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: 31,
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = settings.payday == day;
              final theme = Theme.of(context);

              return InkWell(
                onTap: () {
                  settings.setPayday(day);
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppConstants.radiusSm),
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        color: isSelected ? theme.colorScheme.onPrimary : null,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        ),
      ),
    );
  }

  Future<void> _exportCsv(BuildContext context) async {
    final loc = AppLocalizations.of(context)!;
    try {
      final txProvider = context.read<TransactionProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final transactions = await txProvider.getAllTransactions();

      // Header row is a data-interchange contract, not UI copy: it must
      // stay exactly "Date,Type,Amount,Category,Note" in every locale so
      // CsvImportService's header auto-detection (and re-importing a file
      // this screen exported) keeps working.
      final buffer = StringBuffer();
      buffer.writeln('Date,Type,Amount,Category,Note');

      for (final tx in transactions) {
        // Resolve to the human-readable category name — archived
        // categories still resolve here since getCategoryById isn't
        // filtered, only the active-category pickers are.
        //
        // Deliberately the *stored* name, not the localized one, for the
        // same reason the header row above stays English: this column is
        // what CsvImportScreen matches a re-import on. Writing the display
        // name would make a file exported in one language import as a pile
        // of new categories in the other.
        final categoryName =
            categoryProvider.getCategoryById(tx.categoryId)?.name ?? loc.unknown;
        buffer.writeln([
          tx.date.toIso8601String().substring(0, 10),
          tx.type,
          tx.amount,
          categoryName,
          tx.note ?? '',
        ].map(_csvField).join(','));
      }

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/finta_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      await Share.shareXFiles([XFile(file.path)], subject: loc.csvExportShareSubject);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.errorFailedToExport)),
        );
      }
    }
  }

  String _themeModeName(AppLocalizations loc, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return loc.light;
      case ThemeMode.dark:
        return loc.dark;
      default:
        return loc.systemDefault;
    }
  }

  /// Quote a CSV field only when it contains a character that would
  /// otherwise break column alignment, doubling any embedded quotes.
  static String _csvField(Object value) {
    final s = value.toString();
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }
}
