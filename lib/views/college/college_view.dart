import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/college_preference_provider.dart';
import 'discipline_pane.dart';
import 'goal_pane.dart';
import 'ranking_pane.dart';
import 'widgets/college_segment_bar.dart';

/// 院校页：顶部标题区 + 「排名 / 专业代码 / 目标」分段控件，下方是对应面板。
///
/// 三段式布局的关键约束：面板（各分段的内容）必须始终拿到一个可用的高度。
/// 常规竖屏下沿用「标题区 + Expanded(面板)」；横屏 / 键盘弹起 / 分屏等矮屏场景
/// 下标题区封顶且自身可滚动，避免把 Expanded 压成 0 甚至整列溢出。
class CollegeView extends ConsumerWidget {
  const CollegeView({super.key});

  /// 视口高度低于该值时按「矮屏」处理（横屏手机、键盘弹起、分屏）。
  static const double compactHeightBreakpoint = 430;

  /// 矮屏下标题区最多占视口高度的比例，其余高度全部留给面板。
  static const double headerMaxHeightRatio = 0.45;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segment = ref.watch(collegeSegmentProvider);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, viewport) {
            final compact = viewport.maxHeight < compactHeightBreakpoint;
            final pane = switch (segment) {
              'codes' => const DisciplinePane(),
              'goals' => const GoalPane(),
              _ => const RankingPane(),
            };
            final header = _CollegeHeader(segment: segment, compact: compact);
            if (!compact) {
              // 常规高度：结构与改造前一致，不引入额外滚动手势。
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  header,
                  Expanded(child: pane),
                ],
              );
            }
            // 矮屏：标题区高度封顶（最多 45%）且自身可滚动，
            // 保证面板始终拿到 ≥55% 的高度，而不是被标题区挤成 0。
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: viewport.maxHeight * headerMaxHeightRatio,
                  ),
                  child: SingleChildScrollView(child: header),
                ),
                Expanded(child: pane),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 标题区：大标题（矮屏下省略）+ 分段控件。
///
/// 矮屏时只保留分段控件 —— 它是页面唯一的导航，必须完整可见；
/// 页面身份已由底部导航栏的选中态表达，不依赖大标题。
class _CollegeHeader extends ConsumerWidget {
  const _CollegeHeader({required this.segment, required this.compact});

  final String segment;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, compact ? 8 : 42, 24, compact ? 8 : 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Text(
              '院校',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w300),
            ),
            const SizedBox(height: 12),
          ],
          CollegeSegmentBar(
            segment: segment,
            onChanged: (value) =>
                ref.read(collegeSegmentProvider.notifier).state = value,
          ),
        ],
      ),
    );
  }
}
