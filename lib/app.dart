import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
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
  Timer? _updateCheckTimer;

  @override
  void initState() {
    super.initState();
    // 自动检查到新版本时在根导航上弹窗；同一版本每次启动只弹一次。
    ref.listenManual<UpdateState>(updateProvider, (_, next) {
      final update = next.available;
      if (update == null || _updateDialogShowing) return;
      final dialogContext = rootNavigatorKey.currentContext;
      if (dialogContext == null) return;
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
    // widget 测试环境不发起真实网络检查，也不留下未触发的 Timer。
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    _updateCheckTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) ref.read(updateProvider.notifier).checkForUpdate();
    });
  }

  @override
  void dispose() {
    _updateCheckTimer?.cancel();
    super.dispose();
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
    );
  }
}
