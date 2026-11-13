import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../utils/layout_utils.dart';

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

/// 底部弹窗内容的可用高度：屏幕高度扣除安全区与键盘遮挡。
///
/// 为什么要自己算：`showModalBottomSheet` 只把「屏幕高度」交给内容作为上限，
/// 既不扣刘海 / 状态栏，也不扣弹起的键盘；而路由外层套着 `ClipRect`，
/// 超出部分会被直接裁掉——表现就是「按钮被切掉、点不到」。
double adaptiveSheetMaxHeight(BuildContext context) =>
    math.max(0.0, LayoutUtils.availableHeight(context));

/// 弹窗内容自己的底部留白：系统手势区 + 业务间距。
///
/// 键盘遮挡不在这里计算，由 [AdaptiveSheetBody] 统一承担，避免重复抬高。
double adaptiveSheetBottomPadding(BuildContext context, {double extra = 16}) =>
    math.max(0.0, MediaQuery.paddingOf(context).bottom) + math.max(0.0, extra);

/// 底部弹窗内容的统一外壳：键盘避让 + 高度限幅。
///
/// 做两件事：
/// 1. 外层按 `MediaQuery.viewInsets.bottom` 抬高——模态底部弹窗贴屏幕底部摆放，
///    框架不会自动把它顶到键盘上方，不抬高的话输入框 / 底部按钮会被键盘遮住；
/// 2. 把内容的最大高度收敛到 [adaptiveSheetMaxHeight]，让内部滚动区域有确定的
///    上限，不会出现「内容被 ClipRect 裁掉、又无法滚动查看」的情况。
///
/// 只负责限高，滚动仍由内容自己决定（[SingleChildScrollView] 等）：
/// 因此未加滚动的内容超长时会照旧抛 RenderFlex 溢出，问题能被发现而不是被藏起来。
///
/// 用了它之后，内部**不要**再自己加 `viewInsets.bottom` 的 padding，否则键盘
/// 高度会被计算两遍，内容会被压得过扁。
class AdaptiveSheetBody extends StatelessWidget {
  const AdaptiveSheetBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: math.max(0.0, media.viewInsets.bottom)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: adaptiveSheetMaxHeight(context)),
        child: child,
      ),
    );
  }
}
