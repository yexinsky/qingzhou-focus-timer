import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/layout_utils.dart';

class WeeklyChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;

  const WeeklyChart({super.key, required this.values, required this.labels});

  /// 图表高度按屏幕高度自适应（不再写死 180）：
  /// 横屏 360dp 高时不会把后续内容全挤出首屏，大屏上也不会被拉得过高。
  static double _chartHeight(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    return (screenHeight * 0.26).clamp(150.0, 210.0);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxValue = values.isEmpty
        ? 0.0
        : values.reduce((a, b) => a > b ? a : b);
    final primaryColor = isDark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

    return LayoutBuilder(
      builder: (context, constraints) {
        final outerWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 48;
        // 柱宽跟着可用宽度走，避免月视图（6 组）在窄屏上把柱子挤在一起。
        final contentWidth = (outerWidth - 32).clamp(0.0, double.infinity);
        final barCount = labels.isEmpty ? values.length : labels.length;
        final barWidth = barCount == 0
            ? 16.0
            : (contentWidth / barCount * 0.45).clamp(6.0, 24.0);

        return Container(
          height: _chartHeight(context),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          // 图内刻度/提示文字不是正文：限制缩放上限，避免系统字体放大后
          // 轴标签被裁切、tooltip 撑出图表区域。
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: LayoutUtils.maxTextScaleFactor,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue > 0 ? maxValue * 1.2 : 120,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => primaryColor,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    tooltipMargin: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toInt()}m',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[index],
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                      reservedSize: 28,
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                barGroups: values.asMap().entries.map((entry) {
                  final index = entry.key;
                  final value = entry.value;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: value,
                        width: barWidth,
                        color: primaryColor.withValues(alpha: 0.2),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxValue > 0 ? maxValue * 1.2 : 120,
                          color: primaryColor.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }
}
