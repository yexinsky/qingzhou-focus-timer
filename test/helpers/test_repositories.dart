import 'package:qingzhou_focus/data/models/focus_session.dart';
import 'package:qingzhou_focus/data/models/task.dart';
import 'package:qingzhou_focus/data/repositories/task_repository.dart';

class TestTaskRepository extends TaskRepository {
  final Map<String, Task> tasks = {};
  final Map<String, FocusSession> sessions = {};

  @override
  List<Task> getTasksByDate(String dateKey) {
    final values =
        tasks.values.where((task) => task.dateKey == dateKey).toList()..sort((
          a,
          b,
        ) {
          if (a.completed != b.completed) return a.completed ? 1 : -1;
          final priority = b.priority.compareTo(a.priority);
          return priority != 0 ? priority : b.createdAt.compareTo(a.createdAt);
        });
    return values;
  }

  @override
  int getTaskFocusCount(String taskId) => sessions.values
      .where((session) => session.type == 'focus' && session.taskId == taskId)
      .length;

  @override
  Map<String, int> getFocusCountByTaskId() {
    final counts = <String, int>{};
    for (final session in sessions.values) {
      final taskId = session.taskId;
      if (session.type == 'focus' && taskId != null) {
        counts[taskId] = (counts[taskId] ?? 0) + 1;
      }
    }
    return counts;
  }

  @override
  List<FocusSession> getAllSessions() =>
      sessions.values.toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  @override
  Future<void> postponeTask(String taskId, String dateKey) async {
    final task = tasks[taskId];
    if (task != null)
      tasks[taskId] = task.copyWith(dateKey: dateKey, completed: false);
  }

  @override
  List<Task> getTodayTasks() {
    final values = tasks.values.toList()
      ..sort((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return values;
  }

  @override
  Future<void> addTask(Task task) async => tasks[task.id] = task;

  @override
  Future<void> updateTask(Task task) async => tasks[task.id] = task;

  @override
  Future<void> deleteTask(String taskId) async => tasks.remove(taskId);

  @override
  Future<void> completeTask(String taskId) async {
    final task = tasks[taskId];
    if (task != null) tasks[taskId] = task.copyWith(completed: true);
  }

  @override
  Future<void> addSession(FocusSession session) async =>
      sessions[session.id] = session;

  @override
  List<FocusSession> getSessionsByDate(String dateKey) =>
      sessions.values
          .where(
            (session) => session.dateKey == dateKey && session.type == 'focus',
          )
          .toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  @override
  List<FocusSession> getRecentSessions({int limit = 10}) {
    final values = sessions.values.where((s) => s.type == 'focus').toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return values.take(limit).toList();
  }
}
