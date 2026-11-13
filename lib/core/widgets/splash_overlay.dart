import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// 启动页停留时长：自首帧起算，到点后开始淡出。
const Duration kSplashDuration = Duration(seconds: 3);

const Duration _fadeInDuration = Duration(milliseconds: 400);
const Duration _fadeOutDuration = Duration(milliseconds: 400);
// logo 只作品牌标记，视觉主体是励志语句，故尺寸克制
const double _logoWidth = 120;

/// 冷启动覆盖层：居中 logo + 一句励志语句，停留 [duration] 后淡出并回调 [onFinished]。
///
/// 整屏不透明，覆盖期内天然拦截触摸，下方首页不会误触。
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({
    super.key,
    required this.quote,
    required this.onFinished,
    this.duration = kSplashDuration,
  });

  /// 展示的励志语句。
  final String quote;

  /// 停留时长（自首帧起算，不含随后的淡出）。
  final Duration duration;

  /// 淡出完成时回调，调用方据此移除本覆盖层。
  final VoidCallback onFinished;

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _contentFade;
  late final Animation<double> _quoteFade;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _fadeInDuration)
      ..forward();
    _contentFade = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );
    // 语句比 logo 稍晚浮现，整体更沉一点，也避免整块内容一起弹出
    _quoteFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.3, 1, curve: Curves.easeInOutCubic),
    );
    _controller.addStatusListener(_handleStatus);
    _holdTimer = Timer(widget.duration, _startFadeOut);
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startFadeOut() {
    if (!mounted) return;
    _controller.duration = _fadeOutDuration;
    _controller.reverse();
  }

  /// 反向动画归零即淡出结束；中途被卸载（dispose）不会再收到状态回调。
  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.dismissed) widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ColoredBox(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      child: SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: _contentFade,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  // 启动页是整屏浅色/深色底，图标跟着走浅深两版：
                  // 浅色底上用纸色版（logo_cream），主色版的深绿底块在
                  // 近白背景上会显得过重，像贴了一块深色方片。
                  isDark
                      ? 'design/logo/logo_dark.png'
                      : 'design/logo/logo_cream.png',
                  width: _logoWidth,
                  // 原图为 1024²，按 3x 屏的展示尺寸解码，避免整张大图进内存
                  cacheWidth: (_logoWidth * 3).round(),
                ),
                const SizedBox(height: 32),
                FadeTransition(
                  opacity: _quoteFade,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      widget.quote,
                      textAlign: TextAlign.center,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 1.2,
                        height: 1.7,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
