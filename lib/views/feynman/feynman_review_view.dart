import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/feynman_provider.dart';

class FeynmanReviewView extends ConsumerWidget {
  const FeynmanReviewView({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final u = ref.watch(feynmanProvider);
    if (u == null) return const Scaffold(body: Center(child: Text('没有进行中的学习')));
    final n = ref.read(feynmanProvider.notifier);
    Future<void> done(String outcome) async {
      await n.complete(outcome: outcome);
      if (c.mounted) c.go('/feynman/heatmap');
    }

    return Scaffold(
      appBar: AppBar(title: const Text('学习复盘')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(u.title, style: Theme.of(c).textTheme.headlineSmall),
          const SizedBox(height: 12),
          const Text('现在能不看资料完整讲清楚吗？'),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => done(FeynmanNotifier.outcomeExplained),
            icon: const Icon(Icons.check_circle),
            label: const Text('已经讲清楚'),
          ),
          OutlinedButton.icon(
            onPressed: () => done(FeynmanNotifier.outcomeBlindSpot),
            icon: const Icon(Icons.warning_amber),
            label: const Text('仍有盲点'),
          ),
          OutlinedButton.icon(
            onPressed: () => done(FeynmanNotifier.outcomeReread),
            icon: const Icon(Icons.menu_book),
            label: const Text('需要返回重读'),
          ),
          const SizedBox(height: 20),
          const Text('若实际输出不足输入时长的 50%，本次会自动标记为未达标并建议重读。'),
        ],
      ),
    );
  }
}
