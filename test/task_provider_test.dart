import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/task.dart';
import 'package:qingzhou_focus/providers/task_provider.dart';

import 'helpers/test_repositories.dart';

void main() {
  late TestTaskRepository repository;
  late int changeCount;
  late TasksNotifier notifier;

  setUp(() {
    repository = TestTaskRepository();
    changeCount = 0;
    notifier = TasksNotifier(
      repository,
      DateTime(2026, 9, 6),
      onChanged: () => changeCount++,
    );
  });

  tearDown(() => notifier.dispose());

  Task task(String id, {bool completed = false, int createdAt = 1}) => Task(
    id: id,
    title: '任务 $id',
    subject: '数学',
    completed: completed,
    dateKey: '2026-09-06',
    createdAt: createdAt,
  );

  test('loads repository tasks on construction', () {
    notifier.dispose();
    repository.tasks['a'] = task('a');
    notifier = TasksNotifier(repository, DateTime(2026, 9, 6));
    expect(notifier.state.single.id, 'a');
  });

  test('complete updates state, derived lists and invokes callback', () async {
    repository.tasks['a'] = task('a');
    notifier.refresh();
    await notifier.completeTask('a');
    expect(notifier.incompleteTasks, isEmpty);
    expect(notifier.completedTasks.single.id, 'a');
    expect(changeCount, 1);
  });

  test('update and delete refresh state', () async {
    repository.tasks['a'] = task('a');
    notifier.refresh();
    await notifier.updateTask(task('a').copyWith(title: '新标题'));
    expect(notifier.state.single.title, '新标题');
    await notifier.deleteTask('a');
    expect(notifier.state, isEmpty);
    expect(changeCount, 2);
  });

  test('sorting keeps incomplete first and newest first', () {
    repository.tasks.addAll({
      'old': task('old', createdAt: 1),
      'done': task('done', completed: true, createdAt: 3),
      'new': task('new', createdAt: 2),
    });
    notifier.refresh();
    expect(notifier.state.map((e) => e.id), ['new', 'old', 'done']);
  });
}
