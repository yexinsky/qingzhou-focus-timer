import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/time_formatter.dart';
import '../../../data/models/daily_stats.dart';

class DayDetailSheet extends StatelessWidget {
  final DailyStats stats;
  final DateTime date;

  const DayDetailSheet({super.key, required this.stats, required this.date});

  static const _weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  String get _dateTitle {
    final weekday = _weekdays[date.weekday - 1];
    return '${date.year}年${date.month}月${date.day}日 $weekday';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final media = MediaQuery.of(context);
    // 弹窗由 showAdaptiveBottomSheet(isScrollControlled: true) 打开，此时
    // 可用高度是无界的：必须自己封顶，否则小屏 / 横屏 / 字体放大时
    // Column(mainAxisSize.min) 会直接超出屏幕并报 RenderFlex overflow。
    // 上限取视口的 85%，给状态栏与黑幕留出可点击关闭的区域。
    final maxHeight = media.size.height * 0.85;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖手固定在顶部，不随内容滚走。
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                // 底部安全区（手势条 / 刘海屏）直接算进滚动内容的 padding，
                // 内容再长也能滚到底看到最后一行，且不会被系统导航条压住。
                padding: EdgeInsets.fromLTRB(
                  24,
                  20,
                  24,
                  24 + media.padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _dateTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _SummaryItem(
                            label: '专注时长',
                            value: TimeFormatter.formatMinutes(
                              stats.totalMinutes,
                            ),
                            icon: Icons.timer_outlined,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SummaryItem(
                            label: '专注段',
                            value: '${stats.completedPomodoros} 个',
                            icon: Icons.check_circle_outline,
                            iconColor: AppColors.subjectMath,
                          ),
                        ),
                      ],
                    ),
                    if (stats.subjectMinutes.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _buildSubjectBreakdown(context),
                    ],
                    if (stats.totalMinutes == 0) ...[
                      const SizedBox(height: 24),
                      Text(
                        '这天没有专注记录',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectBreakdown(BuildContext context) {
    final sorted = stats.subjectMinutes.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sorted.fold<int>(0, (sum, e) => sum + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '科目分布',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        for (final entry in sorted)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.getSubjectColor(entry.key),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    entry.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(width: 8),
                // 时长 + 百分比整体可缩：字体放大到 2.0 时数值不会把
                // 科目名挤成 0 宽而溢出。
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerEnd,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          TimeFormatter.formatMinutes(entry.value),
                          maxLines: 1,
                          softWrap: false,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(entry.value / total * 100).toStringAsFixed(0)}%',
                          maxLines: 1,
                          softWrap: false,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                        ),
                      ],
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

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? iconColor;

  const _SummaryItem({
    required this.label,
    required this.value,
    required this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardDark.withValues(alpha: 0.5)
            : AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor ?? AppColors.textSecondary),
          const SizedBox(height: 8),
          // 两列等宽卡片里，数值在 320dp + textScale 2.0 下必然超宽：
          // 用 FittedBox 等比缩小而不是换行/截断，读数完整且不溢出。
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              softWrap: false,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
