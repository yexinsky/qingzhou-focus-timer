import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/layout_utils.dart';

class MainShell extends StatelessWidget {
  final Widget child;

  const MainShell({super.key, required this.child});

  int _getCurrentIndex(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    switch (location) {
      case '/focus':
        return 0;
      case '/plan':
        return 1;
      case '/stats':
        return 2;
      case '/college':
        return 3;
      case '/settings':
        return 4;
      default:
        return 0;
    }
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/focus');
        break;
      case 1:
        context.go('/plan');
        break;
      case 2:
        context.go('/stats');
        break;
      case 3:
        context.go('/college');
        break;
      case 4:
        context.go('/settings');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentIndex = _getCurrentIndex(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      // 平板等宽屏设备上内容居中限宽，避免单列布局被拉伸；手机宽度本就小于 560dp，不受影响
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: child,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          border: Border(
            top: BorderSide(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              width: 0.5,
            ),
          ),
        ),
        // 底栏是"必须一行放下"的固定区域：系统字体放大时先限制标签缩放
        // （正文仍按用户设置放大），再用 Flexible 让 5 个 tab 平分宽度，
        // 避免窄屏 + 大字体把 Row 撑破 / 把底栏越撑越高挤压 body。
        child: SafeArea(
          top: false,
          child: ClampedTextScale(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Flexible(
                    child: _NavItem(
                      key: const ValueKey('nav_item_0'),
                      icon: Icons.timer_outlined,
                      activeIcon: Icons.timer,
                      label: '专注',
                      isActive: currentIndex == 0,
                      onTap: () => _onTap(context, 0),
                    ),
                  ),
                  Flexible(
                    child: _NavItem(
                      key: const ValueKey('nav_item_1'),
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_today,
                      label: '计划',
                      isActive: currentIndex == 1,
                      onTap: () => _onTap(context, 1),
                    ),
                  ),
                  Flexible(
                    child: _NavItem(
                      key: const ValueKey('nav_item_2'),
                      icon: Icons.bar_chart_outlined,
                      activeIcon: Icons.bar_chart,
                      label: '统计',
                      isActive: currentIndex == 2,
                      onTap: () => _onTap(context, 2),
                    ),
                  ),
                  Flexible(
                    child: _NavItem(
                      key: const ValueKey('nav_item_3'),
                      icon: Icons.school_outlined,
                      activeIcon: Icons.school,
                      label: '院校',
                      isActive: currentIndex == 3,
                      onTap: () => _onTap(context, 3),
                    ),
                  ),
                  Flexible(
                    child: _NavItem(
                      key: const ValueKey('nav_item_4'),
                      icon: Icons.settings_outlined,
                      activeIcon: Icons.settings,
                      label: '设置',
                      isActive: currentIndex == 4,
                      onTap: () => _onTap(context, 4),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    super.key,
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;
    final inactiveColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        // 横向内边距收窄：5 个 tab 平分宽度时，窄屏（320dp）也要让
        // 「图标 + 2 个字标签」放得下，多余空间由 Row 的 spaceAround 分配。
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: BoxDecoration(
          color: isActive
              ? activeColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isActive ? activeIcon : icon,
              size: 24,
              color: isActive ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 4),
            // FittedBox(scaleDown)：极窄屏 / 超大字体时标签按需缩小而不是
            // 撑破底栏（文字本身仍受外层 ClampedTextScale 控制）。
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? activeColor : inactiveColor,
                  letterSpacing: 0.5,
                ),
                child: Text(label, maxLines: 1, softWrap: false),
              ),
            ),
            // 活动圆点的占位始终保留：否则选中/未选中的 tab 高度差 8dp，
            // 切 tab 时底栏会变高变矮、body 可用高度跟着跳变。这里只是隐藏
            // 圆点本身，视觉与原来一致（未选中时看不到圆点）。
            const SizedBox(height: 4),
            SizedBox(
              width: 4,
              height: 4,
              child: isActive
                  ? DecoratedBox(
                      decoration: BoxDecoration(
                        color: activeColor,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
