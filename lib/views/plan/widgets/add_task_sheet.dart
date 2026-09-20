import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/task.dart';
import '../../../providers/subject_provider.dart';
import '../../widgets/subject_manage_sheet.dart';
import 'month_calendar.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  final Task? task;
  final DateTime initialDate;
  final ValueChanged<List<Task>> onSave;
  const AddTaskSheet({
    super.key,
    this.task,
    required this.initialDate,
    required this.onSave,
  });
  @override
  ConsumerState<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends ConsumerState<AddTaskSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late String _subject;
  late DateTime _date;
  DateTime? _rangeEnd;
  late int _priority;
  late int _estimated;

  @override
  void initState() {
    super.initState();
    final task = widget.task;
    final subjects = ref.read(subjectsProvider).map((s) => s.name).toList();
    _title = TextEditingController(text: task?.title ?? '');
    _note = TextEditingController(text: task?.note ?? '');
    final fallback = subjects.isNotEmpty ? subjects.first : '其他';
    _subject = task?.subject ?? (subjects.contains('其他') ? '其他' : fallback);
    _date = task == null ? widget.initialDate : DateTime.parse(task.dateKey);
    _priority = task?.priority ?? 1;
    _estimated = task?.estimatedPomodoros ?? 1;
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _md(DateTime d) => '${d.month}月${d.day}日';

  /// 点击日历日期：新增时第一次点选起点、第二次点选终点（自动纠正先后），
  /// 已有终点或编辑已有任务时回到单日选择。
  void _onCalendarDate(DateTime d) {
    setState(() {
      if (widget.task != null) {
        _date = d;
        return;
      }
      final day = DateTime(d.year, d.month, d.day);
      if (_rangeEnd != null) {
        _rangeEnd = null;
        _date = day;
      } else if (day == _date) {
        return;
      } else if (day.isBefore(_date)) {
        _rangeEnd = _date;
        _date = day;
      } else {
        _rangeEnd = day;
      }
    });
  }

  void _submit() {
    if (_title.text.trim().isEmpty) return;
    final old = widget.task;
    final end = old == null ? _rangeEnd : null;
    final days = end == null
        ? [_date]
        : [
            for (
              var d = DateTime(_date.year, _date.month, _date.day);
              !d.isAfter(DateTime(end.year, end.month, end.day));
              d = d.add(const Duration(days: 1))
            )
              d,
          ];
    widget.onSave([
      for (final date in days)
        Task(
          id: old?.id ?? '',
          title: _title.text.trim(),
          subject: _subject,
          completed: old?.completed ?? false,
          dateKey: _key(date),
          createdAt: old?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
          priority: _priority,
          note: _note.text.trim(),
          estimatedPomodoros: _estimated,
        ),
    ]);
    Navigator.pop(context);
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
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.task == null ? '添加任务' : '编辑任务',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: widget.task == null,
              decoration: const InputDecoration(
                labelText: '任务名称',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: '备注（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('学科'),
                const Spacer(),
                InkWell(
                  onTap: () => SubjectManageSheet.show(context),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune,
                          size: 16,
                          color: AppColors.textSecondary.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '管理',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary.withValues(
                                  alpha: 0.8,
                                ),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ref
                  .watch(subjectsProvider)
                  .map(
                    (s) => ChoiceChip(
                      label: Text(s.name),
                      selected: _subject == s.name,
                      onSelected: (_) => setState(() => _subject = s.name),
                      selectedColor: s.color.withValues(alpha: .3),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Text('日期', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            MonthCalendar(
              selectedDate: _date,
              rangeEnd: widget.task == null ? _rangeEnd : null,
              showMarks: false,
              onDateSelected: _onCalendarDate,
            ),
            if (widget.task == null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _rangeEnd == null
                          ? '提示：再点选一天可作为结束日期，批量添加到多天'
                          : '将添加到 ${_md(_date)} 至 ${_md(_rangeEnd!)} · 共 ${_rangeEnd!.difference(_date).inDays + 1} 天',
                      style: TextStyle(
                        fontSize: 12,
                        color: _rangeEnd == null
                            ? AppColors.textSecondary
                            : (dark
                                  ? AppColors.primaryDark
                                  : AppColors.primaryLight),
                      ),
                    ),
                  ),
                  if (_rangeEnd != null)
                    TextButton(
                      onPressed: () => setState(() => _rangeEnd = null),
                      child: const Text('仅当天'),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _priority,
                    decoration: const InputDecoration(
                      labelText: '优先级',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('低')),
                      DropdownMenuItem(value: 1, child: Text('普通')),
                      DropdownMenuItem(value: 2, child: Text('高')),
                    ],
                    onChanged: (v) => setState(() => _priority = v ?? 1),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('预计专注段数'),
                const Spacer(),
                IconButton(
                  onPressed: _estimated > 1
                      ? () => setState(() => _estimated--)
                      : null,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text('$_estimated'),
                IconButton(
                  onPressed: () => setState(() => _estimated++),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: dark
                      ? AppColors.primaryDark
                      : AppColors.primaryLight,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _submit,
                child: Text(
                  widget.task == null
                      ? _rangeEnd == null
                            ? '添加'
                            : '添加到 ${_rangeEnd!.difference(_date).inDays + 1} 天'
                      : '保存',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
