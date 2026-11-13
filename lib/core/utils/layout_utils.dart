import 'package:flutter/material.dart';

/// 多端布局适配共享工具。
///
/// 该文件由团队统一维护，供各页面 / 弹窗复用，避免把魔法数字散落到各处。
/// 只提供无状态的纯函数与轻量包装组件，不包含任何业务逻辑。
class LayoutUtils {
  LayoutUtils._();

  /// 系统字体缩放的统一上限。
  ///
  /// 布局本身以弹性为主（滚动 / Wrap / Flexible），这里只是最后一道保险：
  /// 当系统字体被放大到 1.4 倍以上时，底部固定的操作栏、导航栏等
  /// 「必须一行放下」的区域仍能保持可点击、不被裁切。
  static const double maxTextScaleFactor = 1.4;

  /// 屏幕宽度是否达到平板 / 宽屏阈值。
  static const double wideBreakpoint = 600;

  /// 扣掉系统安全区与键盘遮挡之后的可用高度。
  static double availableHeight(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.height - media.padding.vertical - media.viewInsets.bottom;
  }

  /// 扣掉系统安全区与键盘遮挡之后的可用宽度。
  static double availableWidth(BuildContext context) {
    final media = MediaQuery.of(context);
    return media.size.width - media.padding.horizontal;
  }

  /// 是否为「矮屏」：横屏、小屏，或者键盘弹起后剩余空间不足。
  ///
  /// 页面可以据此把「底部固定按钮」退化为「随内容滚动」。
  static bool isCompactHeight(BuildContext context, {double threshold = 520}) =>
      availableHeight(context) < threshold;

  /// 当前系统字体缩放是否已经大到会影响固定高度区域。
  static bool isLargeText(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(14) > 14 * maxTextScaleFactor;
}

/// 限制子树中的文本缩放，避免系统字体放大时文字撑破固定高度的按钮 / 标签。
///
/// 只用于导航栏、底部操作栏这类「必须容纳在一行内」的容器；
/// 正文、列表内容请保持用户设置的原始缩放（无障碍优先）。
class ClampedTextScale extends StatelessWidget {
  const ClampedTextScale({
    super.key,
    this.maxScaleFactor = LayoutUtils.maxTextScaleFactor,
    required this.child,
  });

  final double maxScaleFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    maxScaleFactor: maxScaleFactor,
    child: child,
  );
}
