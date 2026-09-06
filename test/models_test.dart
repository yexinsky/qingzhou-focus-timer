import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/daily_stats.dart';
import 'package:qingzhou_focus/data/models/focus_session.dart';
import 'package:qingzhou_focus/data/models/task.dart';

void main() {
  group('Task', () {
    final task = Task(
      id: 'task-1',
      title: '复习高数',
      subject: '数学',
      dateKey: '2026-09-06',
      createdAt: 123456,
    );

    test('JSON round-trip preserves fields and defaults completed', () {
      final decoded = Task.fromJson(task.toJson());
      expect(decoded.id, task.id);
      expect(decoded.title, task.title);
      expect(decoded.subject, task.subject);
      expect(decoded.completed, isFalse);
      expect(decoded.dateKey, task.dateKey);
      expect(decoded.createdAt, task.createdAt);
    });

    test('copyWith updates selected fields only', () {
      final copy = task.copyWith(title: '刷真题', completed: true);
      expect(copy.title, '刷真题');
      expect(copy.completed, isTrue);
      expect(copy.id, task.id);
      expect(copy.subject, task.subject);
    });
  });

  group('FocusSession', () {
    final session = FocusSession(
      id: 'session-1',
      taskId: 'task-1',
      taskTitle: '复习高数',
      subject: '数学',
      startTime: 1000,
      duration: 1500,
      type: 'focus',
      dateKey: '2026-09-06',
    );

    test('JSON round-trip preserves all values', () {
      final decoded = FocusSession.fromJson(session.toJson());
      expect(decoded.id, session.id);
      expect(decoded.taskId, session.taskId);
      expect(decoded.taskTitle, session.taskTitle);
      expect(decoded.subject, session.subject);
      expect(decoded.startTime, session.startTime);
      expect(decoded.duration, session.duration);
      expect(decoded.type, session.type);
      expect(decoded.dateKey, session.dateKey);
    });

    test('copyWith preserves nullable task association when omitted', () {
      final copy = session.copyWith(duration: 2700);
      expect(copy.duration, 2700);
      expect(copy.taskId, 'task-1');
      expect(copy.taskTitle, '复习高数');
    });
  });

  group('DailyStats and WeeklyStats', () {
    test('empty factory creates zero-valued stats', () {
      final empty = DailyStats.empty('2026-09-06');
      expect(empty.dateKey, '2026-09-06');
      expect(empty.totalMinutes, 0);
      expect(empty.completedPomodoros, 0);
      expect(empty.subjectMinutes, isEmpty);
    });

    test('DailyStats JSON round-trip preserves subject minutes', () {
      final stats = DailyStats(
        dateKey: '2026-09-06',
        totalMinutes: 75,
        completedPomodoros: 3,
        subjectMinutes: {'数学': 50, '英语': 25},
      );
      final decoded = DailyStats.fromJson(stats.toJson());
      expect(decoded.totalMinutes, 75);
      expect(decoded.completedPomodoros, 3);
      expect(decoded.subjectMinutes, {'数学': 50, '英语': 25});
    });

    test('subject percentages aggregate across days', () {
      final summary = WeeklyStats(
        days: [
          DailyStats(
            dateKey: 'a',
            totalMinutes: 60,
            completedPomodoros: 2,
            subjectMinutes: {'数学': 30, '英语': 30},
          ),
          DailyStats(
            dateKey: 'b',
            totalMinutes: 40,
            completedPomodoros: 1,
            subjectMinutes: {'数学': 40},
          ),
        ],
        totalMinutes: 100,
        totalPomodoros: 3,
      );
      expect(summary.subjectPercentages['数学'], closeTo(70, 0.001));
      expect(summary.subjectPercentages['英语'], closeTo(30, 0.001));
    });

    test('subject percentages are empty without tracked minutes', () {
      final summary = WeeklyStats(days: [], totalMinutes: 0, totalPomodoros: 0);
      expect(summary.subjectPercentages, isEmpty);
    });
  });
}
