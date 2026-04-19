import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/task.dart';
import '../data/repositories/task_repository.dart';
import '../core/utils/time_formatter.dart';
import 'timer_provider.dart';

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  return TasksNotifier(taskRepo);
});

class TasksNotifier extends StateNotifier<List<Task>> {
  final TaskRepository _taskRepo;

  TasksNotifier(this._taskRepo) : super([]) {
    _loadTasks();
  }

  void _loadTasks() {
    state = _taskRepo.getTodayTasks();
  }

  Future<void> addTask(String title, String subject) async {
    final task = Task(
      id: const Uuid().v4(),
      title: title,
      subject: subject,
      completed: false,
      dateKey: TimeFormatter.getTodayKey(),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _taskRepo.addTask(task);
    _loadTasks();
  }

  Future<void> completeTask(String taskId) async {
    await _taskRepo.completeTask(taskId);
    _loadTasks();
  }

  Future<void> deleteTask(String taskId) async {
    await _taskRepo.deleteTask(taskId);
    _loadTasks();
  }

  Future<void> updateTask(Task task) async {
    await _taskRepo.updateTask(task);
    _loadTasks();
  }

  void refresh() {
    _loadTasks();
  }

  List<Task> get incompleteTasks => state.where((t) => !t.completed).toList();
  List<Task> get completedTasks => state.where((t) => t.completed).toList();
}
