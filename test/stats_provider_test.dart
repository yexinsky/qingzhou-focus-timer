import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/focus_session.dart';
import 'package:qingzhou_focus/providers/stats_provider.dart';

import 'helpers/test_repositories.dart';

void main() {
  late TestTaskRepository repository;
  final now = DateTime(2026, 9, 6, 12);

  setUp(() => repository = TestTaskRepository());

  FocusSession session(
    String id,
    String date,
    int minutes,
    String subject, {
    String type = 'focus',
    int start = 0,
  }) => FocusSession(
    id: id,
    subject: subject,
    startTime: start,
    duration: minutes * 60,
    type: type,
    dateKey: date,
  );

  test('today statistics aggregate focus sessions and subjects', () {
    repository.sessions.addAll({
      '1': session('1', '2026-09-06', 25, '数学'),
      '2': session('2', '2026-09-06', 45, '英语'),
      '3': session('3', '2026-09-06', 5, '休息', type: 'break'),
    });
    final stats = StatsNotifier(repository, now: () => now).getTodayStats();
    expect(stats.totalMinutes, 70);
    expect(stats.completedPomodoros, 2);
    expect(stats.subjectMinutes, {'数学': 25, '英语': 45});
  });

  test('week begins Monday and always returns seven days', () {
    repository.sessions['1'] = session('1', '2026-08-31', 30, '数学');
    repository.sessions['2'] = session('2', '2026-09-06', 20, '英语');
    final notifier = StatsNotifier(repository, now: () => now);
    final days = notifier.getWeekStats();
    expect(days, hasLength(7));
    expect(days.first.dateKey, '2026-08-31');
    expect(days.last.dateKey, '2026-09-06');
    expect(notifier.getWeeklySummary().totalMinutes, 50);
    expect(notifier.getWeeklySummary().totalPomodoros, 2);
  });

  test('month uses actual month length and excludes adjacent months', () {
    repository.sessions['1'] = session('1', '2026-09-01', 25, '数学');
    repository.sessions['2'] = session('2', '2026-09-30', 25, '数学');
    repository.sessions['3'] = session('3', '2026-10-01', 90, '数学');
    final notifier = StatsNotifier(repository, now: () => now);
    final days = notifier.getMonthStats();
    expect(days, hasLength(30));
    expect(days.first.dateKey, '2026-09-01');
    expect(days.last.dateKey, '2026-09-30');
    expect(notifier.getMonthlySummary().totalMinutes, 50);
  });

  test('durations shorter than one minute are consistently rounded down', () {
    repository.sessions['1'] = FocusSession(
      id: '1',
      subject: '其他',
      startTime: 0,
      duration: 59,
      type: 'focus',
      dateKey: '2026-09-06',
    );
    expect(
      StatsNotifier(repository, now: () => now).getTodayStats().totalMinutes,
      0,
    );
  });

  test('recent session limit is delegated', () {
    for (var i = 0; i < 5; i++) {
      repository.sessions['$i'] = session(
        '$i',
        '2026-09-06',
        25,
        '数学',
        start: i,
      );
    }
    final recent = StatsNotifier(
      repository,
      now: () => now,
    ).getRecentSessions(limit: 2);
    expect(recent.map((e) => e.startTime), [4, 3]);
  });
}
