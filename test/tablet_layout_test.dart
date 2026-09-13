import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/views/focus/focus_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

void _setSize(WidgetTester tester, Size logicalSize) {
  tester.view.physicalSize = logicalSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
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

Rect _globalBounds(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'tablet landscape (1097x617dp) keeps content centered within 560dp without overflow',
    (tester) async {
      _setSize(tester, const Size(1097, 617));
      await _pumpApp(tester);

      // 内容区限宽 560 且水平居中（FittedBox 同时兜底防止计时区溢出）
      final bounds = _globalBounds(tester, find.byType(FocusView));
      expect(bounds.width, lessThanOrEqualTo(560.001));
      final leftGutter = bounds.left;
      final rightGutter = 1097 - bounds.right;
      expect((leftGutter - rightGutter).abs(), lessThan(2));
    },
  );

  testWidgets(
    'tablet portrait (617x1097dp) keeps content centered without overflow',
    (tester) async {
      _setSize(tester, const Size(617, 1097));
      await _pumpApp(tester);

      final bounds = _globalBounds(tester, find.byType(FocusView));
      expect(bounds.width, lessThanOrEqualTo(560.001));
      final leftGutter = bounds.left;
      final rightGutter = 617 - bounds.right;
      expect((leftGutter - rightGutter).abs(), lessThan(2));
    },
  );

  testWidgets('phone (360x640dp) keeps full-width layout', (tester) async {
    _setSize(tester, const Size(360, 640));
    await _pumpApp(tester);

    final bounds = _globalBounds(tester, find.byType(FocusView));
    expect(bounds.width, greaterThanOrEqualTo(359));
    expect(bounds.left, lessThan(1));
  });

  testWidgets(
    'tablet landscape running timer does not overflow (FittedBox scales timer area)',
    (tester) async {
      _setSize(tester, const Size(1097, 617));
      await _pumpApp(tester);

      // 选择自由专注并启动计时，让控制按钮区出现（垂直空间最紧张的状态）
      await tester.tap(find.text('25:00'), warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      // 弹窗已滑入
      expect(find.text('按科目专注'), findsOneWidget);
      final freeFinder = find.text('自由专注');
      expect(freeFinder, findsOneWidget);
      // 横屏弹窗高度受限，自由专注按钮在滚动区域内
      await tester.ensureVisible(freeFinder);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(freeFinder, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 500));
      // 固定计时模式的自由专注进入运行态：出现剩余时间与控制按钮（溢出会直接抛异常）
      expect(find.text('剩余时间'), findsOneWidget);
      expect(find.text('放弃本次专注'), findsOneWidget);
    },
  );
}
