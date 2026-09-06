import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/focus_session.dart';
import 'package:qingzhou_focus/data/models/task.dart';
import 'package:qingzhou_focus/data/repositories/task_repository.dart';

void main() {
  late TaskRepository repository;
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('qingzhou_test_');
    repository = TaskRepository(storagePath: tempDirectory.path);
    await repository.init();
  });

  tearDown(() async {
    await repository.clearAllData();
    await repository.close();
    await tempDirectory.delete(recursive: true);
  });

  Task task(
    String id,
    String dateKey, {
    bool completed = false,
    int createdAt = 1,
  }) => Task(
    id: id,
    title: id,
    subject: '数学',
    completed: completed,
    dateKey: dateKey,
    createdAt: createdAt,
  );

  FocusSession session(
    String id,
    String dateKey, {
    int startTime = 1,
    int duration = 1500,
    String type = 'focus',
    String subject = '数学',
  }) => FocusSession(
    id: id,
    subject: subject,
    startTime: startTime,
    duration: duration,
    type: type,
    dateKey: dateKey,
  );

  test('task CRUD persists and completion updates the stored task', () async {
    final today = DateTime.now();
    final key =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    await repository.addTask(task('a', key));
    expect(repository.getTodayTasks().single.id, 'a');
    await repository.updateTask(task('a', key).copyWith(title: 'updated'));
    expect(repository.getTodayTasks().single.title, 'updated');
    await repository.completeTask('a');
    expect(repository.getTodayTasks().single.completed, isTrue);
    await repository.deleteTask('a');
    expect(repository.getTodayTasks(), isEmpty);
  });

  test('today query excludes history without deleting it', () async {
    final now = DateTime.now();
    final today =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await repository.addTask(task('today', today));
    await repository.addTask(task('history', '2020-01-01'));
    expect(repository.getTodayTasks().map((e) => e.id), ['today']);
    await repository.updateTask(task('history', today));
    expect(repository.getTodayTasks().map((e) => e.id).toSet(), {
      'today',
      'history',
    });
  });

  test('today tasks sort incomplete first then newest first', () async {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await repository.addTask(task('old', key, createdAt: 1));
    await repository.addTask(task('done', key, completed: true, createdAt: 3));
    await repository.addTask(task('new', key, createdAt: 2));
    expect(repository.getTodayTasks().map((e) => e.id), ['new', 'old', 'done']);
    expect(repository.getIncompleteTasks().map((e) => e.id), ['new', 'old']);
  });

  test('session queries filter focus type and order newest first', () async {
    await repository.addSession(session('old', '2026-09-06', startTime: 1));
    await repository.addSession(session('new', '2026-09-06', startTime: 3));
    await repository.addSession(
      session('break', '2026-09-06', startTime: 4, type: 'break'),
    );
    await repository.addSession(
      session('other-day', '2026-09-05', startTime: 5),
    );
    expect(repository.getSessionsByDate('2026-09-06').map((e) => e.id), [
      'new',
      'old',
    ]);
    expect(repository.getRecentSessions(limit: 2).map((e) => e.id), [
      'other-day',
      'new',
    ]);
  });

  test('today aggregations sum minutes, pomodoros, and subjects', () async {
    final now = DateTime.now();
    final key =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    await repository.addSession(session('a', key, duration: 25 * 60));
    await repository.addSession(
      session('b', key, duration: 45 * 60, subject: '英语'),
    );
    expect(repository.getTodayTotalMinutes(), 70);
    expect(repository.getTodayCompletedPomodoros(), 2);
    expect(repository.getTodaySubjectMinutes(), {'数学': 25, '英语': 45});
  });
}
