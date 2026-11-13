import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_bottom_sheet.dart';
import '../../providers/daily_goal_provider.dart';
import '../../providers/stats_provider.dart';
import '../../providers/task_provider.dart';
import '../../providers/timer_provider.dart';
import '../../data/models/task.dart';
import 'widgets/daily_goal_card.dart';
import 'widgets/month_calendar.dart';
import 'widgets/task_card.dart';
import 'widgets/add_task_sheet.dart';

class PlanView extends ConsumerStatefulWidget {
  const PlanView({super.key});
  @override
  ConsumerState<PlanView> createState() => _PlanViewState();
}

class _PlanViewState extends ConsumerState<PlanView> {
  static const _weekdayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  /// FAB 悬浮在页面底部之上，滚动内容需要让出它的实际占位：
  /// `kFloatingActionButtonMargin`(底边留白) + FAB 默认直径 56 + 视觉间隔，
  /// 而不是凭感觉写一个 110。
  static const double _fabSize = 56;

  /// 尾部安全距离：FAB 占位 + 与最后一张卡片的间隔。
  static const double _tailClearance =
      kFloatingActionButtonMargin + _fabSize + 24;

  DateTime _dayOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  String _dateTitle(DateTime date) {
    final today = _dayOnly(DateTime.now());
    final day = _dayOnly(date);
    final diff = day.difference(today).inDays;
    final weekday = _weekdayNames[date.weekday - 1];
    final label = switch (diff) {
      0 => '今天',
      1 => '明天',
      -1 => '昨天',
      _ => '${date.month}月${date.day}日',
    };
    return '$label · $weekday';
  }

  String _monthKeyOf(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}';

  void _showTaskSheet({Task? task}) {
    final selected = ref.read(selectedPlanDateProvider);
    showAdaptiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => AddTaskSheet(
        task: task,
        initialDate: selected,
        onSave: (tasks) {
          final notifier = ref.read(tasksProvider.notifier);
          if (task == null) {
            for (final value in tasks) {
              notifier.addTask(
                value.title,
                value.subject,
                dateKey: value.dateKey,
                priority: value.priority,
                note: value.note,
                estimatedPomodoros: value.estimatedPomodoros,
              );
            }
          } else {
            notifier.updateTask(tasks.first);
          }
        },
      ),
    );
  }

  void _selectDate(DateTime date) {
    ref.read(selectedPlanDateProvider.notifier).state = _dayOnly(date);
    ref.read(calendarMonthProvider.notifier).state = _monthKeyOf(date);
  }

  void _start(Task task) {
    ref.read(timerProvider.notifier).selectTask(task);
    ref.read(timerProvider.notifier).startTimer(task: task);
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(tasksProvider);
    final selected = ref.watch(selectedPlanDateProvider);
    final markedDates = ref.watch(monthTaskDateKeysProvider);
    // 监听统计失效计数：专注会话落库后据此刷新计数（原 ref.read 非响应式，计数停留在旧值）。
    ref.watch(statsRefreshProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final open = tasks.where((t) => !t.completed).toList();
    final done = tasks.where((t) => t.completed).toList();
    // 一次遍历会话得到 taskId→专注数映射，避免逐卡全扫会话（O(tasks×sessions)）。
    final focusCounts = ref
        .watch(taskRepositoryProvider)
        .getFocusCountByTaskId();

    Widget card(Task task) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: task.completed ? null : () => _start(task),
        child: TaskCard(
          task: task,
          actualPomodoros: focusCounts[task.id] ?? 0,
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
                padding: const EdgeInsets.fromLTRB(20, 36, 20, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '计划',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(fontWeight: FontWeight.w300),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _selectDate(DateTime.now()),
                      icon: const Icon(Icons.today_outlined, size: 18),
                      label: const Text('今天'),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.cardDark : AppColors.cardLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: MonthCalendar(
                    selectedDate: selected,
                    markedDates: markedDates,
                    onDateSelected: _selectDate,
                    onMonthChanged: (monthKey) =>
                        ref.read(calendarMonthProvider.notifier).state =
                            monthKey,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: DailyGoalCard(date: selected),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                // 原来 Text + Spacer + Text 的 Row 在窄屏/大字体下宽度必然
                // 超出（320dp + 2.0 缩放需要 ~534dp）。Wrap 在放得下时用
                // spaceBetween 保持"左标题右计数"的观感，放不下时自动换行，
                // 不会产生 RenderFlex overflow。
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(
                      _dateTitle(selected),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      open.isEmpty ? '全部完成' : '还有 ${open.length} 项任务',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (tasks.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        size: 48,
                        color: AppColors.textSecondary.withValues(alpha: .3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '这一天还没有计划',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '点击 + 添加任务',
                        style: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: .7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (open.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
                  child: Text(
                    '已完成 ${done.length}',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => card(done[i]),
                    childCount: done.length,
                  ),
                ),
              ),
            ],
            // 尾部留白 = FAB 实际占位（见 _tailClearance），保证最后一张卡片
            // 能滚到 FAB 之上；原来写死的 110 与 FAB 尺寸/系统字体无关，在
            // 底栏被大字体撑高时不足以避让。安全区已由外层 SafeArea 扣掉。
            const SliverToBoxAdapter(child: SizedBox(height: _tailClearance)),
          ],
        ),
      ),
    );
  }
}
