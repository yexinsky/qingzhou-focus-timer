import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/daily_stats.dart';
import '../data/models/focus_session.dart';
import '../data/repositories/task_repository.dart';
import 'timer_provider.dart';

final statsRefreshProvider = StateProvider<int>((ref) => 0);

final statsProvider = Provider<StatsNotifier>((ref) {
  ref.watch(statsRefreshProvider);
  return StatsNotifier(ref.watch(taskRepositoryProvider));
});

final yearStatsProvider = Provider<List<DailyStats>>((ref) {
  ref.watch(statsRefreshProvider);
  return ref.watch(statsProvider).getYearStats();
});

class StatsNotifier {
  final TaskRepository _taskRepo;
  final DateTime Function() _now;

  StatsNotifier(this._taskRepo, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  DailyStats getTodayStats() => _statsForDate(_now(), _groupSessionsByDate());

  List<DailyStats> getWeekStats() {
    final now = _dateOnly(_now());
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return _statsForRange(monday, 7);
  }

  List<DailyStats> getMonthStats() {
    final now = _now();
    final firstDay = DateTime(now.year, now.month);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return _statsForRange(firstDay, daysInMonth);
  }

  WeeklyStats getWeeklySummary() => _summary(getWeekStats());

  WeeklyStats getMonthlySummary() => _summary(getMonthStats());

  List<DailyStats> getYearStats() {
    final now = _dateOnly(_now());
    final start = now.subtract(const Duration(days: 364));
    final alignedStart = start.subtract(Duration(days: start.weekday - 1));
    final dayCount = now.difference(alignedStart).inDays + 1;
    return _statsForRange(alignedStart, dayCount);
  }

  DailyStats getStatsForDate(DateTime date) =>
      _statsForDate(date, _groupSessionsByDate());

  List<FocusSession> getRecentSessions({int limit = 10}) =>
      _taskRepo.getRecentSessions(limit: limit);

  /// 一次全表扫描按 dateKey 分组，替代逐日 getSessionsByDate 的 N+1 全量扫描
  /// （getYearStats 一年约 370 次日查询 → 1 次遍历）。
  /// getAllSessions 已按 startTime 倒序，分组后每个日期内仍保持倒序。
  Map<String, List<FocusSession>> _groupSessionsByDate() {
    final grouped = <String, List<FocusSession>>{};
    for (final session in _taskRepo.getAllSessions()) {
      if (session.type != 'focus') continue;
      grouped.putIfAbsent(session.dateKey, () => []).add(session);
    }
    return grouped;
  }

  List<DailyStats> _statsForRange(DateTime start, int dayCount) {
    final grouped = _groupSessionsByDate();
    return List.generate(
      dayCount,
      (index) => _statsForDate(start.add(Duration(days: index)), grouped),
    );
  }

  DailyStats _statsForDate(
    DateTime date,
    Map<String, List<FocusSession>> sessionsByDateKey,
  ) {
    final dateKey = _dateKey(date);
    final sessions = sessionsByDateKey[dateKey] ?? const <FocusSession>[];
    final subjectSeconds = <String, int>{};
    var totalSeconds = 0;
    var completedPomodoros = 0;
    for (final session in sessions) {
      totalSeconds += session.duration;
      subjectSeconds.update(
        session.subject,
        (value) => value + session.duration,
        ifAbsent: () => session.duration,
      );
      if (session.timerMode != 'stopwatch') {
        completedPomodoros++;
      }
    }
    return DailyStats(
      dateKey: dateKey,
      totalMinutes: totalSeconds ~/ 60,
      completedPomodoros: completedPomodoros,
      subjectMinutes: subjectSeconds.map(
        (subject, seconds) => MapEntry(subject, seconds ~/ 60),
      ),
    );
  }

  WeeklyStats _summary(List<DailyStats> days) => WeeklyStats(
    days: days,
    totalMinutes: days.fold(0, (sum, day) => sum + day.totalMinutes),
    totalPomodoros: days.fold(0, (sum, day) => sum + day.completedPomodoros),
  );

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateKey(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}
