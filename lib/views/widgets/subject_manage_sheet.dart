import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/subject_provider.dart';

/// 学科管理底部弹窗：查看/删除现有学科，输入名称添加自定义学科。
/// 在「添加任务」和「按科目专注」两处入口共用。
class SubjectManageSheet extends ConsumerStatefulWidget {
  const SubjectManageSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SubjectManageSheet(),
    );
  }

  @override
  ConsumerState<SubjectManageSheet> createState() => _SubjectManageSheetState();
}

class _SubjectManageSheetState extends ConsumerState<SubjectManageSheet> {
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final changed = await ref.read(subjectsProvider.notifier).add(name);
    if (!mounted) return;
    if (changed) {
      _nameController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('「$name」已在学科列表中')),
      );
    }
  }

  Future<void> _remove(String name) async {
    await ref.read(subjectsProvider.notifier).remove(name);
  }

  @override
  Widget build(BuildContext context) {
    final subjects = ref.watch(subjectsProvider);
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
          Text('管理科目', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            '删除科目不影响历史专注记录，重新添加同名科目会恢复原色',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          if (subjects.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '还没有科目，在下方添加一个吧',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subject = subjects[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: subject.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    title: Text(subject.name),
                    trailing: IconButton(
                      onPressed: () => _remove(subject.name),
                      icon: const Icon(Icons.remove_circle_outline),
                      color: AppColors.textSecondary,
                      tooltip: '删除',
                    ),
                  );
                },
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _nameController,
                  autofocus: subjects.isEmpty,
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: '自定义科目名称',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  onSubmitted: (_) => _add(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _add,
                icon: const Icon(Icons.add),
                label: const Text('添加'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
