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

class StatsNotifier {
  final TaskRepository _taskRepo;
  final DateTime Function() _now;

  StatsNotifier(this._taskRepo, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  DailyStats getTodayStats() => _statsForDate(_now());

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

  List<FocusSession> getRecentSessions({int limit = 10}) =>
      _taskRepo.getRecentSessions(limit: limit);

  List<DailyStats> _statsForRange(DateTime start, int dayCount) =>
      List.generate(
        dayCount,
        (index) => _statsForDate(start.add(Duration(days: index))),
      );

  DailyStats _statsForDate(DateTime date) {
    final dateKey = _dateKey(date);
    final sessions = _taskRepo.getSessionsByDate(dateKey);
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
