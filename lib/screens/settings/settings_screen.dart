import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/transaction_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/constants/app_constants.dart';
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
          AppConstants.spacingLg,
          AppConstants.spacingLg,
          AppConstants.fabClearance,
        ),
        children: [
          // ── Preferences ──────────────────────────────────────────
          Text(loc.preferences, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.spacingMd),
          _SettingsCard(
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
                  _themeModeName(settings.themeMode),
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
                  settings.languageCode == 'en' ? 'English' : 'Bahasa Indonesia',
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
                  'Day ${settings.payday}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                onTap: () => _showPaydayPicker(context, settings),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingXxxl),

          // ── Data ─────────────────────────────────────────────────
          Text(loc.data, style: theme.textTheme.titleLarge),
          const SizedBox(height: AppConstants.spacingMd),
          _SettingsCard(
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
          const SizedBox(height: AppConstants.spacingXxxl),

          // ── About ────────────────────────────────────────────────
          Center(
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
                  'Version 1.0.0\nBuilt for you',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
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
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('🇺🇸', style: TextStyle(fontSize: 24)),
              title: const Text('English'),
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
              title: const Text('Bahasa Indonesia'),
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
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('System Default'),
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
              title: const Text('Light'),
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
              title: const Text('Dark'),
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Payday'),
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
                    borderRadius: BorderRadius.circular(4),
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
    try {
      final txProvider = context.read<TransactionProvider>();
      final categoryProvider = context.read<CategoryProvider>();
      final loc = AppLocalizations.of(context)!;
      final transactions = await txProvider.getAllTransactions();

      final buffer = StringBuffer();
      buffer.writeln('Date,Type,Amount,Category,Note');

      for (final tx in transactions) {
        // Resolve to the human-readable category name — archived
        // categories still resolve here since getCategoryById isn't
        // filtered, only the active-category pickers are.
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

      await Share.shareXFiles([XFile(file.path)], subject: 'Finta export');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to export data')),
        );
      }
    }
  }

  String _themeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      default:
        return 'System Default';
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

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        side: BorderSide(color: theme.colorScheme.outline),
      ),
      child: Column(
        children: children,
      ),
    );
  }
}
