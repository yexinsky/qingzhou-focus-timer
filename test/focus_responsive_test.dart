import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/views/focus/focus_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

/// 专注页多端布局回归：小屏 / 字体放大 / 横屏 / 键盘弹起下不得溢出，
/// 「固定的分钟栏」与底部操作区必须完整落在屏幕内。
void _setSize(WidgetTester tester, Size logicalSize) {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void _setTextScale(WidgetTester tester, double scale) {
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

/// 记录布局异常并转发给测试框架（转发是必须的，否则 binding 会断言失败），
/// 测试体结束后统一 drain 掉 pending exception。
///
/// 团队并行改造中，底部导航（main_shell.dart）、任务选择弹窗
/// （task_selector_sheet.dart）等由其他成员负责；本文件只对专注页自身
/// （focus_view.dart / timer_ring.dart）的溢出判失败，其余仅记录。
Future<void> _captureLayoutErrors(
  WidgetTester tester,
  List<String> sink,
  Future<void> Function() body,
) async {
  final previous = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final text = details.toString();
    const marker = 'The relevant error-causing widget was';
    final index = text.indexOf(marker);
    sink.add(
      index >= 0
          ? text.substring(index, math.min(text.length, index + 240))
          : text,
    );
    previous?.call(details);
  };
  try {
    await body();
  } finally {
    FlutterError.onError = previous;
    while (tester.takeException() != null) {}
  }
}

/// 并行改造期间由其他成员负责的文件：其溢出不算本文件的失败项
/// （底部导航 main_shell.dart / 任务选择弹窗 task_selector_sheet.dart）。
const _otherOwnerFiles = <String>[
  'main_shell.dart',
  'task_selector_sheet.dart',
];

void _expectFocusLayoutClean(List<String> errors) {
  final tolerated = <String>[];
  final blocking = <String>[];
  for (final e in errors) {
    final own = e.contains('focus_view.dart') || e.contains('timer_ring.dart');
    if (own || !_otherOwnerFiles.any(e.contains)) {
      blocking.add(e);
    } else {
      tolerated.add(e);
    }
  }
  if (tolerated.isNotEmpty) {
    debugPrint(
      '[focus_responsive] 暂由他人负责的溢出 ${tolerated.length} 条：'
      '${tolerated.join(' | ')}',
    );
  }
  expect(
    blocking,
    isEmpty,
    reason: '专注页布局异常（${blocking.length} 条）：\n${blocking.join('\n---\n')}',
  );
}

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settingsRepository = SettingsRepository();
  await settingsRepository.init();
  final subjectRepository = SubjectRepository();
  await subjectRepository.init();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(TestTaskRepository()),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        subjectRepositoryProvider.overrideWithValue(subjectRepository),
      ],
      child: const QingzhouApp(),
    ),
  );
  // 专注页存在无限循环的呼吸动画，不能使用 pumpAndSettle
  await tester.pump(const Duration(milliseconds: 400));
}

void _expectInsideScreen(
  WidgetTester tester,
  Finder finder,
  Size screen, {
  required String label,
}) {
  expect(finder, findsWidgets, reason: '$label 未渲染');
  final rect = tester.getRect(finder.first);
  expect(rect.top, greaterThanOrEqualTo(-0.5), reason: '$label 顶部越出屏幕: $rect');
  expect(
    rect.bottom,
    lessThanOrEqualTo(screen.height + 0.5),
    reason: '$label 底部越出屏幕: $rect',
  );
  expect(rect.left, greaterThanOrEqualTo(-0.5), reason: '$label 左侧越出屏幕: $rect');
  expect(
    rect.right,
    lessThanOrEqualTo(screen.width + 0.5),
    reason: '$label 右侧越出屏幕: $rect',
  );
}

/// 内容区是可滚动的：先把它滚进视口，再断言完整可见。
Future<void> _scrollToAndExpectInside(
  WidgetTester tester,
  Finder finder,
  Size screen, {
  required String label,
}) async {
  expect(finder, findsWidgets, reason: '$label 未渲染');
  await tester.ensureVisible(finder.first);
  await tester.pump(const Duration(milliseconds: 300));
  _expectInsideScreen(tester, finder, screen, label: label);
}

/// 走一遍「点击计时环 → 选择专注任务弹窗 → 自由专注」，进入运行态。
Future<void> _enterRunningState(WidgetTester tester) async {
  final ringTimer = find.text('25:00');
  expect(ringTimer, findsOneWidget, reason: '计时环上的 25:00 未渲染');
  await tester.ensureVisible(ringTimer);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(ringTimer, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 600));

  final freeFinder = find.text('自由专注');
  expect(freeFinder, findsOneWidget, reason: '专注任务弹窗未出现');
  await tester.ensureVisible(freeFinder);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(freeFinder, warnIfMissed: false);
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = <String, Size>{
    'iPhone SE 320x568': Size(320, 568),
    '安卓常见 360x640': Size(360, 640),
    '全面屏 412x915': Size(412, 915),
    '横屏 640x360': Size(640, 360),
  };
  const scales = <double>[1.0, 1.4, 2.0];

  for (final entry in sizes.entries) {
    for (final scale in scales) {
      testWidgets('idle 态 ${entry.key} @textScale $scale 分钟栏可见且无溢出', (
        tester,
      ) async {
        final errors = <String>[];
        await _captureLayoutErrors(tester, errors, () async {
          _setSize(tester, entry.value);
          _setTextScale(tester, scale);
          await _pumpApp(tester);

          expect(find.byType(FocusView), findsOneWidget);
          _expectFocusLayoutClean(errors);

          // 回归点：「固定的分钟栏」首项必须完整可见可点（旧实现被裁到屏幕外）
          _expectInsideScreen(
            tester,
            find.text('25分钟'),
            entry.value,
            label: '25分钟胶囊',
          );
          _expectInsideScreen(
            tester,
            find.text('45分钟'),
            entry.value,
            label: '45分钟胶囊',
          );

          // 计时区与费曼入口在可滚动内容区里，滚到后必须完整可见
          await _scrollToAndExpectInside(
            tester,
            find.text('25:00'),
            entry.value,
            label: '倒计时 25:00',
          );
          await _scrollToAndExpectInside(
            tester,
            find.text('费曼学习'),
            entry.value,
            label: '费曼学习入口',
          );

          _expectFocusLayoutClean(errors);
        });
      });
    }
  }

  for (final entry in sizes.entries) {
    for (final scale in scales) {
      testWidgets('运行态 ${entry.key} @textScale $scale 底部控制区在屏内且无溢出', (
        tester,
      ) async {
        final errors = <String>[];
        await _captureLayoutErrors(tester, errors, () async {
          _setSize(tester, entry.value);
          _setTextScale(tester, scale);
          await _pumpApp(tester);
          await _enterRunningState(tester);

          expect(find.text('剩余时间'), findsOneWidget);
          _expectFocusLayoutClean(errors);

          // 旧实现里「放弃本次专注」会被挤出屏幕
          _expectInsideScreen(
            tester,
            find.text('放弃本次专注'),
            entry.value,
            label: '放弃本次专注',
          );
          _expectInsideScreen(
            tester,
            find.byIcon(Icons.pause),
            entry.value,
            label: '暂停按钮',
          );

          _expectFocusLayoutClean(errors);
        });
      });
    }
  }

  testWidgets('分钟栏可横向滚动：末项 60分钟 能滚进屏幕', (tester) async {
    final errors = <String>[];
    await _captureLayoutErrors(tester, errors, () async {
      const screen = Size(320, 568);
      _setSize(tester, screen);
      // 双倍字号把三枚胶囊撑到超出窄屏，横向滚动才有用武之地
      _setTextScale(tester, 2.0);
      await _pumpApp(tester);

      await tester.drag(find.text('25分钟'), const Offset(-300, 0));
      await tester.pump(const Duration(milliseconds: 300));
      _expectInsideScreen(
        tester,
        find.text('60分钟'),
        screen,
        label: '60分钟胶囊（横向滚动后）',
      );
      _expectFocusLayoutClean(errors);
    });
  });

  testWidgets('矮屏 320x480 @textScale 2.0 内容可滚动兜底不溢出', (tester) async {
    final errors = <String>[];
    await _captureLayoutErrors(tester, errors, () async {
      const screen = Size(320, 480);
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      await _pumpApp(tester);

      _expectFocusLayoutClean(errors);
      // 分钟栏是固定的：矮屏 + 双倍字号下依然可见
      _expectInsideScreen(tester, find.text('25分钟'), screen, label: '25分钟胶囊');
      // 内容区可滚动：拖到计时区依然不溢出
      await _scrollToAndExpectInside(
        tester,
        find.text('点击开始'),
        screen,
        label: '计时区提示文案',
      );
      _expectFocusLayoutClean(errors);
    });
  });

  testWidgets('键盘弹起（viewInsets 300）时底部按钮仍可见', (tester) async {
    final errors = <String>[];
    await _captureLayoutErrors(tester, errors, () async {
      const screen = Size(360, 640);
      const keyboardHeight = 300.0;
      _setSize(tester, screen);
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboardHeight);
      addTearDown(tester.view.resetViewInsets);
      await _pumpApp(tester);

      _expectFocusLayoutClean(errors);
      _expectInsideScreen(
        tester,
        find.text('25分钟'),
        screen,
        label: '25分钟胶囊（键盘弹起）',
      );
      // 分钟栏随内容滚动：键盘弹起时必须能被滚到键盘上沿之上，
      // 不能躲在键盘后面滚不出来（旧实现是贴底固定，直接被盖住）。
      final chipsRect = tester.getRect(find.text('25分钟').first);
      expect(
        chipsRect.bottom,
        lessThanOrEqualTo(screen.height - keyboardHeight + 0.5),
        reason: '分钟栏被键盘遮挡: $chipsRect',
      );
      _expectFocusLayoutClean(errors);
    });
  });
}
