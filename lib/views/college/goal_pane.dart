import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_bottom_sheet.dart';
import '../../data/models/college_preference.dart';
import '../../data/models/university.dart';
import '../../providers/college_preference_provider.dart';
import '../../providers/university_provider.dart';

/// 目标面板：目标院校、考研倒计时与自定义里程碑。
class GoalPane extends ConsumerWidget {
  const GoalPane({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(collegePreferenceProvider);
    final countdown = ref.watch(examCountdownProvider);
    final notifier = ref.read(collegePreferenceProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 110),
      children: [
        _TargetCard(
          target: preferences.target,
          onPick: () => _showTargetPicker(context, ref),
          onClear: preferences.target == null
              ? null
              : () => notifier.setTarget(null),
        ),
        const SizedBox(height: 12),
        _CountdownCard(
          countdown: countdown,
          onPickDate: (date) => notifier.setExamDate(date),
        ),
        const SizedBox(height: 12),
        _MilestoneCard(
          milestones: preferences.milestones,
          onAdd: (title, date) => notifier.addMilestone(title, date),
          onToggle: notifier.toggleMilestone,
          onRemove: notifier.removeMilestone,
        ),
      ],
    );
  }

  void _showTargetPicker(BuildContext context, WidgetRef ref) {
    final universities =
        ref.read(universityRankingProvider).valueOrNull?.universities ??
        const [];
    final preferences = ref.read(collegePreferenceProvider);
    showAdaptiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _TargetPickerSheet(
        universities: universities,
        favorites: preferences.favorites.toSet(),
        currentTarget: preferences.target,
        onSelect: (name) {
          ref.read(collegePreferenceProvider.notifier).setTarget(name);
          Navigator.of(sheetContext).pop();
        },
        onClear: () {
          ref.read(collegePreferenceProvider.notifier).setTarget(null);
          Navigator.of(sheetContext).pop();
        },
      ),
    );
  }
}

class _TargetCard extends StatelessWidget {
  const _TargetCard({
    required this.target,
    required this.onPick,
    required this.onClear,
  });

  final String? target;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return _card(
      dark: dark,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '目标院校',
                  style: TextStyle(
                    fontSize: 12,
                    color: dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  target ?? '未设置',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: target == null
                        ? (dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary)
                        : null,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  target == null ? '设置后专注页顶部会显示目标提醒' : '专注页顶部已显示目标提醒',
                  style: TextStyle(
                    fontSize: 11,
                    color: dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onPick,
            child: Text(target == null ? '选择' : '更换'),
          ),
          if (target != null)
            TextButton(onPressed: onClear, child: const Text('清除')),
        ],
      ),
    );
  }
}

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({required this.countdown, required this.onPickDate});

  final ExamCountdown? countdown;
  final ValueChanged<DateTime?> onPickDate;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final countdown = this.countdown;
    final now = DateTime.now();
    return _card(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '考研倒计时',
                style: TextStyle(
                  fontSize: 12,
                  color: dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (countdown != null && !countdown.isAuto)
                TextButton(
                  onPressed: () => onPickDate(null),
                  child: const Text('恢复自动'),
                ),
              IconButton(
                tooltip: '调整考试日期',
                onPressed: countdown == null
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: countdown.date.isBefore(now)
                              ? now
                              : countdown.date,
                          firstDate: now,
                          lastDate: DateTime(now.year + 3, 12, 31),
                        );
                        if (picked != null) onPickDate(picked);
                      },
                icon: const Icon(Icons.edit_outlined, size: 18),
                color: AppColors.textSecondary,
              ),
            ],
          ),
          if (countdown == null)
            const Text(
              '—',
              style: TextStyle(fontSize: 40, fontWeight: FontWeight.w300),
            )
          else if (countdown.daysRemaining < 0) ...[
            Text(
              '初试已开始',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w300,
                color: dark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _caption(countdown),
              style: TextStyle(
                fontSize: 12,
                color: dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ] else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${countdown.daysRemaining}',
                  style: TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w300,
                    height: 1.0,
                    color: dark
                        ? AppColors.primaryDark
                        : AppColors.primaryLight,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '天',
                    style: TextStyle(
                      fontSize: 14,
                      color: dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _caption(countdown),
              style: TextStyle(
                fontSize: 12,
                color: dark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _caption(ExamCountdown countdown) {
    final date = countdown.date;
    final mode = countdown.isAuto ? '按 12 月倒数第二个周六自动推算' : '自定义日期';
    return '距 ${date.year} 考研初试 · ${date.month}月${date.day}日 · $mode';
  }
}

class _MilestoneCard extends StatelessWidget {
  const _MilestoneCard({
    required this.milestones,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
  });

  final List<ExamMilestone> milestones;
  final void Function(String title, DateTime? date) onAdd;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    // 未完成的在前；同组内有日期的按日期升序，不限日期的排最后
    final sorted = List.of(milestones)
      ..sort((a, b) {
        if (a.done != b.done) return a.done ? 1 : -1;
        if (a.date == null && b.date == null) return 0;
        if (a.date == null) return 1;
        if (b.date == null) return -1;
        return a.date!.compareTo(b.date!);
      });

    return _card(
      dark: dark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '里程碑',
                style: TextStyle(
                  fontSize: 12,
                  color: dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _showAddSheet(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('添加'),
              ),
            ],
          ),
          if (sorted.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '还没有里程碑，添加一个备考节点吧',
                style: TextStyle(
                  fontSize: 13,
                  color: dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            )
          else
            for (final milestone in sorted)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Checkbox(
                        value: milestone.done,
                        onChanged: (_) => onToggle(milestone.id),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            milestone.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              decoration: milestone.done
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: milestone.done
                                  ? (dark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary)
                                  : null,
                            ),
                          ),
                          if (milestone.date != null)
                            Text(
                              '${milestone.date!.month}月${milestone.date!.day}日',
                              style: TextStyle(
                                fontSize: 12,
                                color: dark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: '删除',
                      onPressed: () => onRemove(milestone.id),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showAdaptiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMilestoneSheet(onAdd: onAdd),
    );
  }
}

class _AddMilestoneSheet extends StatefulWidget {
  const _AddMilestoneSheet({required this.onAdd});

  final void Function(String title, DateTime? date) onAdd;

  @override
  State<_AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<_AddMilestoneSheet> {
  final _titleController = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: now,
      lastDate: DateTime(now.year + 3, 12, 31),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('添加里程碑', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '记录报名、模考、一轮复习等备考节点',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            autofocus: true,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: '里程碑名称',
              border: OutlineInputBorder(),
              counterText: '',
            ),
            onSubmitted: (_) => _add(),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_outlined, size: 16),
                label: Text(
                  _date == null ? '不限日期' : '${_date!.month}月${_date!.day}日',
                ),
              ),
              if (_date != null)
                TextButton(
                  onPressed: () => setState(() => _date = null),
                  child: const Text('清除日期'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _add, child: const Text('添加里程碑')),
          ),
        ],
      ),
    );
  }

  void _add() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    widget.onAdd(title, _date);
    Navigator.of(context).pop();
  }
}

class _TargetPickerSheet extends StatefulWidget {
  const _TargetPickerSheet({
    required this.universities,
    required this.favorites,
    required this.currentTarget,
    required this.onSelect,
    required this.onClear,
  });

  final List<University> universities;
  final Set<String> favorites;
  final String? currentTarget;
  final ValueChanged<String> onSelect;
  final VoidCallback onClear;

  @override
  State<_TargetPickerSheet> createState() => _TargetPickerSheetState();
}

class _TargetPickerSheetState extends State<_TargetPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final query = _query.trim();
    final list = query.isEmpty
        ? List.of(widget.universities)
        : widget.universities.where((u) => u.name.contains(query)).toList();
    // 收藏置顶；List.sort 不稳定，用原始榜单序号作次级键保持顺序
    final originalOrder = {
      for (var i = 0; i < list.length; i++) list[i].name: i,
    };
    list.sort((a, b) {
      final af = widget.favorites.contains(a.name) ? 0 : 1;
      final bf = widget.favorites.contains(b.name) ? 0 : 1;
      if (af != bf) return af - bf;
      return originalOrder[a.name]! - originalOrder[b.name]!;
    });

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 460),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('选择目标院校', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '设置后专注页顶部会显示目标提醒',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              TextField(
                autofocus: widget.universities.isEmpty,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: '搜索院校名称',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (widget.currentTarget != null)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: widget.onClear,
                        child: const SizedBox(
                          height: 48,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '清除目标院校',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ),
                    for (final university in list.take(80))
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => widget.onSelect(university.name),
                        child: SizedBox(
                          height: 52,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 36,
                                child: Text(
                                  university.rank,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: dark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  university.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: dark
                                        ? AppColors.textPrimaryDark
                                        : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              if (widget.favorites.contains(university.name))
                                const Icon(
                                  Icons.star_rounded,
                                  size: 18,
                                  color: Color(0xFFD9A441),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _card({required bool dark, required Widget child}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: dark ? AppColors.cardDark : AppColors.cardLight,
      borderRadius: BorderRadius.circular(12),
    ),
    child: child,
  );
}
