import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/layout_utils.dart';

/// 院校页顶部的三段切换：「排名 / 专业代码 / 目标」。
///
/// 没有沿用 Material 3 的 `SegmentedButton`：它默认在选中项前面打一个对勾，
/// 三段中文短词并排时勾号会把文字挤偏，选中态又是整块实色 + 粗外框，
/// 压在留白很大的页头上显得很重。
///
/// 这里改成「浅色轨道 + 浮起药丸」：选中项只靠底色与主色文字区分，
/// 无图标、无外框、无竖分隔线，视觉重量与页面整体的莫兰迪留白一致。
class CollegeSegmentBar extends StatelessWidget {
  const CollegeSegmentBar({
    super.key,
    required this.segment,
    required this.onChanged,
  });

  /// 当前选中的分段值（'ranking' / 'codes' / 'goals'）。
  final String segment;

  final ValueChanged<String> onChanged;

  static const List<(String, String)> _options = [
    ('ranking', '排名'),
    ('codes', '专业代码'),
    ('goals', '目标'),
  ];

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.primaryDark : AppColors.primaryLight;
    // 轨道：浅色下是比页面底色略深一点的分割线色，深色下是一层淡白罩。
    final trackColor = dark
        ? Colors.white.withValues(alpha: 0.05)
        : AppColors.dividerLight.withValues(alpha: 0.5);
    // 药丸：浅色下是卡片白（靠极淡投影浮起），深色下是一层主色薄雾。
    final pillColor = dark
        ? accent.withValues(alpha: 0.18)
        : AppColors.cardLight;

    return ClampedTextScale(
      // 三段「必须挤在一行」：字体放大到 1.3 倍以上就统一封顶，
      // 超出时按省略号收尾，而不是把药丸挤出屏幕。
      maxScaleFactor: 1.3,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: trackColor,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (value, label) in _options)
              Flexible(
                child: _Segment(
                  label: label,
                  selected: segment == value,
                  accent: accent,
                  pillColor: pillColor,
                  onTap: () => onChanged(value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.accent,
    required this.pillColor,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Color pillColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeInOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? pillColor : Colors.transparent,
          borderRadius: BorderRadius.circular(19),
          boxShadow: selected && !dark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 5,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            letterSpacing: 0.3,
            color: selected
                ? accent
                : (dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
