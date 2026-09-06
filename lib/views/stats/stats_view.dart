import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_formatter.dart';
import '../../providers/stats_provider.dart';
import '../../data/models/daily_stats.dart';
import '../../data/models/focus_session.dart';
import 'widgets/stat_card.dart';
import 'widgets/weekly_chart.dart';
import 'widgets/subject_pie_chart.dart';

enum StatsTab { day, week, month }

class StatsView extends ConsumerStatefulWidget {
  const StatsView({super.key});
  @override
  ConsumerState<StatsView> createState() => _StatsViewState();
}

class _StatsViewState extends ConsumerState<StatsView> {
  StatsTab _currentTab = StatsTab.week;

  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(statsProvider);
    final today = stats.getTodayStats();
    final week = stats.getWeeklySummary();
    final month = stats.getMonthlySummary();
    final period = switch (_currentTab) {
      StatsTab.day => WeeklyStats(
        days: [today],
        totalMinutes: today.totalMinutes,
        totalPomodoros: today.completedPomodoros,
      ),
      StatsTab.week => week,
      StatsTab.month => month,
    };
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildHeader(),
              const SizedBox(height: 24),
              _buildTabSelector(),
              const SizedBox(height: 24),
              _buildStatsCards(period),
              const SizedBox(height: 24),
              _buildChartSection(period),
              const SizedBox(height: 24),
              _buildSubjectSection(period),
              _buildRecentSessions(stats.getRecentSessions(limit: 5)),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  String get _periodLabel => switch (_currentTab) {
    StatsTab.day => '今日',
    StatsTab.week => '本周',
    StatsTab.month => '本月',
  };

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        '数据统计',
        style: Theme.of(
          context,
        ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w300),
      ),
    ),
  );

  Widget _buildTabSelector() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final entry in const [
          (StatsTab.day, '日'),
          (StatsTab.week, '周'),
          (StatsTab.month, '月'),
        ]) ...[
          _TabItem(
            label: entry.$2,
            isSelected: _currentTab == entry.$1,
            onTap: () => setState(() => _currentTab = entry.$1),
          ),
          if (entry.$1 != StatsTab.month) const SizedBox(width: 16),
        ],
      ],
    ),
  );

  Widget _buildStatsCards(WeeklyStats period) {
    final formatted = TimeFormatter.formatMinutesForDisplay(
      period.totalMinutes,
    );
    final divisor = period.days.isEmpty ? 1 : period.days.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: '总专注时长',
              value: formatted['hasHours']
                  ? '${formatted['hours']}'
                  : '${formatted['minutes']}',
              unit: formatted['hasHours']
                  ? 'h ${formatted['minutes']}m'
                  : 'min',
              subtitle: '$_periodLabel累计',
              icon: Icons.timer_outlined,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StatCard(
              title: '番茄数',
              value: '${period.totalPomodoros}',
              unit: '个',
              subtitle: _currentTab == StatsTab.day
                  ? '今日完成 ${period.totalPomodoros} 个'
                  : '平均每日 ${(period.totalPomodoros / divisor).toStringAsFixed(1)} 个',
              icon: Icons.eco_outlined,
              iconColor: AppColors.subjectMath,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(WeeklyStats period) {
    var days = period.days;
    var labels = <String>[];
    if (_currentTab == StatsTab.day) {
      labels = ['今日'];
    } else if (_currentTab == StatsTab.week) {
      labels = const ['一', '二', '三', '四', '五', '六', '日'];
    } else {
      // Keep monthly charts readable by aggregating each seven-day block.
      final grouped = <DailyStats>[];
      for (var start = 0; start < days.length; start += 7) {
        final slice = days.skip(start).take(7).toList();
        grouped.add(
          DailyStats(
            dateKey: slice.first.dateKey,
            totalMinutes: slice.fold(0, (sum, day) => sum + day.totalMinutes),
            completedPomodoros: slice.fold(
              0,
              (sum, day) => sum + day.completedPomodoros,
            ),
            subjectMinutes: const {},
          ),
        );
        labels.add('${start + 1}-${start + slice.length}');
      }
      days = grouped;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '专注波动',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                _periodLabel,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WeeklyChart(
            values: days.map((d) => d.totalMinutes.toDouble()).toList(),
            labels: labels,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSection(WeeklyStats period) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24),
    child: SubjectPieChart(
      percentages: period.subjectPercentages,
      centerText: _periodLabel,
    ),
  );

  Widget _buildRecentSessions(List<FocusSession> sessions) {
    if (sessions.isEmpty) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            '最近记录',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...sessions.map((session) {
            final color = AppColors.getSubjectColor(session.subject);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session.taskTitle ?? '自由专注',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${session.duration ~/ 60}分钟',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _TabItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryDark
        : AppColors.primaryLight;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected ? primary : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 2,
            decoration: BoxDecoration(
              color: isSelected ? primary : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
