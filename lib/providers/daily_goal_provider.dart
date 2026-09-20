import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'settings_provider.dart';
import 'stats_provider.dart';
import 'task_provider.dart';
import 'timer_provider.dart' show taskRepositoryProvider;

/// 日历当前显示的月份（yyyy-MM），供任务圆点使用
final calendarMonthProvider = StateProvider<String>((ref) {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}';
});

/// 有任务的日期集合，随任务增删（statsRefreshProvider）刷新
final monthTaskDateKeysProvider = Provider<Set<String>>((ref) {
  ref.watch(statsRefreshProvider);
  final monthKey = ref.watch(calendarMonthProvider);
  return ref.watch(taskRepositoryProvider).getTaskDateKeysInMonth(monthKey);
});

class DailyGoal {
  /// 当日目标专注段数
  final int target;

  /// 当日已完成的专注段数（不含灵活计时）
  final int completed;
  final bool hasCustomTarget;

  const DailyGoal({
    required this.target,
    required this.completed,
    this.hasCustomTarget = false,
  });

  double get progress => target <= 0 ? 0 : (completed / target).clamp(0, 1);
  bool get reached => target > 0 && completed >= target;
}

Map<String, int> parseDailyGoals(String json) {
  try {
    final map = jsonDecode(json) as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as num).toInt()));
  } catch (_) {
    return {};
  }
}

final dailyGoalProvider = Provider.family<DailyGoal, DateTime>((ref, date) {
  ref.watch(statsRefreshProvider);
  final settings = ref.watch(settingsProvider);
  final goals = parseDailyGoals(settings.dailyGoalsJson);
  final key = TasksNotifier.dateKey(date);
  return DailyGoal(
    target: goals[key] ?? settings.defaultDailyGoal,
    completed: ref
        .watch(statsProvider)
        .getStatsForDate(date)
        .completedPomodoros,
    hasCustomTarget: goals.containsKey(key),
  );
});

/// 设置/清除（null = 恢复默认）某日目标
Future<void> setDailyGoal(WidgetRef ref, DateTime date, int? count) async {
  final goals = parseDailyGoals(ref.read(settingsProvider).dailyGoalsJson);
  final key = TasksNotifier.dateKey(date);
  if (count == null) {
    goals.remove(key);
  } else {
    goals[key] = count;
  }
  // 清理 180 天前的过期记录，避免无限增长
  if (goals.length > 400) {
    final cutoffKey = TasksNotifier.dateKey(
      DateTime.now().subtract(const Duration(days: 180)),
    );
    goals.removeWhere((k, _) => k.compareTo(cutoffKey) < 0);
  }
  await ref
      .read(settingsProvider.notifier)
      .setDailyGoalsJson(jsonEncode(goals));
}
