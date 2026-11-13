import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/models/task.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/views/plan/plan_view.dart';
import 'package:qingzhou_focus/views/plan/widgets/task_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

/// 计划页会读取 `monthTaskDateKeysProvider`（→ getTaskDateKeysInMonth），
/// 而共享的 TestTaskRepository 没有覆盖该方法，会落到真实实现里去访问
/// 未初始化的 Hive box。这里在测试内补齐，避免污染公共 helper。
class _PlanTestTaskRepository extends TestTaskRepository {
  @override
  Set<String> getTaskDateKeysInMonth(String monthKey) => {
    for (final task in tasks.values)
      if (task.dateKey.startsWith(monthKey)) task.dateKey,
  };
}

/// 主框架底栏 + 计划页的多端布局回归：
/// 小屏（320×568）、常见手机（360×640）、横屏（640×360）× 系统字体
/// 1.0 / 2.0 缩放下都不应出现 RenderFlex overflow，且底栏 5 个标签与
/// 计划页 FAB 都必须完整落在屏幕内、互不遮挡。
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

/// 模拟刘海 / 手势条安全区。
void _setSafeArea(WidgetTester tester, {double top = 0, double bottom = 0}) {
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
}

/// 模拟键盘弹起（只占用底部，不改变逻辑尺寸）。
void _setKeyboardInset(WidgetTester tester, double bottom) {
  tester.view.viewInsets = FakeViewPadding(bottom: bottom);
  addTearDown(tester.view.resetViewInsets);
}

Future<void> _pumpApp(
  WidgetTester tester, {
  List<Task> seedTasks = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final settingsRepository = SettingsRepository();
  await settingsRepository.init();
  final subjectRepository = SubjectRepository();
  await subjectRepository.init();
  final taskRepository = _PlanTestTaskRepository();
  for (final task in seedTasks) {
    taskRepository.tasks[task.id] = task;
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(taskRepository),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        subjectRepositoryProvider.overrideWithValue(subjectRepository),
      ],
      child: const QingzhouApp(),
    ),
  );
  // 专注页存在无限循环的呼吸动画，不能使用 pumpAndSettle
  await tester.pump(const Duration(milliseconds: 400));
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

/// 预置一张高优先级 + 长标题/长备注的未完成任务和一张已完成任务，
/// 让 TaskCard 的密集行 / 已完成分组也进入被测布局。
List<Task> _seedTasks() => [
  Task(
    id: 't-plan-1',
    title: '复习高等数学第三章：多元函数微分学与方向导数',
    subject: '数学',
    dateKey: _todayKey(),
    createdAt: DateTime.now().millisecondsSinceEpoch,
    priority: 2,
    note: '重点看梯度与方向导数的几何意义，再做两套真题巩固',
    estimatedPomodoros: 3,
  ),
  Task(
    id: 't-plan-2',
    title: '英语阅读真题',
    subject: '英语',
    completed: true,
    dateKey: _todayKey(),
    createdAt: DateTime.now().millisecondsSinceEpoch - 1000,
  ),
];

Rect _globalBounds(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return box.localToGlobal(Offset.zero) & box.size;
}

/// 断言 [inner] 完整位于 [outer] 之内（含 0.5 的浮点容差）。
void _expectInside(Rect outer, Rect inner, String label) {
  expect(
    inner.left,
    greaterThanOrEqualTo(outer.left - 0.5),
    reason: '$label 左边界超出屏幕（left=${inner.left}）',
  );
  expect(
    inner.right,
    lessThanOrEqualTo(outer.right + 0.5),
    reason: '$label 右边界超出屏幕（right=${inner.right}）',
  );
  expect(
    inner.top,
    greaterThanOrEqualTo(outer.top - 0.5),
    reason: '$label 上边界超出屏幕（top=${inner.top}）',
  );
  expect(
    inner.bottom,
    lessThanOrEqualTo(outer.bottom + 0.5),
    reason: '$label 下边界超出屏幕（bottom=${inner.bottom}）',
  );
}

const _navLabels = ['专注', '计划', '统计', '院校', '设置'];

/// 切到计划页：点底栏第二个 tab（用 ValueKey 定位，避免和页面标题「计划」重名）。
Future<void> _gotoPlanTab(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('nav_item_1')));
  // 第一次 pump 让路由变更落下，第二次把 300ms 的转场动画推到终态。
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// 计划页 CustomScrollView 的滚动位置（不使用 pumpAndSettle）。
ScrollPosition _planScrollPosition(WidgetTester tester) {
  final scrollableFinder = find
      .descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      )
      .first;
  return tester.state<ScrollableState>(scrollableFinder).position;
}

/// 把计划页的 CustomScrollView 滚到底。
void _scrollToBottom(WidgetTester tester) {
  final position = _planScrollPosition(tester);
  position.jumpTo(position.maxScrollExtent);
}

/// 逐步下滚直到 [finder] 命中（懒加载列表在屏幕外的子项不会被构建，
/// 所以只能滚动逼近，而不能直接断言总数）。
Future<void> _scrollUntilFound(
  WidgetTester tester,
  Finder finder, {
  double step = 160,
  int maxSteps = 80,
}) async {
  for (var i = 0; i < maxSteps; i++) {
    if (finder.evaluate().isNotEmpty) return;
    final position = _planScrollPosition(tester);
    if (position.pixels >= position.maxScrollExtent) return;
    position.jumpTo(
      (position.pixels + step).clamp(0.0, position.maxScrollExtent),
    );
    await tester.pump();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sizes = <String, Size>{
    'small 320x568': Size(320, 568),
    'phone 360x640': Size(360, 640),
    'landscape 640x360': Size(640, 360),
  };
  const scales = <double>[1.0, 2.0];

  for (final entry in sizes.entries) {
    for (final scale in scales) {
      testWidgets(
        'plan page (${entry.key}, textScale ${scale}x) 无溢出且底栏/FAB 可见',
        (tester) async {
          _setSize(tester, entry.value);
          _setTextScale(tester, scale);
          await _pumpApp(tester);

          final screen = Rect.fromLTWH(
            0,
            0,
            entry.value.width,
            entry.value.height,
          );

          // 底栏 5 个 tab：文案（既有契约）与几何位置都要成立
          for (var i = 0; i < _navLabels.length; i++) {
            expect(
              find.text(_navLabels[i]),
              findsWidgets,
              reason: '底栏缺少「${_navLabels[i]}」标签',
            );
            final itemFinder = find.byKey(ValueKey('nav_item_$i'));
            expect(itemFinder, findsOneWidget, reason: '底栏第 $i 个 tab 未找到');
            _expectInside(
              screen,
              _globalBounds(tester, itemFinder),
              '底栏 tab $i',
            );
          }
          expect(
            tester.takeException(),
            isNull,
            reason: '底栏在 ${entry.key} 下溢出',
          );

          await _gotoPlanTab(tester);

          expect(find.byType(PlanView), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '计划页在 ${entry.key} / textScale ${scale}x 下渲染溢出',
          );

          // FAB 必须完整在屏幕内，且位于底栏之上（不与底栏重叠）
          final fabFinder = find.byType(FloatingActionButton);
          expect(fabFinder, findsOneWidget, reason: '计划页缺少 FAB');
          final fab = _globalBounds(tester, fabFinder);
          _expectInside(screen, fab, 'FAB');

          final navTop = List<double>.generate(
            _navLabels.length,
            (i) =>
                _globalBounds(tester, find.byKey(ValueKey('nav_item_$i'))).top,
          ).reduce((a, b) => a < b ? a : b);
          expect(
            fab.bottom,
            lessThanOrEqualTo(navTop + 0.5),
            reason: 'FAB 被底栏遮挡（fab.bottom=${fab.bottom}, navTop=$navTop）',
          );

          // 滚到底：最后一行内容不能被 FAB 压住（尾部留白 >= FAB 占位）
          _scrollToBottom(tester);
          await tester.pump();

          expect(tester.takeException(), isNull, reason: '计划页滚动到底时溢出');

          final lastLine = find.text('点击 + 添加任务');
          expect(lastLine, findsOneWidget);
          final lastBounds = _globalBounds(tester, lastLine);
          _expectInside(screen, lastBounds, '计划页最后一行内容');
          expect(
            lastBounds.bottom,
            lessThanOrEqualTo(fab.top + 0.5),
            reason:
                '尾部留白不足：最后一行内容被 FAB 遮挡'
                '（last.bottom=${lastBounds.bottom}, fab.top=${fab.top}）',
          );
        },
      );

      testWidgets(
        'plan page with tasks (${entry.key}, textScale ${scale}x) 任务卡不溢出且不被 FAB 遮挡',
        (tester) async {
          _setSize(tester, entry.value);
          _setTextScale(tester, scale);
          await _pumpApp(tester, seedTasks: _seedTasks());

          final screen = Rect.fromLTWH(
            0,
            0,
            entry.value.width,
            entry.value.height,
          );

          await _gotoPlanTab(tester);

          expect(find.byType(PlanView), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '计划页（有任务）在 ${entry.key} / ${scale}x 下渲染溢出',
          );

          // 长标题 + 高优先级 + 备注 + 已完成分组都进入布局后仍不溢出。
          // SliverList 懒构建：先滚到卡片可见，再断言几何位置。
          await _scrollUntilFound(tester, find.byType(TaskCard));
          expect(find.byType(TaskCard), findsWidgets, reason: '任务卡未渲染');
          expect(tester.takeException(), isNull, reason: '长标题任务卡渲染溢出');

          // 长标题只可能横向撑破卡片：断言卡片完整落在屏幕宽度内
          final cardRect = _globalBounds(tester, find.byType(TaskCard).first);
          expect(
            cardRect.left,
            greaterThanOrEqualTo(screen.left - 0.5),
            reason: '任务卡左边界超出屏幕（left=${cardRect.left}）',
          );
          expect(
            cardRect.right,
            lessThanOrEqualTo(screen.right + 0.5),
            reason: '任务卡右边界超出屏幕（right=${cardRect.right}）',
          );

          final fab = _globalBounds(tester, find.byType(FloatingActionButton));

          // 滚到底后，最后一张卡片必须整体位于 FAB 之上
          _scrollToBottom(tester);
          await tester.pump();

          expect(tester.takeException(), isNull, reason: '有任务时滚动到底溢出');

          final lastCard = _globalBounds(tester, find.byType(TaskCard).last);
          _expectInside(screen, lastCard, '最后一张任务卡');
          expect(
            lastCard.bottom,
            lessThanOrEqualTo(fab.top + 0.5),
            reason:
                '尾部留白不足：最后一张任务卡被 FAB 遮挡'
                '（card.bottom=${lastCard.bottom}, fab.top=${fab.top}）',
          );
        },
      );
    }
  }

  // 刘海屏 + 手势条：底栏必须整体落在安全区内，不被系统手势条压住。
  const notchTop = 24.0;
  const gestureBottom = 34.0;
  for (final scale in scales) {
    testWidgets('safe area (320x568, textScale ${scale}x) 底栏让出手势条', (
      tester,
    ) async {
      _setSize(tester, const Size(320, 568));
      _setSafeArea(tester, top: notchTop, bottom: gestureBottom);
      _setTextScale(tester, scale);
      await _pumpApp(tester);

      expect(tester.takeException(), isNull, reason: '安全区下底栏溢出');

      final safeBottom = 568 - gestureBottom;
      for (var i = 0; i < _navLabels.length; i++) {
        final rect = _globalBounds(tester, find.byKey(ValueKey('nav_item_$i')));
        expect(
          rect.top,
          greaterThanOrEqualTo(notchTop - 0.5),
          reason: 'tab $i 顶到刘海',
        );
        expect(
          rect.bottom,
          lessThanOrEqualTo(safeBottom + 0.5),
          reason:
              'tab $i 被手势条遮挡（bottom=${rect.bottom}, safeBottom=$safeBottom）',
        );
      }

      // 底栏内容不该被安全区挤压到溢出：5 个标签仍需可见
      for (final label in _navLabels) {
        expect(find.text(label), findsWidgets, reason: '安全区下丢失「$label」');
      }
    });
  }

  // 键盘弹起：目标编辑器（弹层）整体位于键盘之上，「保存」可滚动到并点中。
  testWidgets('goal editor sheet (320x568, textScale 2.0x) 键盘弹起时保存键可见', (
    tester,
  ) async {
    const size = Size(320, 568);
    const keyboard = 280.0;
    final keyboardTop = size.height - keyboard;
    _setSize(tester, size);
    _setTextScale(tester, 2.0);
    await _pumpApp(tester);
    await _gotoPlanTab(tester);

    _setKeyboardInset(tester, keyboard);
    // FakeViewPadding 写入后不会自动广播 metrics 变更，手动触发一次。
    tester.binding.handleMetricsChanged();
    await tester.pump();

    // 打开「每日目标」编辑弹层
    final goalHeader = find.text('每日目标');
    await _scrollUntilFound(tester, goalHeader);
    expect(goalHeader, findsOneWidget, reason: '未找到每日目标卡片');
    await tester.tap(goalHeader);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(tester.takeException(), isNull, reason: '键盘弹起时目标弹层溢出');
    expect(find.text('设置目标'), findsOneWidget, reason: '目标弹层未打开');

    final screen = Offset.zero & size;
    // 弹层必须整体落在键盘之上，不能被键盘盖住（弹层内容自身上限 = 键盘上方高度）
    final sheetRect = _globalBounds(tester, find.byType(BottomSheet));
    expect(
      sheetRect.bottom,
      lessThanOrEqualTo(keyboardTop + 0.5),
      reason: '目标弹层底部被键盘遮挡（sheetBottom=${sheetRect.bottom}）',
    );

    // 内容超出可用高度时应可滚动，滚到底后「保存」完整可见、可点。
    final saveButton = find.widgetWithText(FilledButton, '保存');
    expect(saveButton, findsOneWidget, reason: '目标弹层缺少保存按钮');
    await tester.ensureVisible(saveButton);
    await tester.pump();
    expect(tester.takeException(), isNull, reason: '滚动到保存键时弹层溢出');

    final saveRect = _globalBounds(tester, saveButton);
    expect(
      saveRect.bottom,
      lessThanOrEqualTo(keyboardTop + 0.5),
      reason: '保存按钮被键盘遮挡（bottom=${saveRect.bottom}, keyboardTop=$keyboardTop）',
    );
    _expectInside(screen, saveRect, '保存按钮');
  });
}
