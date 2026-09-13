import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_bottom_sheet.dart';
import '../../providers/task_provider.dart';
import '../../providers/timer_provider.dart';
import '../../data/models/task.dart';
import 'widgets/task_card.dart';
import 'widgets/add_task_sheet.dart';

class PlanView extends ConsumerStatefulWidget {
  const PlanView({super.key});
  @override
  ConsumerState<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends ConsumerState<PlanView> {
  DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);
  String _dateTitle(DateTime date) {
    final today = _dayOnly(DateTime.now());
    final day = _dayOnly(date);
    if (day == today) return '今日规划';
    if (day == today.add(const Duration(days: 1))) return '明日规划';
    return '${date.month}月${date.day}日规划';
  }

  void _showTaskSheet({Task? task}) {
    final selected = ref.read(selectedPlanDateProvider);
    showAdaptiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTaskSheet(
        task: task,
        initialDate: selected,
        onSave: (value) {
          final notifier = ref.read(tasksProvider.notifier);
          if (task == null) {
            notifier.addTask(
              value.title,
              value.subject,
              dateKey: value.dateKey,
              priority: value.priority,
              note: value.note,
              estimatedPomodoros: value.estimatedPomodoros,
            );
          } else {
            notifier.updateTask(value);
          }
        },
      ),
    );
  }

  void _selectPreset(int offset) =>
      ref.read(selectedPlanDateProvider.notifier).state = _dayOnly(
        DateTime.now(),
      ).add(Duration(days: offset));
  Future<void> _pickDate() async {
    final current = ref.read(selectedPlanDateProvider);
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null)
      ref.read(selectedPlanDateProvider.notifier).state = picked;
  }

  void _start(Task task) {
    ref.read(timerProvider.notifier).selectTask(task);
    ref.read(timerProvider.notifier).startTimer(task: task);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final selected = ref.watch(selectedPlanDateProvider);
    final open = tasks.where((t) => !t.completed).toList();
    final done = tasks.where((t) => t.completed).toList();
    Widget card(Task task) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: task.completed ? null : () => _start(task),
        child: TaskCard(
          task: task,
          actualPomodoros: ref.read(tasksProvider.notifier).focusCount(task.id),
          onComplete: () =>
              ref.read(tasksProvider.notifier).completeTask(task.id),
          onDelete: () => ref.read(tasksProvider.notifier).deleteTask(task.id),
          onEdit: () => _showTaskSheet(task: task),
          onPostpone: () =>
              ref.read(tasksProvider.notifier).postponeToTomorrow(task),
        ),
      ),
    );
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskSheet(),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 42, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _dateTitle(selected),
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w300),
                          ),
                        ),
                        IconButton(
                          onPressed: _pickDate,
                          tooltip: '选择日期',
                          icon: Icon(Icons.calendar_today_outlined),
                        ),
                      ],
                    ),
                    Text(
                      '还有 ${open.length} 项任务',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('今天')),
                        ButtonSegment(value: 1, label: Text('明天')),
                        ButtonSegment(value: 2, label: Text('选日期')),
                      ],
                      selected: {
                        _dayOnly(selected) == _dayOnly(DateTime.now())
                            ? 0
                            : _dayOnly(selected) ==
                                  _dayOnly(
                                    DateTime.now(),
                                  ).add(const Duration(days: 1))
                            ? 1
                            : 2,
                      },
                      onSelectionChanged: (s) {
                        final v = s.first;
                        if (v < 2)
                          _selectPreset(v);
                        else
                          _pickDate();
                      },
                    ),
                  ],
                ),
              ),
            ),
            if (tasks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 60,
                        color: AppColors.textSecondary.withValues(alpha: .3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '这一天还没有计划',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 6),
                      const Text('点击 + 添加任务'),
                    ],
                  ),
                ),
              ),
            if (open.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => card(open[i]),
                    childCount: open.length,
                  ),
                ),
              ),
            if (done.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
                  child: Text(
                    '已完成 ${done.length}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => card(done[i]),
                    childCount: done.length,
                  ),
                ),
              ),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 110)),
          ],
        ),
      ),
    );
  }
}
