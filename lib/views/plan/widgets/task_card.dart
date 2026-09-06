import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/task.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final int actualPomodoros;
  final VoidCallback onComplete;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onPostpone;
  const TaskCard({
    super.key,
    required this.task,
    required this.actualPomodoros,
    required this.onComplete,
    required this.onDelete,
    required this.onEdit,
    required this.onPostpone,
  });
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = AppColors.getSubjectColor(task.subject);
    return Dismissible(
      key: Key(task.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppColors.error,
        child: Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Opacity(
        opacity: task.completed ? .55 : 1,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: dark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: task.completed,
                activeColor: color,
                onChanged: task.completed ? null : (_) => onComplete(),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (task.priority == 2)
                          const Padding(
                            padding: EdgeInsets.only(right: 5),
                            child: Icon(
                              Icons.flag,
                              size: 16,
                              color: Colors.red,
                            ),
                          ),
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              decoration: task.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (task.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          task.note,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 8,
                      children: [
                        Text(
                          task.subject,
                          style: TextStyle(color: color, fontSize: 12),
                        ),
                        Text(
                          '$actualPomodoros/${task.estimatedPomodoros} 个番茄',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'tomorrow') onPostpone();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('编辑')),
                  PopupMenuItem(value: 'tomorrow', child: Text('延期到明天')),
                  PopupMenuItem(value: 'delete', child: Text('删除')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
