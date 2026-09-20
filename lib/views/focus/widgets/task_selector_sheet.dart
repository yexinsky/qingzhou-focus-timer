import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/task.dart';
import '../../../providers/ambient_sound_provider.dart';
import '../../../providers/task_provider.dart';
import '../../../providers/subject_provider.dart';
import '../../settings/ambient_sound_settings_sheet.dart';
import '../../widgets/subject_manage_sheet.dart';

class TaskSelectorSheet extends ConsumerWidget {
  final Function(Task?) onTaskSelected;
  final Function(String subject)? onSubjectSelected;

  const TaskSelectorSheet({
    super.key,
    required this.onTaskSelected,
    this.onSubjectSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(tasksProvider);
    final subjects = ref.watch(subjectsProvider);
    final incompleteTasks = tasks.where((t) => !t.completed).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      // 横屏等矮高度场景下限制弹窗高度并支持滚动，避免底部入口被裁出屏幕
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '选择专注任务',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (onSubjectSelected != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        '按科目专注',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      _ManageSubjectsButton(dark: isDark),
                    ],
                  ),
                ),
                if (subjects.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: subjects
                          .map(
                            (subject) => _SubjectChip(
                              subject: subject.name,
                              color: subject.color,
                              onTap: () {
                                onSubjectSelected!(subject.name);
                                Navigator.pop(context);
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  '今日待办',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (incompleteTasks.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.assignment_outlined,
                        size: 40,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '暂无待办任务，可按科目直接专注',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: incompleteTasks.length,
                  itemBuilder: (context, index) {
                    final task = incompleteTasks[index];
                    final subjectColor = AppColors.getSubjectColor(
                      task.subject,
                    );
                    return _TaskItem(
                      task: task,
                      subjectColor: subjectColor,
                      onTap: () {
                        onTaskSelected(task);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _FreeFocusButton(
                  onTap: () {
                    onTaskSelected(null);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _AmbientSoundEntry(),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskItem extends StatelessWidget {
  final Task task;
  final Color subjectColor;
  final VoidCallback onTap;

  const _TaskItem({
    required this.task,
    required this.subjectColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: subjectColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: subjectColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        task.subject,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: subjectColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.play_circle_outline, color: subjectColor),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManageSubjectsButton extends ConsumerWidget {
  final bool dark;

  const _ManageSubjectsButton({required this.dark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
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
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubjectChip extends StatelessWidget {
  final String subject;
  final Color color;
  final VoidCallback onTap;

  const _SubjectChip({
    required this.subject,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final subjectColor = color;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: subjectColor.withValues(alpha: 0.08),
            border: Border.all(color: subjectColor.withValues(alpha: 0.35)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: subjectColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                subject,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: subjectColor,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 氛围音快速入口：显示当前所选音频与循环模式，点按打开氛围音设置。
class _AmbientSoundEntry extends ConsumerWidget {
  const _AmbientSoundEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ambientSoundProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => AmbientSoundSettingsSheet.show(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.06),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                state.isPlaying
                    ? Icons.graphic_eq_rounded
                    : Icons.library_music_outlined,
                size: 20,
                color: primary,
              ),
              const SizedBox(width: 12),
              Text(
                '氛围音',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  state.selectedSound?.name ?? '未选择',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FreeFocusButton extends StatelessWidget {
  final VoidCallback onTap;

  const _FreeFocusButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.textSecondary.withValues(alpha: 0.2),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  '自由专注',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
