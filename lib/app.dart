import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/constants/motivational_quotes.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/splash_overlay.dart';
import 'core/widgets/update_dialog.dart';
import 'providers/ambient_sound_provider.dart';
import 'providers/timer_provider.dart';
import 'providers/update_provider.dart';
import 'router/app_router.dart';

class QingzhouApp extends ConsumerStatefulWidget {
  const QingzhouApp({super.key});

  @override
  ConsumerState<QingzhouApp> createState() => _QingzhouAppState();
}

class _QingzhouAppState extends ConsumerState<QingzhouApp> {
  bool _updateDialogShowing = false;
  String? _lastPoppedUpdateVersion;
  Timer? _updateCheckTimer;
  // 冷启动展示启动页；widget 测试环境不展示，避免影响既有的首屏断言。
  bool _splashVisible = !Platform.environment.containsKey('FLUTTER_TEST');
  late final String _splashQuote = MotivationalQuotes.pick();

  @override
  void initState() {
    super.initState();
    // 自动检查到新版本时在根导航上弹窗；available 命中后会驻留状态，
    // 因此仅当版本号相对上次发生变化才弹窗——否则手动"检查更新"引起的
    // checking 状态变更会用旧 available 重复弹窗，与手动检查自己的弹窗叠加。
    ref.listenManual<UpdateState>(updateProvider, (_, next) {
      final update = next.available;
      if (update == null || _updateDialogShowing) return;
      if (_lastPoppedUpdateVersion == update.version) return;
      final dialogContext = rootNavigatorKey.currentContext;
      if (dialogContext == null) return;
      _lastPoppedUpdateVersion = update.version;
      _updateDialogShowing = true;
      showUpdateDialog(dialogContext, update).whenComplete(() {
        _updateDialogShowing = false;
      });
    });
    // 氛围音联动专注计时：在根节点注册（listenManual + fireImmediately），
    // 保证启动即创建 provider 并捕获注册前已发生的状态（如快照恢复的运行中计时），
    // 避免懒创建导致错过"专注开始"事件。
    final ambientNotifier = ref.read(ambientSoundProvider.notifier);
    ref.listenManual<TimerStateData>(timerProvider, (_, next) {
      final isFocusRunning =
          next.state == TimerState.running &&
          next.sessionType == SessionType.focus;
      if (isFocusRunning) {
        unawaited(ambientNotifier.autoStartIfEnabled());
      } else {
        unawaited(ambientNotifier.stopPlayback());
      }
    }, fireImmediately: true);
    // 每次进入 app 检查一次更新：等首页稳定后再静默请求，避免抢占启动。
    // 有启动页时推迟到启动页淡出之后，否则更新弹窗会盖在启动页上并被覆盖层吃掉点击。
    if (!_splashVisible) _startUpdateCheck();
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
  }

  void _startUpdateCheck() {
    // widget 测试环境不发起真实网络检查，也不留下未触发的 Timer。
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _updateCheckTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  void _handleSplashFinished() {
    setState(() => _splashVisible = false);
    _startUpdateCheck();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '轻舟',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
      // 首页在启动页下方先行构建，启动页淡出后即可直接使用
      builder: (context, child) => Stack(
        fit: StackFit.expand,
        children: [
          if (child != null) child,
          if (_splashVisible)
            SplashOverlay(
              quote: _splashQuote,
              onFinished: _handleSplashFinished,
            ),
        ],
      ),
    );
  }
}
