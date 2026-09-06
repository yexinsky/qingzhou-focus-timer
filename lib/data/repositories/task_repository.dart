import 'package:hive_flutter/hive_flutter.dart';
import '../models/task.dart';
import '../models/focus_session.dart';
import '../../core/utils/time_formatter.dart';

class TaskRepository {
  TaskRepository({String? storagePath}) : _storagePath = storagePath;

  final String? _storagePath;
  static const String _taskBoxName = 'tasks';
  static const String _sessionBoxName = 'sessions';

  late Box<Task> _taskBox;
  late Box<FocusSession> _sessionBox;

  Future<void> init() async {
    if (_storagePath == null) {
      await Hive.initFlutter();
    } else {
      Hive.init(_storagePath);
    }
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TaskAdapter());
    if (!Hive.isAdapterRegistered(1))
      Hive.registerAdapter(FocusSessionAdapter());
    _taskBox = await Hive.openBox<Task>(_taskBoxName);
    _sessionBox = await Hive.openBox<FocusSession>(_sessionBoxName);
  }

  List<Task> getTodayTasks() {
    final todayKey = TimeFormatter.getTodayKey();
    return _taskBox.values.where((task) => task.dateKey == todayKey).toList()
      ..sort((a, b) {
        if (a.completed != b.completed) return a.completed ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  List<Task> getAllTasks() =>
      _taskBox.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  List<Task> getTasksByDate(String dateKey) =>
      _taskBox.values.where((task) => task.dateKey == dateKey).toList()
        ..sort((a, b) {
          if (a.completed != b.completed) return a.completed ? 1 : -1;
          if (a.priority != b.priority) return b.priority.compareTo(a.priority);
          return b.createdAt.compareTo(a.createdAt);
        });

  Future<void> postponeTask(String taskId, String dateKey) async {
    final task = _taskBox.get(taskId);
    if (task != null) {
      await _taskBox.put(taskId, task.copyWith(dateKey: dateKey));
    }
  }

  int getTaskFocusCount(String taskId) => _sessionBox.values
      .where((session) => session.type == 'focus' && session.taskId == taskId)
      .length;

  Future<void> addTask(Task task) => _taskBox.put(task.id, task);
  Future<void> updateTask(Task task) => _taskBox.put(task.id, task);
  Future<void> deleteTask(String taskId) => _taskBox.delete(taskId);

  Future<void> completeTask(String taskId) async {
    final task = _taskBox.get(taskId);
    if (task != null)
      await _taskBox.put(taskId, task.copyWith(completed: true));
  }

  List<Task> getIncompleteTasks() =>
      getTodayTasks().where((task) => !task.completed).toList();

  Future<void> addSession(FocusSession session) =>
      _sessionBox.put(session.id, session);

  List<FocusSession> getAllSessions() =>
      _sessionBox.values.toList()
        ..sort((a, b) => b.startTime.compareTo(a.startTime));

  Future<void> deleteSession(String sessionId) => _sessionBox.delete(sessionId);

  Future<void> replaceAllData({
    required Iterable<Task> tasks,
    required Iterable<FocusSession> sessions,
  }) async {
    await _taskBox.clear();
    await _sessionBox.clear();
    await _taskBox.putAll({for (final task in tasks) task.id: task});
    await _sessionBox.putAll({
      for (final session in sessions) session.id: session,
    });
  }

  Future<void> clearAllData() async {
    await _taskBox.clear();
    await _sessionBox.clear();
  }

  Future<void> close() async {
    await _taskBox.close();
    await _sessionBox.close();
  }

  List<FocusSession> getSessionsByDate(String dateKey) {
    return _sessionBox.values
        .where(
          (session) => session.dateKey == dateKey && session.type == 'focus',
        )
        .toList()
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
  }

  List<FocusSession> getSessionsForWeek() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sessions = <FocusSession>[];
    for (var i = 0; i < 7; i++) {
      final date = monday.add(Duration(days: i));
      final dateKey =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      sessions.addAll(getSessionsByDate(dateKey));
    }
    return sessions;
  }

  int getTodayTotalMinutes() => getSessionsByDate(
    TimeFormatter.getTodayKey(),
  ).fold(0, (sum, session) => sum + (session.duration ~/ 60));

  int getTodayCompletedPomodoros() =>
      getSessionsByDate(TimeFormatter.getTodayKey()).length;

  Map<String, int> getTodaySubjectMinutes() {
    final subjectMinutes = <String, int>{};
    for (final session in getSessionsByDate(TimeFormatter.getTodayKey())) {
      subjectMinutes[session.subject] =
          (subjectMinutes[session.subject] ?? 0) + (session.duration ~/ 60);
    }
    return subjectMinutes;
  }

  List<FocusSession> getRecentSessions({int limit = 10}) => getAllSessions()
      .where((session) => session.type == 'focus')
      .take(limit)
      .toList();
}
