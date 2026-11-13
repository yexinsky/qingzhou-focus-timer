import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/layout_utils.dart';
import '../../../core/widgets/adaptive_bottom_sheet.dart';

class SettingTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showDivider;

  const SettingTile({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.trailing,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: AppColors.textSecondary),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            color:
                (Theme.of(context).brightness == Brightness.dark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight)
                    .withValues(alpha: 0.5),
          ),
      ],
    );
  }
}

class DurationPickerSheet extends StatefulWidget {
  final String title;
  final int currentValue;
  final int minValue;
  final int maxValue;
  final Function(int) onChanged;

  const DurationPickerSheet({
    super.key,
    required this.title,
    required this.currentValue,
    this.minValue = 1,
    this.maxValue = 120,
    required this.onChanged,
  });

  @override
  State<DurationPickerSheet> createState() => _DurationPickerSheetState();
}

class _DurationPickerSheetState extends State<DurationPickerSheet> {
  late int _value;

  @override
  void initState() {
    super.initState();
    _value = widget.currentValue;
  }

  void _increment() {
    if (_value < widget.maxValue) {
      setState(() => _value++);
    }
  }

  void _decrement() {
    if (_value > widget.minValue) {
      setState(() => _value--);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmButton = _buildConfirmButton(isDark);

    return AdaptiveSheetBody(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        // 弹窗路由只把「屏幕高度」作为上限交给内容，超出的部分会被 ClipRect 直接
        // 裁掉（表现就是『确定』按钮被切掉、点不到）。AdaptiveSheetBody 先把键盘
        // 与安全区让出来，这里再用 LayoutBuilder 拿真实可用高度做两件事：
        //   1. 内容区可滚动，高度上限永远来自可用高度，不写死；
        //   2. 『确定』按钮固定在底部，任何机型 / 字体缩放 / 键盘下都在屏内。
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = constraints.maxHeight;
            // 连底栏都放不下的极矮场景（横屏 + 键盘 + 超大字体叠加）：
            // 「固定底栏 + 可滚内容」会把内容区压成 0 高，此时退化为
            // 「整体滚动 + 按钮随内容」，保证按钮依然可达、数值依然可见。
            final compact = maxHeight < 280;
            // 底部留白 = 手势区 + 间距（键盘已由 AdaptiveSheetBody 抬高，不重复算），
            // 并给内容留出空间，避免留白把内容压没。
            final bottomInset = compact
                ? 16.0
                : math.min(
                    adaptiveSheetBottomPadding(context),
                    maxHeight * 0.4,
                  );

            final content = Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildCounterRow(context),
                Text(
                  '分钟',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            );

            if (compact) {
              // 极矮兜底：整体滚动，按钮跟在数值后面一起滚
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    content,
                    const SizedBox(height: 24),
                    confirmButton,
                  ],
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 内容可滚：小屏 / 横屏 / 字体放大时标题与计数器不会被压出屏幕
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                    child: content,
                  ),
                ),
                // 底部按钮固定：始终在屏内，底部留白吃掉手势区
                Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset),
                  child: confirmButton,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// 数字 + 两个 48dp 触控按钮：数字用 FittedBox 兜底，
  /// 字体放大到 2 倍时压缩字号而不是横向溢出；按钮间距固定 40dp 但整行可缩。
  Widget _buildCounterRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _CircleButton(
          icon: Icons.remove,
          onTap: _decrement,
          enabled: _value > widget.minValue,
        ),
        const SizedBox(width: 40),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Text(
                '$_value',
                key: ValueKey(_value),
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  fontWeight: FontWeight.w200,
                  fontSize: 56,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 40),
        _CircleButton(
          icon: Icons.add,
          onTap: _increment,
          enabled: _value < widget.maxValue,
        ),
      ],
    );
  }

  Widget _buildConfirmButton(bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () {
          widget.onChanged(_value);
          Navigator.pop(context);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark
              ? AppColors.primaryDark
              : AppColors.primaryLight,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        // 按钮文字限制缩放上限：底栏是「必须一行放下」的区域，
        // 系统字体放到 2 倍时仍保持文字完整可读，不会撑破按钮。
        child: const ClampedTextScale(
          child: Text(
            '确定',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool enabled;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: enabled
              ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
                    .withValues(alpha: 0.1)
              : AppColors.dividerLight.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: enabled
              ? (isDark ? AppColors.primaryDark : AppColors.primaryLight)
              : AppColors.textSecondary.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
