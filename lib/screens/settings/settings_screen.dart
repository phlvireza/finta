import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/category_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/section_card.dart';
import '../../l10n/app_localizations.dart';
import '../backup/backup_restore_screen.dart';
import 'privacy_policy_screen.dart';

final Future<PackageInfo> _packageInfo = PackageInfo.fromPlatform();

/// Settings screen — preferences and management links. The data-portability
/// flows (backup, restore, CSV export/import) all live in
/// [BackupRestoreScreen], reached from the Data section below.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final isDark = theme.brightness == Brightness.dark;
    final appIconAsset = isDark
        ? 'assets/images/app_icon_dark.png'
        : 'assets/images/app_icon.png';
    final appIconCacheWidth = (64 * MediaQuery.devicePixelRatioOf(context))
        .round();

    final loc = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(loc.settings)),
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
                    settings.languageCode == 'en'
                        ? loc.languageNameEnglish
                        : loc.languageNameIndonesian,
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
            padding: EdgeInsets.zero,
            child: ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: Text(
                settings.languageCode == 'id'
                    ? 'Kebijakan Privasi'
                    : 'Privacy Policy',
              ),
              subtitle: Text(
                settings.languageCode == 'id'
                    ? 'Cara Squirio menangani data Anda'
                    : 'How Squirio handles your data',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingLg),

          SectionCard(
            title: loc.data,
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                // One entry point, not two. Export used to live here while
                // import lived inside the screen below, which is how "Export
                // as CSV" ended up subtitled "Backup your data" — all four
                // data flows now sit together, grouped by what they cover.
                ListTile(
                  leading: const Icon(Icons.settings_backup_restore),
                  title: Text(loc.backupAndData),
                  subtitle: Text(loc.backupAndDataSubtitle),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const BackupRestoreScreen(),
                    ),
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
                  AnimatedSwitcher(
                    duration: AppConstants.animNormal,
                    child: ClipRRect(
                      key: ValueKey(appIconAsset),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLg,
                      ),
                      child: Image.asset(
                        appIconAsset,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        cacheWidth: appIconCacheWidth,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spacingMd),
                  Text('Squirio', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 4),
                  FutureBuilder<PackageInfo>(
                    future: _packageInfo,
                    builder: (context, snapshot) {
                      final version = snapshot.data?.version ?? '—';
                      return Text(
                        '${loc.appVersionLabel(version)}\n${loc.appTagline}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      );
                    },
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
              leading: Text(
                c.symbol,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              title: Text(c.name),
              trailing: settings.currencyCode == c.code
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
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
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                // Read before popping and before the first await, so the
                // provider lookup never happens across an async gap.
                final categories = context.read<CategoryProvider>();
                Navigator.pop(context);
                await settings.setLanguage('en');
                // SettingsProvider has no route to CategoryProvider, so the
                // default category names are refreshed here.
                await categories.localizeDefaultNames('en');
              },
            ),
            ListTile(
              leading: const Text('🇮🇩', style: TextStyle(fontSize: 24)),
              title: Text(loc.languageNameIndonesian),
              trailing: settings.languageCode == 'id'
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onTap: () async {
                // Read before popping and before the first await, so the
                // provider lookup never happens across an async gap.
                final categories = context.read<CategoryProvider>();
                Navigator.pop(context);
                await settings.setLanguage('id');
                // SettingsProvider has no route to CategoryProvider, so the
                // default category names are refreshed here.
                await categories.localizeDefaultNames('id');
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
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
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
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
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
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
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
                      color: isSelected
                          ? theme.colorScheme.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSm,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '$day',
                        style: TextStyle(
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : null,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
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
}
