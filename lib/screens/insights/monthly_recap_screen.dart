import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers/analytics_provider.dart';
import '../../providers/category_provider.dart';
import '../../providers/settings_provider.dart';
import '../../core/constants/app_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/number_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../core/utils/category_display.dart';

/// A shareable "your pay cycle, summarised" card — captured from a live
/// widget tree via [RepaintBoundary] rather than drawn with a separate
/// imaging API, so the card's design and the aggregation it reads
/// ([AnalyticsProvider.loadAnalytics], the same range-scoped query the main
/// Insights breakdown uses) can never drift out of sync with each other the
/// way a hand-maintained duplicate renderer could.
///
/// The period is the user's payday-anchored cycle, not a calendar month.
/// This screen used to slice by calendar month while every other surface in
/// the app used [AppDateUtils.getCurrentPeriod], which meant that for anyone
/// whose payday isn't the 1st the recap disagreed with the dashboard: with
/// payday 21, salary received 21 July counted towards "July" while the
/// expenses it paid for from 1 August counted towards "August", so August
/// showed real spending against zero income.
class MonthlyRecapScreen extends StatefulWidget {
  const MonthlyRecapScreen({super.key});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen> {
  final _boundaryKey = GlobalKey();
  late ({DateTime start, DateTime end}) _period;
  late int _payday;

  /// Captured up front rather than read in [dispose], where looking a
  /// provider up off a deactivating element is not safe.
  late AnalyticsProvider _analytics;

  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    _payday = context.read<SettingsProvider>().payday;
    _analytics = context.read<AnalyticsProvider>();
    _period = AppDateUtils.getCurrentPeriod(_payday);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    // This screen drives the shared AnalyticsProvider, so leaving would
    // otherwise strand the Analytics tab on whichever period was last
    // browsed here.
    final analytics = _analytics;
    final payday = _payday;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      analytics.loadForCurrentPeriod(payday);
    });
    super.dispose();
  }

  Future<void> _load() {
    return _analytics.loadAnalytics(
      start: _period.start,
      end: _period.end,
      comparedTo: AppDateUtils.getPreviousPeriod(_period),
    );
  }

  /// True once [_period] is the newest one there is. Paging past it only
  /// ever produced an empty card for a period that hasn't started.
  bool get _isLatestPeriod {
    final current = AppDateUtils.getCurrentPeriod(_payday);
    return !_period.start.isBefore(current.start);
  }

  /// True while the period is still running, so partial totals are never
  /// presented as a finished result.
  bool get _isInProgress => DateTime.now().isBefore(_period.end);

  void _changePeriod(int delta) {
    setState(() {
      _period = delta < 0
          ? AppDateUtils.getPreviousPeriod(_period)
          // No getNextPeriod exists, and none is needed: re-anchoring on the
          // day after this period ends is exactly the next one.
          : AppDateUtils.getCurrentPeriod(
              _payday,
              referenceDate: _period.end.add(const Duration(days: 1)),
            );
    });
    _load();
  }

  Future<void> _share() async {
    final loc = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sharing = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/finta_recap_${AppDateUtils.formatIso(_period.start)}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)]);
    } catch (e) {
      // Rendering, the file write and the share sheet can all fail; without
      // a catch the failure was silent and the spinner just stopped.
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(loc.errorFailedToExport)));
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final analytics = context.watch<AnalyticsProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();

    final expenseBreakdown = analytics.expenseBreakdown.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final topCategories = [
      for (final item in expenseBreakdown.take(3))
        (
          name: categoryDisplayNameOr(
            categories.getCategoryById(item.categoryId),
            loc,
            fallback: loc.unknown,
          ),
          total: item.total,
        ),
    ];

    // Null, not zero, when there is no income: a period with expenses and no
    // income has no meaningful savings rate, and "0%" reads as if the user
    // merely spent everything they earned.
    final savingsRate = analytics.totalIncome > 0
        ? (analytics.totalIncome - analytics.totalExpense) / analytics.totalIncome
        : null;

    final canShare = !_sharing && !analytics.isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.periodRecap),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            // Disabled while loading: the RepaintBoundary isn't in the tree
            // then, and capturing it would throw on a null context.
            onPressed: canShare ? _share : null,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: AppConstants.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: () => _changePeriod(-1),
              ),
              Text(
                AppDateUtils.formatPeriodRange(_period.start, _period.end),
                style: theme.textTheme.titleMedium,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: _isLatestPeriod ? null : () => _changePeriod(1),
              ),
            ],
          ),
          Expanded(
            child: analytics.isLoading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spacingLg,
                      AppConstants.spacingSm,
                      AppConstants.spacingLg,
                      AppConstants.fabClearance,
                    ),
                    child: Center(
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: _RecapCard(
                          period: _period,
                          isInProgress: _isInProgress,
                          elapsedFraction: AppDateUtils.periodElapsedFraction(_period),
                          totalIncome: analytics.totalIncome,
                          totalExpense: analytics.totalExpense,
                          previousIncome: analytics.previousTotalIncome,
                          previousExpense: analytics.previousTotalExpense,
                          savingsRate: savingsRate,
                          topCategories: topCategories,
                          symbol: settings.currencySymbol,
                          useDecimals: settings.currencyUseDecimals,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

typedef _TopCategory = ({String name, double total});

class _RecapCard extends StatelessWidget {
  final ({DateTime start, DateTime end}) period;
  final bool isInProgress;
  final double elapsedFraction;
  final double totalIncome;
  final double totalExpense;
  final double previousIncome;
  final double previousExpense;
  final double? savingsRate;
  final List<_TopCategory> topCategories;
  final String symbol;
  final bool useDecimals;

  const _RecapCard({
    required this.period,
    required this.isInProgress,
    required this.elapsedFraction,
    required this.totalIncome,
    required this.totalExpense,
    required this.previousIncome,
    required this.previousExpense,
    required this.savingsRate,
    required this.topCategories,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final net = totalIncome - totalExpense;
    final isDark = theme.brightness == Brightness.dark;
    final incomeColor = isDark ? AppColors.darkIncome : AppColors.lightIncome;
    final expenseColor = isDark ? AppColors.darkExpense : AppColors.lightExpense;
    final netColor = net >= 0 ? incomeColor : expenseColor;

    final totalDays = period.end.difference(period.start).inDays + 1;
    final elapsedDays = (elapsedFraction * totalDays).round().clamp(1, totalDays);

    return ConstrainedBox(
      // Was a fixed 320px box centred in a full-height Expanded, which left
      // a phone showing a small card marooned in ~300px of empty space and
      // a tablet showing a postage stamp. Now it takes the width it is
      // given, up to a share-card-sized cap.
      constraints: const BoxConstraints(maxWidth: 420),
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spacingXxl),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.darkSurface, AppColors.darkSurfaceVariant]
                : [AppColors.lightSurface, AppColors.lightSurfaceVariant],
          ),
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Finta',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? AppColors.darkPrimary : AppColors.lightPrimary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: AppConstants.spacingXs),
            Text(
              loc.yourPeriodRecapTitle(
                AppDateUtils.formatPeriodRange(period.start, period.end),
              ),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (isInProgress) ...[
              const SizedBox(height: AppConstants.spacingSm),
              // Without this a half-finished period reads as a settled
              // result — the original complaint, where a recap claimed
              // savings for a cycle that still had ten days to run.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppConstants.radiusFull),
                ),
                child: Text(
                  loc.periodInProgress(elapsedDays, totalDays),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: AppConstants.spacingXl),
            Text(loc.netSavings, style: theme.textTheme.labelMedium),
            Text(
              NumberUtils.formatCurrency(net, symbol: symbol, useDecimals: useDecimals),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(color: netColor, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: AppConstants.spacingLg),
            _statLine(context, loc.totalIncome, totalIncome, previousIncome, incomeColor),
            const SizedBox(height: AppConstants.spacingSm),
            _statLine(context, loc.totalExpense, totalExpense, previousExpense, expenseColor),
            const SizedBox(height: AppConstants.spacingSm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(loc.savingsRate, style: theme.textTheme.bodyMedium),
                Text(
                  savingsRate == null
                      ? '—'
                      : NumberUtils.formatPercentage(savingsRate!.clamp(-1.0, 1.0)),
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (topCategories.isNotEmpty) ...[
              const SizedBox(height: AppConstants.spacingXl),
              Text(loc.topCategories, style: theme.textTheme.labelMedium),
              const SizedBox(height: AppConstants.spacingSm),
              ...topCategories.map((category) => _categoryRow(context, category, expenseColor)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statLine(
    BuildContext context,
    String label,
    double amount,
    double previous,
    Color deltaColor,
  ) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.bodyMedium),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Only when there is something to compare against — a first
            // period, or one after a gap, would otherwise read as "-100%".
            if (previous > 0) ...[
              Text(
                _deltaLabel(amount, previous),
                style: theme.textTheme.labelSmall?.copyWith(color: deltaColor),
              ),
              const SizedBox(width: AppConstants.spacingSm),
            ],
            Text(
              NumberUtils.formatCurrency(amount, symbol: symbol, useDecimals: useDecimals),
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ],
    );
  }

  String _deltaLabel(double amount, double previous) {
    final percent = (amount - previous) / previous * 100;
    final sign = percent >= 0 ? '+' : '−';
    return '$sign${percent.abs().toStringAsFixed(0)}%';
  }

  Widget _categoryRow(BuildContext context, _TopCategory category, Color barColor) {
    final theme = Theme.of(context);
    final share = totalExpense > 0 ? (category.total / totalExpense).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  category.name,
                  style: theme.textTheme.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppConstants.spacingSm),
              Text(
                NumberUtils.formatCurrency(
                  category.total,
                  symbol: symbol,
                  useDecimals: useDecimals,
                ),
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusFull),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 4,
              backgroundColor: barColor.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation(barColor),
            ),
          ),
        ],
      ),
    );
  }
}
