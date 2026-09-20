import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/adaptive_bottom_sheet.dart';
import '../../../providers/daily_goal_provider.dart';

/// 每日目标卡片：显示选中日期的目标专注段数与完成进度，点按可编辑。
class DailyGoalCard extends ConsumerWidget {
  const DailyGoalCard({super.key, required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final goal = ref.watch(dailyGoalProvider(date));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.primaryDark : AppColors.primaryLight;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _showEditor(context, ref, goal),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: dark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  goal.reached ? Icons.verified_outlined : Icons.flag_outlined,
                  size: 18,
                  color: goal.reached ? AppColors.success : primary,
                ),
                const SizedBox(width: 8),
                Text(
                  '每日目标',
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  goal.reached ? '已达成' : '${goal.completed}/${goal.target} 段',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: goal.reached ? AppColors.success : primary,
                  ),
                ),
                Icon(
                  Icons.edit_outlined,
                  size: 14,
                  color: AppColors.textSecondary.withValues(alpha: .6),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: goal.progress,
                minHeight: 6,
                backgroundColor: primary.withValues(alpha: .12),
                valueColor: AlwaysStoppedAnimation(
                  goal.reached ? AppColors.success : primary,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              goal.reached
                  ? '今日目标已完成，保持节奏'
                  : '目标 ${goal.target} 个专注段 · 还差 ${goal.target - goal.completed} 段',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditor(BuildContext context, WidgetRef ref, DailyGoal goal) {
    showAdaptiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalEditorSheet(date: date, goal: goal),
    );
  }
}

class _GoalEditorSheet extends ConsumerStatefulWidget {
  const _GoalEditorSheet({required this.date, required this.goal});
  final DateTime date;
  final DailyGoal goal;

  @override
  ConsumerState<_GoalEditorSheet> createState() => _GoalEditorSheetState();
}

class _GoalEditorSheetState extends ConsumerState<_GoalEditorSheet> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.goal.target;
  }

  Future<void> _save(int? count) async {
    await setDailyGoal(ref, widget.date, count);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.primaryDark : AppColors.primaryLight;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('设置目标', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text(
            '${widget.date.month}月${widget.date.day}日 · 已完成 ${widget.goal.completed} 段',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 28),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: _value > 1 ? () => setState(() => _value--) : null,
              ),
              const SizedBox(width: 36),
              Text(
                '$_value',
                style: TextStyle(
                  fontSize: 52,
                  fontWeight: FontWeight.w200,
                  color: primary,
                ),
              ),
              const SizedBox(width: 36),
              _StepButton(
                icon: Icons.add,
                onTap: _value < 24 ? () => setState(() => _value++) : null,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text('个专注段', style: TextStyle(color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => _save(_value),
              child: const Text('保存'),
            ),
          ),
          if (widget.goal.hasCustomTarget)
            TextButton(
              onPressed: () => _save(null),
              child: const Text('恢复默认目标'),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.primaryDark : AppColors.primaryLight;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: onTap == null ? .04 : .1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: primary.withValues(alpha: onTap == null ? .3 : 1),
        ),
      ),
    );
  }
}
