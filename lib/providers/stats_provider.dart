import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/daily_stats.dart';
import '../data/models/focus_session.dart';
import '../data/repositories/task_repository.dart';
import '../core/utils/time_formatter.dart';
import 'timer_provider.dart';

final statsProvider = Provider<StatsNotifier>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  return StatsNotifier(taskRepo);
});

class StatsNotifier {
  final TaskRepository _taskRepo;

  StatsNotifier(this._taskRepo);

  DailyStats getTodayStats() {
    final todayKey = TimeFormatter.getTodayKey();
    final sessions = _taskRepo.getSessionsByDate(todayKey);
    final totalMinutes =
        sessions.fold(0, (sum, s) => sum + (s.duration ~/ 60));
    final subjectMinutes = <String, int>{};
    for (final session in sessions) {
      subjectMinutes[session.subject] =
          (subjectMinutes[session.subject] ?? 0) + (session.duration ~/ 60);
    }
    return DailyStats(
      dateKey: todayKey,
      totalMinutes: totalMinutes,
      completedPomodoros: sessions.length,
      subjectMinutes: subjectMinutes,
    );
  }

  List<DailyStats> getWeekStats() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final List<DailyStats> weekStats = [];

    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      final sessions = _taskRepo.getSessionsByDate(dateKey);
      final totalMinutes =
          sessions.fold(0, (sum, s) => sum + (s.duration ~/ 60));
      final subjectMinutes = <String, int>{};
      for (final session in sessions) {
        subjectMinutes[session.subject] =
            (subjectMinutes[session.subject] ?? 0) + (session.duration ~/ 60);
      }
      weekStats.add(DailyStats(
        dateKey: dateKey,
        totalMinutes: totalMinutes,
        completedPomodoros: sessions.length,
        subjectMinutes: subjectMinutes,
      ));
    }

    return weekStats;
  }

  WeeklyStats getWeeklySummary() {
    final weekStats = getWeekStats();
    final totalMinutes =
        weekStats.fold(0, (sum, day) => sum + day.totalMinutes);
    final totalPomodoros =
        weekStats.fold(0, (sum, day) => sum + day.completedPomodoros);
    return WeeklyStats(
      days: weekStats,
      totalMinutes: totalMinutes,
      totalPomodoros: totalPomodoros,
    );
  }

  List<FocusSession> getRecentSessions({int limit = 10}) {
    return _taskRepo.getRecentSessions(limit: limit);
  }
}
