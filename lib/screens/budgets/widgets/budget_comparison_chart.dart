import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/number_utils.dart';
import '../../../l10n/app_localizations.dart';
import '../../../providers/budget_provider.dart';
import '../../../providers/settings_provider.dart';
import '../budget_overview_data.dart';

class BudgetChartItem {
  final String title;
  final BudgetStatus status;

  const BudgetChartItem({required this.title, required this.status});
}

class BudgetComparisonChart extends StatefulWidget {
  final List<BudgetChartItem> items;
  final SettingsProvider settings;

  const BudgetComparisonChart({
    super.key,
    required this.items,
    required this.settings,
  });

  @override
  State<BudgetComparisonChart> createState() => _BudgetComparisonChartState();
}

class _BudgetComparisonChartState extends State<BudgetComparisonChart> {
  int? _selectedIndex;
  bool _hasPainted = false;

  @override
  void didUpdateWidget(covariant BudgetComparisonChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selectedIndex;
    if (selected != null && selected >= widget.items.length) {
      _selectedIndex = null;
    }
    if (_identity(oldWidget.items) != _identity(widget.items)) {
      _selectedIndex = null;
    }
  }

  String _identity(List<BudgetChartItem> items) => items
      .map(
        (item) =>
            '${item.status.budget.id}:${item.status.effectiveAmount}:${item.status.spent}',
      )
      .join('|');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final loc = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final statuses = widget.items.map((item) => item.status).toList();
    final maxY = budgetChartMaximum(statuses);
    final hideAmounts = widget.settings.hideBalances;
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final axisReservedSize = 54.0 + ((textScale - 1).clamp(0.0, 1.0) * 40);
    final duration = MediaQuery.disableAnimationsOf(context) || !_hasPainted
        ? Duration.zero
        : AppConstants.animNormal;
    WidgetsBinding.instance.addPostFrameCallback((_) => _hasPainted = true);

    String money(double value) => NumberUtils.formatCurrencyLocalized(
      value,
      locale: locale,
      symbol: widget.settings.currencySymbol,
      useDecimals: widget.settings.currencyUseDecimals,
    );
    String compactMoney(double value) =>
        NumberUtils.formatCompactCurrencyLocalized(
          value,
          locale: locale,
          symbol: widget.settings.currencySymbol,
        );

    final semantics = widget.items
        .map((item) {
          final status = item.status;
          final delta = status.effectiveAmount - status.spent;
          final detail = delta < 0
              ? loc.budgetOverspentAmount(money(-delta))
              : '${money(delta)} ${loc.left}';
          return '${item.title}: ${loc.budgetedLabel} '
              '${money(status.effectiveAmount)}, ${loc.spent} '
              '${money(status.spent)}, $detail';
        })
        .join('. ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(loc.budgetChartTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: AppConstants.spacingXs),
        Text(loc.budgetChartHint, style: theme.textTheme.bodySmall),
        const SizedBox(height: AppConstants.spacingMd),
        Wrap(
          spacing: AppConstants.spacingLg,
          runSpacing: AppConstants.spacingSm,
          children: [
            _LegendItem(
              color: _budgetedColor(theme),
              label: loc.budgetedLabel,
              outlined: true,
            ),
            _LegendItem(color: theme.colorScheme.primary, label: loc.spent),
          ],
        ),
        const SizedBox(height: AppConstants.spacingMd),
        LayoutBuilder(
          builder: (context, constraints) {
            final chartWidth = math.max(
              constraints.maxWidth,
              widget.items.length * 72.0,
            );
            return Semantics(
              label: hideAmounts ? loc.budgetChartHiddenAmounts : semantics,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: chartWidth,
                  height: 250,
                  child: BarChart(
                    BarChartData(
                      minY: 0,
                      maxY: maxY,
                      alignment: BarChartAlignment.spaceAround,
                      groupsSpace: AppConstants.spacingLg,
                      barGroups: [
                        for (var i = 0; i < widget.items.length; i++)
                          _group(context, i, selected: _selectedIndex == i),
                      ],
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: !hideAmounts,
                            reservedSize: axisReservedSize,
                            interval: maxY / 2,
                            getTitlesWidget: (value, meta) {
                              if (value != 0 &&
                                  value != maxY / 2 &&
                                  value != maxY) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Text(
                                  compactMoney(value),
                                  maxLines: 1,
                                  style: theme.textTheme.labelSmall,
                                  textAlign: TextAlign.right,
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 52,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();
                              if (index < 0 || index >= widget.items.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 64,
                                  child: Text(
                                    widget.items[index].title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.labelSmall,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: FlGridData(
                        drawVerticalLine: false,
                        horizontalInterval: maxY / 2,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: theme.colorScheme.outline.withValues(
                            alpha: value == 0 ? 0.9 : 0.35,
                          ),
                          strokeWidth: value == 0 ? 1.25 : 1,
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(
                            color: theme.colorScheme.outline,
                            width: 1.25,
                          ),
                        ),
                      ),
                      barTouchData: BarTouchData(
                        handleBuiltInTouches: false,
                        touchExtraThreshold: const EdgeInsets.all(10),
                        touchCallback: (event, response) {
                          if (event is! FlTapUpEvent) return;
                          final index = response?.spot?.touchedBarGroupIndex;
                          setState(() => _selectedIndex = index);
                        },
                        touchTooltipData: BarTouchTooltipData(
                          fitInsideHorizontally: true,
                          fitInsideVertically: true,
                          maxContentWidth: 210,
                          tooltipRoundedRadius: AppConstants.radiusSm,
                          getTooltipColor: (_) =>
                              theme.colorScheme.inverseSurface,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                            final item = widget.items[groupIndex];
                            final status = item.status;
                            final delta = status.effectiveAmount - status.spent;
                            final budgeted = hideAmounts
                                ? '••••••'
                                : money(status.effectiveAmount);
                            final spent = hideAmounts
                                ? '••••••'
                                : money(status.spent);
                            final balance = hideAmounts
                                ? '••••••'
                                : money(delta.abs());
                            final balanceLabel = delta < 0
                                ? loc.budgetOverLimit
                                : loc.remaining;
                            return BarTooltipItem(
                              '${item.title}\n'
                              '${loc.budgetedLabel}: $budgeted\n'
                              '${loc.spent}: $spent\n'
                              '$balanceLabel: $balance',
                              theme.textTheme.labelMedium!.copyWith(
                                color: theme.colorScheme.onInverseSurface,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    duration: duration,
                    curve: Curves.easeOutCubic,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  BarChartGroupData _group(
    BuildContext context,
    int index, {
    required bool selected,
  }) {
    final theme = Theme.of(context);
    final status = widget.items[index].status;
    final budgeted = math.max(0.0, status.effectiveAmount);
    final spent = math.max(0.0, status.spent);
    final isOver = status.spent > status.effectiveAmount;
    final width = selected ? 12.0 : 10.0;
    final radius = const BorderRadius.vertical(top: Radius.circular(4));
    return BarChartGroupData(
      x: index,
      barsSpace: 5,
      showingTooltipIndicators: selected ? const [1] : const [],
      barRods: [
        BarChartRodData(
          toY: budgeted,
          width: width,
          color: _budgetedColor(theme),
          borderSide: BorderSide(
            color: theme.colorScheme.outline,
            width: selected ? 1.5 : 1,
          ),
          borderRadius: radius,
        ),
        BarChartRodData(
          toY: spent,
          width: width,
          color: isOver ? theme.colorScheme.error : theme.colorScheme.primary,
          borderRadius: radius,
        ),
      ],
    );
  }

  Color _budgetedColor(ThemeData theme) => Color.alphaBlend(
    theme.colorScheme.onSurface.withValues(alpha: 0.18),
    theme.colorScheme.surfaceContainer,
  );
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;

  const _LegendItem({
    required this.color,
    required this.label,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: outlined
                ? Border.all(color: theme.colorScheme.outline)
                : null,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Text(label, style: theme.textTheme.labelMedium),
      ],
    );
  }
}
