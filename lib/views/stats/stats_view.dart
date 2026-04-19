import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/time_formatter.dart';
import '../../providers/stats_provider.dart';
import '../../data/models/daily_stats.dart';
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
    final statsNotifier = ref.watch(statsProvider);

    final todayStats = statsNotifier.getTodayStats();
    final weeklyStats = statsNotifier.getWeeklySummary();
    final recentSessions = statsNotifier.getRecentSessions(limit: 5);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 60),
              _buildHeader(context),
              const SizedBox(height: 24),
              _buildTabSelector(),
              const SizedBox(height: 24),
              _buildStatsCards(todayStats, weeklyStats),
              const SizedBox(height: 24),
              _buildChartSection(weeklyStats),
              const SizedBox(height: 24),
              if (_currentTab == StatsTab.week)
                _buildSubjectSection(weeklyStats),
              _buildRecentSessions(recentSessions),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '数据统计',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _TabItem(
            label: '日',
            isSelected: _currentTab == StatsTab.day,
            onTap: () => setState(() => _currentTab = StatsTab.day),
          ),
          const SizedBox(width: 16),
          _TabItem(
            label: '周',
            isSelected: _currentTab == StatsTab.week,
            onTap: () => setState(() => _currentTab = StatsTab.week),
          ),
          const SizedBox(width: 16),
          _TabItem(
            label: '月',
            isSelected: _currentTab == StatsTab.month,
            onTap: () => setState(() => _currentTab = StatsTab.month),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCards(DailyStats todayStats, WeeklyStats weeklyStats) {
    final displayMinutes = _currentTab == StatsTab.day
        ? todayStats.totalMinutes
        : weeklyStats.totalMinutes;
    final displayPomodoros = _currentTab == StatsTab.day
        ? todayStats.completedPomodoros
        : weeklyStats.totalPomodoros;
    final formattedTime = TimeFormatter.formatMinutesForDisplay(displayMinutes);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          Expanded(
            child: StatCard(
              title: '总专注时长',
              value: formattedTime['hasHours']
                  ? '${formattedTime['hours']}'
                  : '${formattedTime['minutes']}',
              unit: formattedTime['hasHours'] ? 'h ${formattedTime['minutes']}m' : 'min',
              subtitle: _currentTab == StatsTab.day ? '今日' : '本周累计',
              icon: PhosphorIcons.timer(PhosphorIconsStyle.regular),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: StatCard(
              title: '番茄数',
              value: '$displayPomodoros',
              unit: '个',
              subtitle: '平均每日 ${(displayPomodoros / 7).toStringAsFixed(1)} 个',
              icon: PhosphorIcons.plant(PhosphorIconsStyle.regular),
              iconColor: AppColors.subjectMath,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection(WeeklyStats weeklyStats) {
    final chartValues = weeklyStats.days
        .map((d) => d.totalMinutes.toDouble())
        .toList();
    final chartLabels = ['一', '二', '三', '四', '五', '六', '日'];

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
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              Text(
                '本周',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          WeeklyChart(
            values: chartValues,
            labels: chartLabels,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSection(WeeklyStats weeklyStats) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SubjectPieChart(
        percentages: weeklyStats.subjectPercentages,
        centerText: '本周',
      ),
    );
  }

  Widget _buildRecentSessions(List recentSessions) {
    if (recentSessions.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            '最近记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          ...recentSessions.take(5).map((session) {
            final subjectColor = AppColors.getSubjectColor(session.subject);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: subjectColor.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: subjectColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        session.taskTitle ?? '自由专注',
                        style: Theme.of(context).textTheme.bodyMedium,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

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
              color: isSelected ? primaryColor : AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24,
            height: 2,
            decoration: BoxDecoration(
              color: isSelected ? primaryColor : Colors.transparent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ],
      ),
    );
  }
}
