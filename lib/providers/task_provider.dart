import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/task.dart';
import '../data/repositories/task_repository.dart';
import 'stats_provider.dart';
import 'timer_provider.dart';

final selectedPlanDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  final repo = ref.watch(taskRepositoryProvider);
  final selectedDate = ref.watch(selectedPlanDateProvider);
  return TasksNotifier(
    repo,
    selectedDate,
    onChanged: () {
      ref.read(statsRefreshProvider.notifier).state++;
    },
  );
});

class TasksNotifier extends StateNotifier<List<Task>> {
  final TaskRepository _taskRepo;
  final void Function()? _onChanged;
  final DateTime selectedDate;
  TasksNotifier(this._taskRepo, this.selectedDate, {void Function()? onChanged})
    : _onChanged = onChanged,
      super([]) {
    _loadTasks();
  }

  String get selectedDateKey => dateKey(selectedDate);
  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  void _loadTasks() => state = _taskRepo.getTasksByDate(selectedDateKey);

  Future<void> addTask(
    String title,
    String subject, {
    String? dateKey,
    int priority = 1,
    String note = '',
    int estimatedPomodoros = 1,
  }) async {
    await _taskRepo.addTask(
      Task(
        id: const Uuid().v4(),
        title: title,
        subject: subject,
        completed: false,
        dateKey: dateKey ?? selectedDateKey,
        createdAt: DateTime.now().millisecondsSinceEpoch,
        priority: priority,
        note: note,
        estimatedPomodoros: estimatedPomodoros,
      ),
    );
    _changed();
  }

  Future<void> completeTask(String id) async {
    await _taskRepo.completeTask(id);
    _changed();
  }

  Future<void> deleteTask(String id) async {
    await _taskRepo.deleteTask(id);
    _changed();
  }

  Future<void> updateTask(Task task) async {
    await _taskRepo.updateTask(task);
    _changed();
  }

  Future<void> postponeToTomorrow(Task task) async {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    await _taskRepo.postponeTask(task.id, dateKey(tomorrow));
    _changed();
  }

  int focusCount(String taskId) => _taskRepo.getTaskFocusCount(taskId);
  void refresh() => _loadTasks();
  void _changed() {
    _loadTasks();
    _onChanged?.call();
  }

  List<Task> get incompleteTasks => state.where((t) => !t.completed).toList();
  List<Task> get completedTasks => state.where((t) => t.completed).toList();
}
