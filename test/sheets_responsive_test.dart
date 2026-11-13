import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/core/widgets/adaptive_bottom_sheet.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/views/plan/widgets/add_task_sheet.dart';
import 'package:qingzhou_focus/views/settings/widgets/setting_tile.dart';
import 'package:qingzhou_focus/views/widgets/battery_guide_sheet.dart';
import 'package:qingzhou_focus/views/widgets/subject_manage_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

/// 计划页会读取 `monthTaskDateKeysProvider`（→ getTaskDateKeysInMonth），
/// 而共享的 TestTaskRepository 没有覆盖该方法，会落到真实实现里去访问
/// 未初始化的 Hive box。这里在测试内补齐，避免污染公共 helper。
class _SheetsTestTaskRepository extends TestTaskRepository {
  @override
  Set<String> getTaskDateKeysInMonth(String monthKey) => {
    for (final task in tasks.values)
      if (task.dateKey.startsWith(monthKey)) task.dateKey,
  };
}

/// 底部弹窗 / 表单的多端布局回归。
///
/// 覆盖四类真实触发场景：
/// 1. 小屏（320×568、360×640）；
/// 2. 系统字体放大（textScale 2.0）；
/// 3. 键盘弹起（viewInsets.bottom = 300）；
/// 4. 横屏（640×360）。
///
/// 断言的核心是「主操作按钮完整落在屏幕内、可被点到」——弹窗路由外层套着
/// ClipRect，内容一旦超出可用高度就会被直接裁掉，这正是用户反馈的
/// 「按钮被遮挡 / 点不到」。
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

/// 模拟软键盘弹起（Android 上键盘高度通常是 250~320dp）。
void _openKeyboard(WidgetTester tester, {double height = 300}) {
  tester.view.viewInsets = FakeViewPadding(bottom: height);
  addTearDown(tester.view.resetViewInsets);
}

/// 排空进入被测弹窗前累积的异常。
///
/// 团队并行改造中，底栏、专注页、计划页等由其他成员负责，本文件只对
/// 弹窗自身（sheets + setting_tile）的布局负责，因此只检查「打开弹窗之后」
/// 新产生的异常。注意本函数只在打开弹窗前调用，不会掩盖被测弹窗的问题。
void _drainExceptions(WidgetTester tester) {
  while (tester.takeException() != null) {}
}

/// 断言控件完整落在屏幕内（即用户能看到并点到）。
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

Future<void> _pumpApp(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final settingsRepository = SettingsRepository();
  await settingsRepository.init();
  final subjectRepository = SubjectRepository();
  await subjectRepository.init();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(_SheetsTestTaskRepository()),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        subjectRepositoryProvider.overrideWithValue(subjectRepository),
      ],
      child: const QingzhouApp(),
    ),
  );
  // 专注页存在无限循环的呼吸动画，不能使用 pumpAndSettle
  await tester.pump(const Duration(milliseconds: 400));
}

/// 切 tab：用 ValueKey 定位底栏项，避免和页面标题重名。
Future<void> _gotoTab(WidgetTester tester, int index) async {
  await tester.tap(find.byKey(ValueKey('nav_item_$index')));
  // 第一次 pump 让路由变更落下，第二次把 300ms 的转场动画推到终态。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 只保留底部弹窗进场动画，不用 pumpAndSettle。
Future<void> _settleSheet(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 直接以最小宿主打开时长选择器：不依赖设置页（避免把其他页面的状态
/// 引入本用例），聚焦「弹窗自身在极端尺寸下按钮是否在屏内」。
Future<void> _pumpDurationPickerHost(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => showAdaptiveBottomSheet(
                context: context,
                isScrollControlled: true,
                builder: (_) => DurationPickerSheet(
                  title: '默认专注时长',
                  currentValue: 25,
                  onChanged: (_) {},
                ),
              ),
              child: const Text('打开时长选择器'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开时长选择器'));
  await _settleSheet(tester);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('时长选择器（设置页 默认专注时长）', () {
    testWidgets('320x568 @textScale 2.0：确定按钮完整在屏内', (tester) async {
      const screen = Size(320, 568);
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      await _pumpDurationPickerHost(tester);

      expect(find.text('默认专注时长'), findsOneWidget);
      expect(find.text('分钟'), findsOneWidget);
      // 回归点：旧实现无滚动、按内容自然高度排布，小屏 + 大字体下
      // 『确定』被挤出屏幕底部并被 ClipRect 裁掉，用户点不到。
      _expectInsideScreen(tester, find.text('确定'), screen, label: '确定按钮');
      expect(tester.takeException(), isNull, reason: '时长选择器在 320x568/2.0 下溢出');
    });

    testWidgets('360x640 键盘弹起：确定按钮抬到键盘上方', (tester) async {
      const screen = Size(360, 640);
      const keyboard = 300.0;
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      await _pumpDurationPickerHost(tester);

      // 键盘在实际使用中可能晚于弹窗出现，所以这里在弹窗打开后再弹键盘。
      _openKeyboard(tester, height: keyboard);
      await tester.pump();

      final rect = tester.getRect(find.text('确定').first);
      _expectInsideScreen(tester, find.text('确定'), screen, label: '确定按钮');
      expect(
        rect.bottom,
        lessThanOrEqualTo(screen.height - keyboard + 0.5),
        reason: '确定按钮被键盘遮挡（bottom=${rect.bottom}）',
      );
      expect(tester.takeException(), isNull, reason: '键盘弹起时时长选择器溢出');
    });

    testWidgets('320x568 @textScale 2.0 + 键盘：极矮下退化为整体滚动，确定仍可触达', (
      tester,
    ) async {
      const screen = Size(320, 568);
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      await _pumpDurationPickerHost(tester);

      _openKeyboard(tester, height: 300);
      await tester.pump();

      // 可用高度只剩 268dp，「固定底栏」会把内容区压成 0 高，
      // 因此该分支退化为整体滚动：按钮仍可达（滚动后进屏幕）。
      final confirm = find.text('确定');
      await tester.ensureVisible(confirm.first);
      await tester.pump();
      _expectInsideScreen(tester, confirm, screen, label: '确定按钮（极矮兜底）');
      expect(tester.takeException(), isNull, reason: '极矮 + 键盘时溢出');
    });

    testWidgets('横屏 640x360 @textScale 2.0：确定按钮完整在屏内', (tester) async {
      const screen = Size(640, 360);
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      await _pumpDurationPickerHost(tester);

      _expectInsideScreen(tester, find.text('确定'), screen, label: '确定按钮');
      expect(tester.takeException(), isNull, reason: '横屏时长选择器溢出');
    });

    testWidgets('真实路径：设置页 → 默认专注时长 → 确定在屏内', (tester) async {
      const screen = Size(320, 568);
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      await _pumpApp(tester);
      _drainExceptions(tester);

      await _gotoTab(tester, 4); // 设置
      _drainExceptions(tester);

      final tile = find
          .ancestor(of: find.text('默认专注时长'), matching: find.byType(SettingTile))
          .first;
      expect(tile, findsOneWidget, reason: '设置页缺少「默认专注时长」项');
      await tester.ensureVisible(tile);
      await tester.pump();

      final entry = find.descendant(
        of: tile,
        matching: find.byType(TextButton),
      );
      expect(entry, findsOneWidget, reason: '时长项缺少可点击的数值入口');
      await tester.tap(entry.first);
      await _settleSheet(tester);

      expect(find.text('分钟'), findsOneWidget, reason: '时长选择器未打开');
      _expectInsideScreen(tester, find.text('确定'), screen, label: '确定按钮');
      expect(tester.takeException(), isNull, reason: '设置页打开时长选择器后溢出');
    });
  });

  group('添加任务表单（计划页 FAB）', () {
    testWidgets('360x640 @textScale 2.0 + 键盘：提交按钮可达', (tester) async {
      const screen = Size(360, 640);
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      await _pumpApp(tester);
      _drainExceptions(tester);

      await _gotoTab(tester, 1); // 计划
      _drainExceptions(tester);

      await tester.tap(find.byType(FloatingActionButton));
      await _settleSheet(tester);
      expect(find.byType(AddTaskSheet), findsOneWidget, reason: '添加任务表单未打开');

      // 键盘在表单打开后弹起（点「任务名称」输入框时的真实时序）
      _openKeyboard(tester, height: 300);
      await tester.pump();

      // 表单是「整体滚动」：按钮随内容滚动，滚动后必须完整进入屏幕
      final submit = find.widgetWithText(FilledButton, '添加');
      expect(submit, findsOneWidget, reason: '表单缺少提交按钮');
      await tester.ensureVisible(submit.first);
      await tester.pump();

      _expectInsideScreen(tester, submit, screen, label: '添加按钮');
      final rect = tester.getRect(submit.first);
      expect(
        rect.bottom,
        lessThanOrEqualTo(screen.height - 300 + 0.5),
        reason: '添加按钮被键盘遮挡（bottom=${rect.bottom}）',
      );
      expect(tester.takeException(), isNull, reason: '添加任务表单溢出');
    });
  });

  group('其它底部弹窗', () {
    testWidgets('320x568 @textScale 2.0：电池优化指引可滚动且不溢出', (tester) async {
      const screen = Size(320, 568);
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => BatteryGuideSheet.show(context),
                  child: const Text('打开指引'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开指引'));
      await _settleSheet(tester);

      _expectInsideScreen(
        tester,
        find.text('各机型后台设置路径'),
        screen,
        label: '电池优化指引标题',
      );
      expect(tester.takeException(), isNull, reason: '电池优化指引在小屏/大字体下溢出');
    });

    testWidgets('320x568 @textScale 2.0：管理科目弹窗的输入行与列表都在屏内', (tester) async {
      const screen = Size(320, 568);
      _setSize(tester, screen);
      _setTextScale(tester, 2.0);
      SharedPreferences.setMockInitialValues({});
      final subjectRepository = SubjectRepository();
      await subjectRepository.init();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            subjectRepositoryProvider.overrideWithValue(subjectRepository),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: TextButton(
                    onPressed: () => SubjectManageSheet.show(context),
                    child: const Text('打开管理科目'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开管理科目'));
      await _settleSheet(tester);

      expect(find.text('管理科目'), findsOneWidget);
      // 列表区固定 320dp 高 + 输入行常驻底部的旧实现，在大字体下会把
      // 输入行/「添加」按钮挤出屏幕；现在列表可独立滚动、输入行始终在屏内。
      _expectInsideScreen(tester, find.text('添加'), screen, label: '添加按钮');
      expect(tester.takeException(), isNull, reason: '管理科目弹窗在大字体下溢出');
    });
  });
}
