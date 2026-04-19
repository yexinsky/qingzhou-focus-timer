import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../../core/utils/time_formatter.dart';

class TaskRepository {
  static const String _taskBoxName = 'tasks';
  static const String _sessionBoxName = 'sessions';

  late Box<Task> _taskBox;
  late Box<FocusSession> _sessionBox;

  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(TaskAdapter());
    Hive.registerAdapter(FocusSessionAdapter());
    _taskBox = await Hive.openBox<Task>(_taskBoxName);
    _sessionBox = await Hive.openBox<FocusSession>(_sessionBoxName);
    _cleanOldTasks();
  }

  void _cleanOldTasks() {
    final todayKey = TimeFormatter.getTodayKey();
    final keysToRemove = <dynamic>[];
    for (var key in _taskBox.keys) {
      final task = _taskBox.get(key);
      if (task != null && task.dateKey != todayKey) {
        keysToRemove.add(key);
      }
    }
    for (var key in keysToRemove) {
      _taskBox.delete(key);
    }
  }

  List<Task> getTodayTasks() {
    final todayKey = TimeFormatter.getTodayKey();
    return _taskBox.values.where((task) => task.dateKey == todayKey).toList()
      ..sort((a, b) {
        if (a.completed != b.completed) {
          return a.completed ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  Future<void> addTask(Task task) async {
    await _taskBox.put(task.id, task);
  }

  Future<void> updateTask(Task task) async {
    await _taskBox.put(task.id, task);
  }

  Future<void> deleteTask(String taskId) async {
    await _taskBox.delete(taskId);
  }

  Future<void> completeTask(String taskId) async {
    final task = _taskBox.get(taskId);
    if (task != null) {
      await _taskBox.put(taskId, task.copyWith(completed: true));
    }
  }

  List<Task> getIncompleteTasks() {
    return getTodayTasks().where((task) => !task.completed).toList();
  }

  Future<void> addSession(FocusSession session) async {
    await _sessionBox.put(session.id, session);
  }

  List<FocusSession> getSessionsByDate(String dateKey) {
    return _sessionBox.values
        .where((session) => session.dateKey == dateKey && session.type == 'focus')
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<FocusSession> getSessionsForWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final List<FocusSession> sessions = [];
    for (int i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      sessions.addAll(getSessionsByDate(dateKey));
    }
    return sessions;
  }

  int getTodayTotalMinutes() {
    final todayKey = TimeFormatter.getTodayKey();
    return getSessionsByDate(todayKey)
        .fold(0, (sum, session) => sum + (session.duration ~/ 60));
  }

  int getTodayCompletedPomodoros() {
    final todayKey = TimeFormatter.getTodayKey();
    return getSessionsByDate(todayKey).length;
  }

  Map<String, int> getTodaySubjectMinutes() {
    final todayKey = TimeFormatter.getTodayKey();
    final sessions = getSessionsByDate(todayKey);
    final Map<String, int> subjectMinutes = {};
    for (final session in sessions) {
      subjectMinutes[session.subject] =
          (subjectMinutes[session.subject] ?? 0) + (session.duration ~/ 60);
    }
    return subjectMinutes;
  }

  List<FocusSession> getRecentSessions({int limit = 10}) {
    final allSessions = _sessionBox.values
        .where((session) => session.type == 'focus')
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return allSessions.take(limit).toList();
  }
}
