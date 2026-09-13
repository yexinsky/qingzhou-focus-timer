import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/task.dart';
import '../../../providers/subject_provider.dart';
import '../../widgets/subject_manage_sheet.dart';

class AddTaskSheet extends ConsumerStatefulWidget {
  final Task? task;
  final DateTime initialDate;
  final ValueChanged<Task> onSave;
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
  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (value != null) setState(() => _date = value);
  }

  void _submit() {
    if (_title.text.trim().isEmpty) return;
    final old = widget.task;
    widget.onSave(
      Task(
        id: old?.id ?? '',
        title: _title.text.trim(),
        subject: _subject,
        completed: old?.completed ?? false,
        dateKey: _key(_date),
        createdAt: old?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
        priority: _priority,
        note: _note.text.trim(),
        estimatedPomodoros: _estimated,
      ),
    );
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
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text('${_date.month}月${_date.day}日'),
                  ),
                ),
                const SizedBox(width: 12),
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
                const Text('预计番茄数'),
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
              child: ElevatedButton(
                onPressed: _submit,
                child: Text(widget.task == null ? '添加' : '保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
