import 'package:flutter/material.dart';

/// 底部弹窗统一入口：手机上全宽展示，平板等宽屏设备（>560dp）底部居中限宽。
Future<T?> showAdaptiveBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    backgroundColor: Colors.transparent,
    // 不能用 Align 包裹：Align 会撑满弹窗可用高度，透明的 Material 会挡住
    // 黑幕区域的点击，导致点击弹窗外侧无法关闭弹窗。
    builder: (context) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      // 统一提供不透明圆角底板：个别弹窗内容自身没有背景色，
      // 透明时会透出被压暗的页面内容。已有背景的弹窗颜色一致，叠加无副作用。
      child: Material(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: builder(context),
      ),
    ),
  );
}
