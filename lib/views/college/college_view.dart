import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'discipline_pane.dart';
import 'ranking_pane.dart';

/// 院校 tab 顶部分段：排名 / 专业代码；切换 tab 后仍保留所选分段。
final collegeSegmentProvider = StateProvider<String>((ref) => 'ranking');

class CollegeView extends ConsumerWidget {
  const CollegeView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(collegeSegmentProvider);
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 42, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '院校',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ranking', label: Text('排名')),
                      ButtonSegment(value: 'codes', label: Text('专业代码')),
                    ],
                    selected: {segment},
                    onSelectionChanged: (selection) =>
                        ref.read(collegeSegmentProvider.notifier).state =
                            selection.first,
                  ),
                ],
              ),
            ),
            Expanded(
              child: segment == 'codes'
                  ? const DisciplinePane()
                  : const RankingPane(),
            ),
          ],
        ),
      ),
    );
  }
}
