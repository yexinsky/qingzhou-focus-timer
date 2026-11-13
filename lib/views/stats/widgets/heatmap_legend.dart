import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/layout_utils.dart';

class HeatmapLegend extends StatelessWidget {
  const HeatmapLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryDark
        : AppColors.primaryLight;
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary);

    // 图例是纯装饰性说明，不应随系统字体无限放大抢走标题宽度：
    // 文字缩放封顶 LayoutUtils.maxTextScaleFactor，外层 FittedBox 再兜底，
    // 保证「学习日历」标题行在 320dp 窄屏 + textScale 2.0 时也不溢出。
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: LayoutUtils.maxTextScaleFactor,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: AlignmentDirectional.centerEnd,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('少', maxLines: 1, softWrap: false, style: labelStyle),
            const SizedBox(width: 4),
            for (final opacity in [0.08, 0.25, 0.50, 0.75, 1.0])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: opacity),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            const SizedBox(width: 4),
            Text('多', maxLines: 1, softWrap: false, style: labelStyle),
          ],
        ),
      ),
    );
  }
}
