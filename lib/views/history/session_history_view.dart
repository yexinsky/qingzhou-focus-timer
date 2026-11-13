import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/focus_session.dart';
import '../../providers/data_management_provider.dart';

class SessionHistoryView extends ConsumerWidget {
  const SessionHistoryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(sessionHistoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('专注历史')),
      body: sessions.isEmpty
          ? const SafeArea(child: Center(child: Text('暂无专注记录')))
          : ListView.separated(
              // 底部补系统安全区，最后一条记录不会被手势区/导航栏压住。
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                32 + MediaQuery.viewPaddingOf(context).bottom,
              ),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _SessionCard(session: sessions[index]),
            ),
    );
  }
}

class _SessionCard extends ConsumerWidget {
  const _SessionCard({required this.session});
  final FocusSession session;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final start = DateTime.fromMillisecondsSinceEpoch(session.startTime);
    final durationLabel = session.duration < 60
        ? '${session.duration} 秒'
        : '${session.duration ~/ 60} 分钟';
    final dark = Theme.of(context).brightness == Brightness.dark;
    final subjectColor = AppColors.getSubjectColor(session.subject);
    return Card(
      elevation: 0,
      color: dark ? AppColors.cardDark : AppColors.cardLight,
      // 不再用 ListTile：它的 trailing 没有宽度弹性，窄屏 + 系统字体放大时
      // trailing 会吃掉整行并直接抛 "consumes the entire tile width"。
      // 这里改成自适应的 Row + Expanded，信息（标题 / 时间 / 学科 / 时长）一条不少，
      // 只是把时长从右侧挪到第三行，任何屏宽下都不会互相挤压。
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: subjectColor.withValues(alpha: .14),
              child: Text(
                session.subject.characters.first,
                style: TextStyle(color: subjectColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    session.taskTitle?.trim().isNotEmpty == true
                        ? session.taskTitle!
                        : '自由专注',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('yyyy年M月d日 HH:mm').format(start)} · ${session.subject}${session.isFlexible ? ' · 灵活计时' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    durationLabel,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'delete') _confirmDelete(context, ref);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Text('删除记录')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除专注记录？'),
        content: const Text('删除后统计数据会同步变化，且无法撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(dataManagementProvider.notifier).deleteSession(session.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('记录已删除')));
      }
    }
  }
}
