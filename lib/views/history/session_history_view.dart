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
          ? const Center(child: Text('暂无专注记录'))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
    final minutes = session.duration ~/ 60;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      color: dark ? AppColors.cardDark : AppColors.cardLight,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.getSubjectColor(
            session.subject,
          ).withValues(alpha: .14),
          child: Text(
            session.subject.characters.first,
            style: TextStyle(color: AppColors.getSubjectColor(session.subject)),
          ),
        ),
        title: Text(
          session.taskTitle?.trim().isNotEmpty == true
              ? session.taskTitle!
              : '自由专注',
        ),
        subtitle: Text(
          '${DateFormat('yyyy年M月d日 HH:mm').format(start)} · ${session.subject}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$minutes 分钟'),
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
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('记录已删除')));
    }
  }
}
