import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/college_preference_provider.dart';
import 'discipline_pane.dart';
import 'goal_pane.dart';
import 'ranking_pane.dart';

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
                      ButtonSegment(value: 'goals', label: Text('目标')),
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
              child: switch (segment) {
                'codes' => const DisciplinePane(),
                'goals' => const GoalPane(),
                _ => const RankingPane(),
              },
            ),
          ],
        ),
      ),
    );
  }
}
