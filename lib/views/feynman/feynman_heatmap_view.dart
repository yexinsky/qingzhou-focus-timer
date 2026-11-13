import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/stumble_mark.dart';
import '../../providers/feynman_provider.dart';

class FeynmanHeatmapView extends ConsumerWidget {
  const FeynmanHeatmapView({super.key});
  @override
  Widget build(BuildContext c, WidgetRef ref) {
    final marks = ref.watch(stumbleMarksProvider);
    final groups = <String, List<StumbleMark>>{};
    for (final m in marks) {
      groups
          .putIfAbsent(
            m.chapter.isEmpty
                ? m.topic.isEmpty
                      ? '未分类'
                      : m.topic
                : m.chapter,
            () => [],
          )
          .add(m);
    }
    final sorted = groups.entries.toList()
      ..sort(
        (a, b) => b.value
            .fold<int>(0, (s, m) => s + m.severity)
            .compareTo(a.value.fold<int>(0, (s, m) => s + m.severity)),
      );
    return Scaffold(
      appBar: AppBar(title: const Text('知识卡点热力图')),
      body: marks.isEmpty
          ? const SafeArea(child: Center(child: Text('完成费曼讲解并记录卡点后，这里会显示热点。')))
          : ListView(
              // 底部补系统安全区，最后一张卡片不会被手势区/导航栏压住。
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.viewPaddingOf(c).bottom,
              ),
              children: [
                const Text(
                  '颜色越深，近期卡壳与严重程度越高。',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 12),
                ...sorted.map((e) {
                  final score = e.value.fold<int>(0, (s, m) => s + m.severity);
                  final unresolved = e.value.where((m) => !m.resolved).length;
                  return Card(
                    color: Colors.deepOrange.withValues(
                      alpha: (.08 + score * .04).clamp(.08, .5),
                    ),
                    child: ExpansionTile(
                      // 大字体 + 窄屏：标题/副标题按行数收缩，分数列宽固定并等比缩放，
                      // 避免 trailing 撑满整行（ListTile 会直接抛错）。
                      title: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${e.value.length} 次卡壳 · $unresolved 个未解决',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: SizedBox(
                        width: 56,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text('$score'),
                        ),
                      ),
                      children: e.value
                          .map(
                            (m) => CheckboxListTile(
                              value: m.resolved,
                              title: Text(
                                m.keyword.isEmpty ? '未命名卡点' : m.keyword,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${m.reason}${m.note.isEmpty ? '' : ' · ${m.note}'} · ${m.offsetSeconds}s',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onChanged: (v) => ref
                                  .read(feynmanProvider.notifier)
                                  .updateMark(
                                    m.copyWith(
                                      resolved: v,
                                      resolvedAt: v == true
                                          ? DateTime.now()
                                                .millisecondsSinceEpoch
                                          : null,
                                    ),
                                  ),
                            ),
                          )
                          .toList(),
                    ),
                  );
                }),
              ],
            ),
    );
  }
}
