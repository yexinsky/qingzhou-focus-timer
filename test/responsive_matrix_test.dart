import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/models/focus_session.dart';
import 'package:qingzhou_focus/data/models/task.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/router/app_router.dart';
import 'package:qingzhou_focus/views/college/college_view.dart';
import 'package:qingzhou_focus/views/college/widgets/college_segment_bar.dart';
import 'package:qingzhou_focus/views/feynman/feynman_setup_view.dart';
import 'package:qingzhou_focus/views/focus/focus_view.dart';
import 'package:qingzhou_focus/views/plan/plan_view.dart';
import 'package:qingzhou_focus/views/settings/settings_view.dart';
import 'package:qingzhou_focus/views/stats/stats_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

/// 全仓响应式回归矩阵（集成验收）。
///
/// 覆盖：5 个主 Tab 页（专注 / 计划 / 统计 / 院校 / 设置）+ 费曼设置页
///      × 5 档屏幕 {320x568, 360x640, 412x915, 640x360(横屏), 1097x617(平板横屏)}
///      × 3 档系统字体 {1.0, 1.4, 2.0}。
///
/// 断言口径（只验证"用户看得到、点得到"，不写死任何布局数字）：
///  - 逐页 `tester.takeException()` 必须为 null：任何 RenderFlex 溢出 /
///    ListTile trailing 断言 / 布局 assert 都算失败，并在 reason 里标出页名；
///  - 底栏 5 个入口 + 当前页主操作元素的全局矩形必须落在屏幕 0..宽 / 0..高 之内；
///  - 另外覆盖四个最容易翻车的真实场景：刘海屏 + 手势区安全区、键盘弹起、
///    底栏高度在切 tab 时不能跳变、计划页 FAB 不能被底栏压住。
///
/// pump 模板与 test/tablet_layout_test.dart 一致：专注页有无限循环的呼吸动画，
/// **禁止 pumpAndSettle**。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// 逻辑分辨率即屏幕 dp 尺寸（devicePixelRatio = 1.0），并设置系统字体缩放。
  void setViewport(WidgetTester tester, Size logicalSize, double textScale) {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// 模拟刘海（top）与手势条 / 三键导航栏（bottom）安全区。
  void setSafeArea(WidgetTester tester, {double top = 0, double bottom = 0}) {
    tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
    tester.view.viewPadding = FakeViewPadding(top: top, bottom: bottom);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
  }

  /// 整机 App：底栏、路由、真实页面链路都可用。
  ///
  /// appRouter 是全局单例（跨用例保留 location），所以每次先把位置重置回
  /// 专注页，保证每条用例起点一致。
  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final subjectRepository = SubjectRepository();
    await subjectRepository.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(_seededRepository()),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          subjectRepositoryProvider.overrideWithValue(subjectRepository),
        ],
        child: const QingzhouApp(),
      ),
    );
    // 专注页存在无限循环的呼吸动画，不能使用 pumpAndSettle
    await tester.pump(const Duration(milliseconds: 400));
    appRouter.go('/focus');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// 点底栏第 [index] 个入口切页（底栏项自带 ValueKey('nav_item_$index')，
  /// 比按文案定位稳：页面标题可能与标签同名）。
  Future<void> goToTab(WidgetTester tester, int index) async {
    final navItem = find.byKey(ValueKey('nav_item_$index'));
    expect(navItem, findsOneWidget, reason: '底栏第 $index 个入口必须存在');
    await tester.tap(navItem);
    await tester.pump(); // 路由切换
    await tester.pump(const Duration(milliseconds: 400)); // 转场动画
  }

  /// 逐阶段取出框架捕获的布局异常：非空即失败，reason 里回显异常文本。
  void expectNoLayoutError(WidgetTester tester, String scenario) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$scenario 出现布局异常：$error');
  }

  /// 断言控件完整落在屏幕内（用户能看到、能点到）。
  void expectInsideScreen(
    WidgetTester tester,
    Finder finder,
    Size screen, {
    required String label,
  }) {
    expect(finder, findsWidgets, reason: '$label 未渲染');
    final rect = tester.getRect(finder.first);
    expect(rect.top, greaterThanOrEqualTo(-0.5), reason: '$label 顶部越界: $rect');
    expect(
      rect.bottom,
      lessThanOrEqualTo(screen.height + 0.5),
      reason: '$label 底部越界: $rect',
    );
    expect(rect.left, greaterThanOrEqualTo(-0.5), reason: '$label 左侧越界: $rect');
    expect(
      rect.right,
      lessThanOrEqualTo(screen.width + 0.5),
      reason: '$label 右侧越界: $rect',
    );
  }

  /// 底栏 5 个入口都必须完整在屏内（这是任何页面的公共外壳）。
  void expectNavBarInsideScreen(
    WidgetTester tester,
    Size screen,
    String scenario,
  ) {
    for (var i = 0; i < 5; i++) {
      expectInsideScreen(
        tester,
        find.byKey(ValueKey('nav_item_$i')),
        screen,
        label: '$scenario 底栏第 $i 个入口',
      );
    }
  }

  /// 一页的验收组合：页面已渲染 + 无布局异常 + 主操作元素与底栏都在屏内。
  void expectPageHealthy(
    WidgetTester tester, {
    required Finder page,
    required Finder anchor,
    required Size screen,
    required String scenario,
  }) {
    expect(page, findsOneWidget, reason: '$scenario：页面应已渲染');
    expectNoLayoutError(tester, scenario);
    expectInsideScreen(tester, anchor, screen, label: '$scenario 主操作元素');
    expectNavBarInsideScreen(tester, screen, scenario);
  }

  // ------------------------------------------------------------ 主矩阵

  const sizes = <Size>[
    Size(320, 568), // 小屏手机
    Size(360, 640), // 主流手机
    Size(412, 915), // 大屏手机
    Size(640, 360), // 横屏
    Size(1097, 617), // 平板横屏
  ];
  const scales = <double>[1.0, 1.4, 2.0];

  for (final size in sizes) {
    for (final scale in scales) {
      final scenario =
          '${size.width.toInt()}x${size.height.toInt()} @textScale $scale';
      testWidgets('响应式矩阵 $scenario：5 主 Tab + 费曼设置页均无溢出', (tester) async {
        setViewport(tester, size, scale);
        await pumpApp(tester);

        // 1) 专注页：idle 态底部固定分钟栏是历史 bug 现场，必须可点
        expectPageHealthy(
          tester,
          page: find.byType(FocusView),
          anchor: find.text('25分钟'),
          screen: size,
          scenario: '$scenario 专注页',
        );

        // 2) 计划页：FAB 是主操作
        await goToTab(tester, 1);
        expectPageHealthy(
          tester,
          page: find.byType(PlanView),
          anchor: find.byType(FloatingActionButton),
          screen: size,
          scenario: '$scenario 计划页',
        );

        // 3) 统计页：整页滚动，标题在首屏
        await goToTab(tester, 2);
        expectPageHealthy(
          tester,
          page: find.byType(StatsView),
          anchor: find.text('数据统计'),
          screen: size,
          scenario: '$scenario 统计页',
        );

        // 4) 院校页：分段控件是唯一导航，必须完整可见
        await goToTab(tester, 3);
        expectPageHealthy(
          tester,
          page: find.byType(CollegeView),
          anchor: find.byType(CollegeSegmentBar),
          screen: size,
          scenario: '$scenario 院校页',
        );

        // 5) 设置页：整页滚动，标题与副标题在首屏
        await goToTab(tester, 4);
        expectPageHealthy(
          tester,
          page: find.byType(SettingsView),
          anchor: find.text('定制您的沉浸式学习仪式'),
          screen: size,
          scenario: '$scenario 设置页',
        );

        // 6) 费曼设置页（也在 ShellRoute 内，底栏仍在）
        appRouter.go('/feynman');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expectPageHealthy(
          tester,
          page: find.byType(FeynmanSetupView),
          anchor: find.text('先理解，再用自己的话讲清楚'),
          screen: size,
          scenario: '$scenario 费曼设置页',
        );
      });
    }
  }

  // ------------------------------------------- 专注页：分钟栏历史 bug 回归

  testWidgets('专注页 320x568 @2.0 首枚分钟胶囊在屏内，末枚可横向滚到', (tester) async {
    const size = Size(320, 568);
    setViewport(tester, size, 2.0);
    await pumpApp(tester);
    expectNoLayoutError(tester, '专注页首屏');

    // 历史 bug：Row 在水平滚动视口里居中会把第 1 枚胶囊推到负偏移、滚不回来
    expectInsideScreen(tester, find.text('25分钟'), size, label: '第 1 枚胶囊 25分钟');

    final horizontalScrollable = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable && widget.axisDirection == AxisDirection.right,
      description: '分钟栏横向滚动视口',
    );
    expect(horizontalScrollable, findsWidgets, reason: '分钟栏必须可横向滚动');
    await tester.drag(horizontalScrollable.first, const Offset(-400, 0));
    await tester.pump(const Duration(milliseconds: 300));
    expectInsideScreen(tester, find.text('60分钟'), size, label: '末枚胶囊 60分钟');
    expectNoLayoutError(tester, '分钟栏横向滚动后');
  });

  // ----------------------------------------- 安全区：刘海 + 手势条 / 导航栏

  testWidgets('360x640 刘海屏 + 手势区：底栏与专注页操作区都在安全区内', (tester) async {
    const size = Size(360, 640);
    const safeTop = 24.0;
    const safeBottom = 34.0;
    setViewport(tester, size, 1.4);
    setSafeArea(tester, top: safeTop, bottom: safeBottom);
    await pumpApp(tester);
    expectNoLayoutError(tester, '刘海屏专注页');

    // 底栏只能落在手势条之上（SafeArea 兜住 bottom）
    final navItem = tester.getRect(find.byKey(const ValueKey('nav_item_2')));
    expect(
      navItem.bottom,
      lessThanOrEqualTo(size.height - safeBottom + 0.5),
      reason: '底栏必须让出手势条 / 导航栏区域：$navItem',
    );
    // 内容区不能钻到刘海下面
    final chip = tester.getRect(find.text('25分钟'));
    expect(
      chip.top,
      greaterThanOrEqualTo(safeTop - 0.5),
      reason: '分钟栏不能进入刘海区域：$chip',
    );
    expectInsideScreen(tester, find.text('25分钟'), size, label: '分钟栏');

    // 每个 tab 在安全区下都完整可见
    expectNavBarInsideScreen(tester, size, '刘海屏');
  });

  // -------------------------------------------------- 键盘弹起（viewInsets）

  testWidgets('360x640 @2.0 键盘弹起（300dp）时专注页操作区仍在键盘之上', (tester) async {
    const size = Size(360, 640);
    const keyboard = 300.0;
    setViewport(tester, size, 2.0);
    tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.resetViewInsets);
    await pumpApp(tester);
    expectNoLayoutError(tester, '键盘弹起专注页');

    // 键盘顶边之上才是用户真正能看到的区域
    const visible = Size(360, 640 - keyboard);
    // 分钟栏随内容滚动（不再是贴底的固定工具栏），因此验收口径是
    // 「能滚进键盘之上的可视区」而不是「首屏就必须在可视区内」。
    await tester.ensureVisible(find.text('25分钟'));
    await tester.pump(const Duration(milliseconds: 300));
    expectInsideScreen(tester, find.text('25分钟'), visible, label: '分钟栏（键盘之上）');
    expectNoLayoutError(tester, '键盘弹起滚动后');
  });

  // ------------------------------------------------ 底栏高度在切 tab 时不跳变

  testWidgets('320x568 @2.0 切 tab 时底栏高度保持恒定', (tester) async {
    setViewport(tester, const Size(320, 568), 2.0);
    await pumpApp(tester);

    double navHeight() =>
        tester.getRect(find.byKey(const ValueKey('nav_item_0'))).height;
    final initial = navHeight();
    expect(initial, greaterThan(0), reason: '底栏必须真实占位');

    for (final index in const [1, 2, 3, 4, 0]) {
      await goToTab(tester, index);
      expectNoLayoutError(tester, '切换到第 $index 个 tab');
      expect(
        navHeight(),
        closeTo(initial, 0.5),
        reason: '切到第 $index 个 tab 后底栏高度不应跳变（body 高度会跟着抖）',
      );
    }
  });

  // ------------------------------------------- 计划页：FAB 与底栏不互相遮挡

  testWidgets('640x360 @2.0 计划页 FAB 完整在屏内且不被底栏压住', (tester) async {
    const size = Size(640, 360);
    setViewport(tester, size, 2.0);
    await pumpApp(tester);
    await goToTab(tester, 1);
    expectNoLayoutError(tester, '计划页');

    final fab = tester.getRect(find.byType(FloatingActionButton));
    final navItem = tester.getRect(find.byKey(const ValueKey('nav_item_2')));
    expect(
      fab.bottom,
      lessThanOrEqualTo(size.height + 0.5),
      reason: 'FAB 越出屏幕底边',
    );
    expect(
      fab.right,
      lessThanOrEqualTo(size.width + 0.5),
      reason: 'FAB 越出屏幕右边',
    );
    expect(
      fab.bottom,
      lessThanOrEqualTo(navItem.top + 0.5),
      reason: 'FAB 与底栏重叠（fab=$fab, navItem=$navItem）',
    );

    // 尾部留白按 FAB 真实占位计算：滚到底时最后内容不能被 FAB 压住
    final planScrollable = find
        .descendant(
          of: find.byType(PlanView),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.drag(planScrollable, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(planScrollable, const Offset(0, -400));
    await tester.pump(const Duration(milliseconds: 300));
    expectNoLayoutError(tester, '计划页滚动到底');
  });

  // -------------------------------------- 费曼设置页：底部按钮必须能滚到屏内

  testWidgets('320x568 @2.0 费曼设置页底部按钮可滚到屏内', (tester) async {
    const size = Size(320, 568);
    setViewport(tester, size, 2.0);
    await pumpApp(tester);
    appRouter.go('/feynman');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expectNoLayoutError(tester, '费曼设置页进入');

    final setup = find.byType(FeynmanSetupView);
    final scrollable = find
        .descendant(of: setup, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      find.text('查看卡点热力图'),
      120,
      scrollable: scrollable,
      maxScrolls: 80,
    );
    await tester.pump(const Duration(milliseconds: 200));
    expectInsideScreen(tester, find.text('查看卡点热力图'), size, label: '查看卡点热力图');
    expectNoLayoutError(tester, '费曼设置页滚动到底');
  });
}

/// 计划页会读 `monthTaskDateKeysProvider`（→ getTaskDateKeysInMonth），
/// 共享的 TestTaskRepository 没覆盖该方法，会落到真实实现里访问未初始化的
/// Hive box；这里在矩阵内补齐（与 test/plan_responsive_test.dart 同思路）。
class _MatrixTaskRepository extends TestTaskRepository {
  @override
  Set<String> getTaskDateKeysInMonth(String monthKey) => {
    for (final task in tasks.values)
      if (task.dateKey.startsWith(monthKey)) task.dateKey,
  };
}

String _dateKeyOf(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// 铺一点真实数据：空列表时计划页的任务卡、统计页的图表 / 最近记录都不渲染，
/// 覆盖不到"长标题 + 多行列表 + 大数值"这些最容易溢出的形态。
_MatrixTaskRepository _seededRepository() {
  final repo = _MatrixTaskRepository();
  final now = DateTime.now();
  final today = _dateKeyOf(now);

  repo.tasks['t-matrix-1'] = Task(
    id: 't-matrix-1',
    title: '复习高等数学第三章：多元函数微分学与方向导数',
    subject: '数学',
    dateKey: today,
    createdAt: now.millisecondsSinceEpoch,
    priority: 2,
    note: '重点看梯度与方向导数的几何意义，再做两套真题巩固',
    estimatedPomodoros: 3,
  );
  repo.tasks['t-matrix-2'] = Task(
    id: 't-matrix-2',
    title: '英语阅读真题',
    subject: '英语',
    completed: true,
    dateKey: today,
    createdAt: now.millisecondsSinceEpoch - 1000,
  );

  const subjects = ['政治', '英语', '数学', '专业课'];
  const durations = [1500, 2700, 3600, 5400];
  for (var i = 0; i < durations.length; i++) {
    final day = now.subtract(Duration(days: i));
    repo.sessions['s-matrix-$i'] = FocusSession(
      id: 's-matrix-$i',
      taskId: 't-matrix-1',
      taskTitle: '考研数学真题第${i + 1}套模拟练习',
      subject: subjects[i % subjects.length],
      startTime: day.millisecondsSinceEpoch,
      duration: durations[i],
      type: 'focus',
      dateKey: _dateKeyOf(day),
    );
  }
  return repo;
}
