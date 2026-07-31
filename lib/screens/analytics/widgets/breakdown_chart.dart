import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../../../providers/analytics_provider.dart';
import '../../../providers/settings_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../core/utils/number_utils.dart';

/// Donut chart showing breakdown of spending/income by category.
class BreakdownChart extends StatelessWidget {
  final List<CategoryAnalytics> data;
  final double total;

  const BreakdownChart({
    super.key,
    required this.data,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final palette = isDark ? AppColors.chartColorsDark : AppColors.chartColorsLight;

    return Stack(
      alignment: Alignment.center,
      children: [
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 50,
            startDegreeOffset: -90,
            sections: List.generate(data.length, (i) {
              final item = data[i];
              final color = palette[i % palette.length];
              final percentage = total > 0 ? (item.total / total) * 100 : 0;
              // Only show label if percentage is > 3% to avoid overlapping
              final showLabel = percentage > 3;

              return PieChartSectionData(
                color: color,
                value: item.total,
                title: showLabel ? '${percentage.toStringAsFixed(0)}%' : '',
                radius: 46,
                titleStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              );
            }),
          ),
        ),
        SizedBox(
          width: 90,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Total',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  NumberUtils.formatCurrency(
                    total,
                    symbol: settings.currencySymbol,
                    useDecimals: settings.currencyUseDecimals,
                  ),
                  style: AppTypography.amountStyle(
                    color: theme.textTheme.bodyLarge!.color!,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
