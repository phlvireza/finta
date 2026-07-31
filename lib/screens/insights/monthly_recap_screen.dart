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

/// A shareable "Your [Month]" summary card — captured from a live widget
/// tree via [RepaintBoundary] rather than drawn with a separate imaging
/// API, so the card's design and the aggregation it reads
/// ([AnalyticsProvider.loadAnalytics], the same range-scoped query the
/// main Insights breakdown uses) can never drift out of sync with each
/// other the way a hand-maintained duplicate renderer could.
class MonthlyRecapScreen extends StatefulWidget {
  const MonthlyRecapScreen({super.key});

  @override
  State<MonthlyRecapScreen> createState() => _MonthlyRecapScreenState();
}

class _MonthlyRecapScreenState extends State<MonthlyRecapScreen> {
  final _boundaryKey = GlobalKey();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _sharing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() {
    final start = DateTime(_month.year, _month.month, 1);
    final end = DateTime(_month.year, _month.month + 1, 0);
    return context.read<AnalyticsProvider>().loadAnalytics(start: start, end: end);
  }

  void _changeMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
    _load();
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/finta_recap_${_month.year}_${_month.month}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles([XFile(file.path)]);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final analytics = context.watch<AnalyticsProvider>();
    final categories = context.watch<CategoryProvider>();
    final settings = context.watch<SettingsProvider>();

    final expenseBreakdown = analytics.expenseBreakdown.toList()
      ..sort((a, b) => b.total.compareTo(a.total));
    final topCategory = expenseBreakdown.isNotEmpty ? expenseBreakdown.first : null;
    final topCategoryName =
        topCategory != null ? categories.getCategoryById(topCategory.categoryId)?.name : null;
    final savingsRate = analytics.totalIncome > 0
        ? (analytics.totalIncome - analytics.totalExpense) / analytics.totalIncome
        : 0.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.monthlyRecap),
        actions: [
          IconButton(
            icon: _sharing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
            onPressed: _sharing ? null : _share,
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: AppConstants.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
              Text(AppDateUtils.formatMonthYear(_month), style: Theme.of(context).textTheme.titleMedium),
              IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
            ],
          ),
          Expanded(
            child: analytics.isLoading
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(AppConstants.spacingLg),
                      child: RepaintBoundary(
                        key: _boundaryKey,
                        child: _RecapCard(
                          month: _month,
                          totalIncome: analytics.totalIncome,
                          totalExpense: analytics.totalExpense,
                          savingsRate: savingsRate,
                          topCategoryName: topCategoryName,
                          topCategoryTotal: topCategory?.total,
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

class _RecapCard extends StatelessWidget {
  final DateTime month;
  final double totalIncome;
  final double totalExpense;
  final double savingsRate;
  final String? topCategoryName;
  final double? topCategoryTotal;
  final String symbol;
  final bool useDecimals;

  const _RecapCard({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.savingsRate,
    required this.topCategoryName,
    required this.topCategoryTotal,
    required this.symbol,
    required this.useDecimals,
  });

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    final net = totalIncome - totalExpense;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final netColor = net >= 0
        ? (isDark ? AppColors.darkIncome : AppColors.lightIncome)
        : (isDark ? AppColors.darkExpense : AppColors.lightExpense);

    return Container(
      width: 320,
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
            loc.yourMonthRecapTitle(AppDateUtils.monthName(month.month)),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingXxl),
          Text(loc.netSavings, style: Theme.of(context).textTheme.labelMedium),
          Text(
            NumberUtils.formatCurrency(net, symbol: symbol, useDecimals: useDecimals),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: netColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppConstants.spacingLg),
          _statLine(context, loc.totalIncome, totalIncome),
          const SizedBox(height: AppConstants.spacingSm),
          _statLine(context, loc.totalExpense, totalExpense),
          if (topCategoryName != null && topCategoryTotal != null) ...[
            const SizedBox(height: AppConstants.spacingLg),
            Text(
              loc.topCategoryLabel(
                topCategoryName!,
                NumberUtils.formatCurrency(topCategoryTotal!, symbol: symbol, useDecimals: useDecimals),
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
          const SizedBox(height: AppConstants.spacingSm),
          Text(
            loc.savingsRateLabel(NumberUtils.formatPercentage(savingsRate.clamp(-1.0, 1.0))),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _statLine(BuildContext context, String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Text(
          NumberUtils.formatCurrency(amount, symbol: symbol, useDecimals: useDecimals),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
