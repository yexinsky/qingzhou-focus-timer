import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
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
  void _showAddTaskSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AddTaskSheet(
        onAdd: (title, subject) {
          ref.read(tasksProvider.notifier).addTask(title, subject);
        },
      ),
    );
  }

  void _startFocusWithTask(Task task) {
    ref.read(timerProvider.notifier).selectTask(task);
    ref.read(timerProvider.notifier).startTimer(task: task);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final incompleteTasks = tasks.where((t) => !t.completed).toList();
    final completedTasks = tasks.where((t) => t.completed).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '今日规划',
                          style:
                              Theme.of(context).textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.w300,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '还有 ${incompleteTasks.length} 项任务',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: _showAddTaskSheet,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.primaryDark
                              : AppColors.primaryLight,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          PhosphorIcons.plus(PhosphorIconsStyle.regular),
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (incompleteTasks.isEmpty && completedTasks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(),
              )
            else ...[
              if (incompleteTasks.isNotEmpty)
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = incompleteTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: GestureDetector(
                            onTap: () => _startFocusWithTask(task),
                            child: TaskCard(
                              task: task,
                              onComplete: () => ref
                                  .read(tasksProvider.notifier)
                                  .completeTask(task.id),
                              onDelete: () => ref
                                  .read(tasksProvider.notifier)
                                  .deleteTask(task.id),
                            ),
                          ),
                        );
                      },
                      childCount: incompleteTasks.length,
                    ),
                  ),
                ),
              if (completedTasks.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                    child: Text(
                      '已完成',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final task = completedTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: TaskCard(
                            task: task,
                            onComplete: () {},
                            onDelete: () => ref
                                .read(tasksProvider.notifier)
                                .deleteTask(task.id),
                          ),
                        );
                      },
                      childCount: completedTasks.length,
                    ),
                  ),
                ),
              ],
            ],
            const SliverToBoxAdapter(
              child: SizedBox(height: 120),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            PhosphorIcons.calendarBlank(PhosphorIconsStyle.regular),
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '今天还没有计划',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击右上角 + 添加任务',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}
