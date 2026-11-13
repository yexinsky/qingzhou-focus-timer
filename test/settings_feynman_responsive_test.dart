import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/models/feynman_unit.dart';
import 'package:qingzhou_focus/data/models/focus_session.dart';
import 'package:qingzhou_focus/data/models/stumble_mark.dart';
import 'package:qingzhou_focus/data/repositories/feynman_repository.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/feynman_provider.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/router/app_router.dart';
import 'package:qingzhou_focus/views/feynman/feynman_heatmap_view.dart';
import 'package:qingzhou_focus/views/feynman/feynman_review_view.dart';
import 'package:qingzhou_focus/views/feynman/feynman_session_view.dart';
import 'package:qingzhou_focus/views/feynman/feynman_setup_view.dart';
import 'package:qingzhou_focus/views/history/session_history_view.dart';
import 'package:qingzhou_focus/views/settings/settings_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

/// 设置页 / 费曼页 / 专注历史页的多端布局回归（t6）。
///
/// 覆盖矩阵：320x568（小屏）/ 640x360（横屏）× textScale 1.0 / 2.0（系统字体放大），
/// 以及「键盘弹起（viewInsets）」这一最容易把底部按钮顶出屏幕的场景。
///
/// 断言口径（不写死任何宽高，只验证"用户看得到、点得到"）：
///  - 进入每一页、以及把可滚内容滚到底时，都不产生布局异常（RenderFlex 溢出 /
///    ListTile trailing 吃掉整行等）；错误由 takeException 逐阶段取出，
///    失败信息里带阶段名，便于定位是哪一页哪一步炸的；
///  - 底部按钮（『开始输入理解』『结束并复盘』『需要返回重读』）必须能滚到屏幕内；
///  - 专注历史的超长任务名 + 大字体不再把标题/时间挤爆。
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

  /// 整机 App：底栏、路由、真实页面链路都可用。
  ///
  /// appRouter 是全局单例（会跨用例保留当前 location），因此每次先把
  /// 位置重置回专注页，保证每条用例的起点一致。
  Future<void> pumpApp(
    WidgetTester tester, {
    TestTaskRepository? taskRepository,
    _MemoryFeynmanRepository? feynmanRepository,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final subjectRepository = SubjectRepository();
    await subjectRepository.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(
            taskRepository ?? TestTaskRepository(),
          ),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          subjectRepositoryProvider.overrideWithValue(subjectRepository),
          // 费曼仓库的真实实现依赖 Hive 落盘；这里换成内存替身，
          // 让「设置页 → 费曼设置页」的整条链路无需写盘即可渲染。
          feynmanRepositoryProvider.overrideWithValue(
            feynmanRepository ?? _MemoryFeynmanRepository(),
          ),
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

  /// 逐阶段取出框架捕获的布局异常：非空即失败，并在 reason 里回显异常文本。
  void expectNoLayoutError(WidgetTester tester, String scenario) {
    final error = tester.takeException();
    expect(error, isNull, reason: '$scenario 出现布局异常：$error');
  }

  /// 在 [within] 这一页内部滚动，直到 [target] 被真实构建出来（可滚动布局的核心能力）。
  Future<void> scrollTo(
    WidgetTester tester,
    Finder target, {
    required Finder within,
    double delta = 120,
  }) async {
    final scrollable = find
        .descendant(of: within, matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(
      target,
      delta,
      scrollable: scrollable,
      maxScrolls: 80,
    );
    await tester.pump(const Duration(milliseconds: 200));
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
    expect(
      rect.top,
      greaterThanOrEqualTo(-0.5),
      reason: '$label 顶部越出屏幕: $rect',
    );
    expect(
      rect.bottom,
      lessThanOrEqualTo(screen.height + 0.5),
      reason: '$label 底部越出屏幕: $rect',
    );
    expect(
      rect.left,
      greaterThanOrEqualTo(-0.5),
      reason: '$label 左侧越出屏幕: $rect',
    );
    expect(
      rect.right,
      lessThanOrEqualTo(screen.width + 0.5),
      reason: '$label 右侧越出屏幕: $rect',
    );
  }

  const sizes = <Size>[Size(320, 568), Size(640, 360)];
  const scales = <double>[1.0, 2.0];
  final settingsNav = find.byKey(const ValueKey('nav_item_4'));

  String labelOf(Size size, double scale) =>
      '${size.width.toInt()}x${size.height.toInt()} / textScale $scale';

  // ------------------------------------------ 1) 设置页 → 费曼设置页 真实链路

  for (final size in sizes) {
    for (final scale in scales) {
      final scenario = labelOf(size, scale);
      testWidgets('设置页与费曼设置页无溢出（$scenario）', (tester) async {
        setViewport(tester, size, scale);
        await pumpApp(tester);
        expectNoLayoutError(tester, '$scenario 专注页首屏');

        // 底栏进入设置页
        await tester.tap(settingsNav);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SettingsView), findsOneWidget, reason: '设置页应已渲染');
        expect(find.text('定制您的沉浸式学习仪式'), findsOneWidget);
        expectNoLayoutError(tester, '$scenario 设置页进入');

        // 设置页是「整页滚动」：一路滚到底（页脚版本号 / 隐私声明）
        await scrollTo(
          tester,
          find.text('隐私政策与服务条款将在正式发布前提供'),
          within: find.byType(SettingsView),
        );
        expect(
          find.text('隐私政策与服务条款将在正式发布前提供'),
          findsOneWidget,
          reason: '页脚应能滚到屏幕内',
        );
        expectNoLayoutError(tester, '$scenario 设置页滚动到底');

        // 费曼设置页（/feynman 也在 ShellRoute 内，底栏仍在）
        appRouter.go('/feynman');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byType(FeynmanSetupView),
          findsOneWidget,
          reason: '费曼设置页应已渲染',
        );
        expectNoLayoutError(tester, '$scenario 费曼设置页进入');

        // 表单整体滚动：两个下拉框 + 底部按钮都能滚进屏幕
        final setup = find.byType(FeynmanSetupView);
        await scrollTo(tester, find.text('开始输入理解'), within: setup);
        expectInsideScreen(tester, find.text('开始输入理解'), size, label: '开始输入理解');
        await scrollTo(tester, find.text('查看卡点热力图'), within: setup);
        expectInsideScreen(
          tester,
          find.text('查看卡点热力图'),
          size,
          label: '查看卡点热力图',
        );
        expectNoLayoutError(tester, '$scenario 费曼设置页滚动到底');
      });
    }
  }

  // ------------------------------------------- 2) 专注历史：长标题 / 大字体

  for (final size in sizes) {
    for (final scale in scales) {
      final scenario = labelOf(size, scale);
      testWidgets('专注历史长标题不溢出（$scenario）', (tester) async {
        setViewport(tester, size, scale);
        final repository = TestTaskRepository();
        final now = DateTime.now().millisecondsSinceEpoch;
        repository.sessions['s1'] = FocusSession(
          id: 's1',
          taskTitle: '整理线性代数第五章的笔记并推导特征值与特征向量的几何意义',
          subject: '数学',
          startTime: now,
          duration: 1500,
          type: 'focus',
          dateKey: '2026-11-13',
        );
        repository.sessions['s2'] = FocusSession(
          id: 's2',
          subject: '数据结构与算法',
          startTime: now - 3600 * 1000,
          duration: 45,
          type: 'focus',
          dateKey: '2026-11-13',
          timerMode: 'stopwatch',
        );
        repository.sessions['s3'] = FocusSession(
          id: 's3',
          subject: '英语',
          startTime: now - 7200 * 1000,
          duration: 45 * 60,
          type: 'focus',
          dateKey: '2026-11-13',
        );
        await pumpApp(tester, taskRepository: repository);
        expectNoLayoutError(tester, '$scenario 专注页首屏');

        await tester.tap(settingsNav);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(find.byType(SettingsView), findsOneWidget);

        final settings = find.byType(SettingsView);
        await scrollTo(tester, find.text('专注历史'), within: settings);
        await tester.tap(find.text('专注历史'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          find.byType(SessionHistoryView),
          findsOneWidget,
          reason: '专注历史页应已渲染',
        );
        // 超长任务名完整保留在文本里（只是按 2 行省略显示），没被丢弃
        expect(find.text('整理线性代数第五章的笔记并推导特征值与特征向量的几何意义'), findsOneWidget);
        expectNoLayoutError(tester, '$scenario 专注历史页');

        // 列表是懒构建的：滚到后面几条，校验「无标题记录 → 自由专注」与
        // 各种时长文案（秒 / 分钟）都还在，且滚动过程不产生溢出
        final history = find.byType(SessionHistoryView);
        await scrollTo(tester, find.text('45 秒'), within: history);
        expect(find.text('自由专注'), findsWidgets);
        expect(find.text('45 秒'), findsOneWidget);
        await scrollTo(tester, find.text('45 分钟'), within: history);
        expect(find.text('45 分钟'), findsOneWidget);
        // 再往下拉一把，确认到底部（含底部安全区留白）时也没有溢出
        await tester.drag(
          find.byType(SessionHistoryView),
          const Offset(0, -300),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expectNoLayoutError(tester, '$scenario 专注历史页滚动到底');
      });
    }
  }

  // ------------------------- 3) 费曼讲解 / 复盘 / 热力图：键盘弹起与展开态

  Future<void> pumpStandalone(
    WidgetTester tester,
    Widget view,
    _MemoryFeynmanRepository repository,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [feynmanRepositoryProvider.overrideWithValue(repository)],
        child: MaterialApp(home: view),
      ),
    );
    await tester.pump();
  }

  for (final size in sizes) {
    final scenario = labelOf(size, 2.0);
    testWidgets('费曼讲解键盘弹起时按钮可达（$scenario）', (tester) async {
      setViewport(tester, size, 2.0);
      // 模拟输入法弹起：Scaffold 把 body 压到键盘上方，页面需自行切换紧凑排版
      tester.view.viewInsets = FakeViewPadding(bottom: size.height * 0.45);
      addTearDown(tester.view.resetViewInsets);

      final now = DateTime.now().millisecondsSinceEpoch;
      final repository = _MemoryFeynmanRepository(
        units: [
          FeynmanUnit(
            id: 'u1',
            title: '用最简单的话解释协方差矩阵在卡尔曼滤波里的传播',
            subject: '控制理论',
            startedAt: now,
            phase: 'output',
            phaseStartedAt: now,
          ),
        ],
      );
      await pumpStandalone(tester, const FeynmanSessionView(), repository);
      expectNoLayoutError(tester, '$scenario 费曼讲解页渲染');

      final session = find.byType(FeynmanSessionView);
      final done = find.text('结束并复盘');
      await scrollTo(tester, done, within: session);
      expectInsideScreen(tester, done, size, label: '结束并复盘');
      expectInsideScreen(tester, find.text('卡壳了'), size, label: '卡壳了');
      expectNoLayoutError(tester, '$scenario 费曼讲解页（键盘弹起）');
    });
  }

  testWidgets('费曼复盘 640x360 @textScale 2.0 三个按钮可滚到底', (tester) async {
    setViewport(tester, const Size(640, 360), 2.0);
    final now = DateTime.now().millisecondsSinceEpoch;
    final repository = _MemoryFeynmanRepository(
      units: [
        FeynmanUnit(
          id: 'u2',
          title: '复述快速排序的分区过程与最坏时间复杂度',
          subject: '数据结构与算法',
          startedAt: now,
          phase: 'review',
          accumulatedPhaseSeconds: 300,
        ),
      ],
    );
    await pumpStandalone(tester, const FeynmanReviewView(), repository);
    expectNoLayoutError(tester, '费曼复盘页渲染');

    final review = find.byType(FeynmanReviewView);
    await scrollTo(tester, find.text('已经讲清楚'), within: review);
    expectInsideScreen(
      tester,
      find.text('已经讲清楚'),
      const Size(640, 360),
      label: '已经讲清楚',
    );
    await scrollTo(tester, find.text('需要返回重读'), within: review);
    expectInsideScreen(
      tester,
      find.text('需要返回重读'),
      const Size(640, 360),
      label: '需要返回重读',
    );
    expectNoLayoutError(tester, '费曼复盘页滚动到底');
  });

  testWidgets('卡点热力图 320x568 @textScale 2.0 分数与展开项不溢出', (tester) async {
    setViewport(tester, const Size(320, 568), 2.0);
    final now = DateTime.now().millisecondsSinceEpoch;
    final repository = _MemoryFeynmanRepository(
      marks: [
        StumbleMark(
          id: 'm1',
          unitId: 'u1',
          subject: '数学',
          chapter: '线性代数',
          keyword: '特征值出现重根时的对角化条件',
          reason: '推导中断',
          note: '忘记先验证几何重数',
          offsetSeconds: 421,
          createdAt: now,
          severity: 3,
        ),
        StumbleMark(
          id: 'm2',
          unitId: 'u1',
          subject: '数学',
          chapter: '线性代数',
          keyword: '正交矩阵的定义',
          offsetSeconds: 88,
          createdAt: now - 1000,
        ),
        StumbleMark(
          id: 'm3',
          unitId: 'u1',
          subject: '数学',
          keyword: '内积空间的完备性',
          offsetSeconds: 12,
          createdAt: now - 2000,
        ),
      ],
    );
    await pumpStandalone(tester, const FeynmanHeatmapView(), repository);
    expectNoLayoutError(tester, '卡点热力图渲染');
    expect(find.text('线性代数'), findsOneWidget);
    expect(find.text('未分类'), findsOneWidget);

    // 展开分组：勾选行（CheckboxListTile）的长副标题在大字体窄屏下也不能溢出
    await tester.tap(find.text('线性代数'));
    await tester.pump(const Duration(milliseconds: 400));
    final heatmap = find.byType(FeynmanHeatmapView);
    await scrollTo(tester, find.text('特征值出现重根时的对角化条件'), within: heatmap);
    expect(find.text('特征值出现重根时的对角化条件'), findsOneWidget);
    expectNoLayoutError(tester, '卡点热力图展开');
  });
}

/// 内存版费曼仓库：真实实现要开 Hive box，布局测试只关心渲染，
/// 因此把读写落到内存列表（与 test/helpers 里 TestTaskRepository 同一思路）。
class _MemoryFeynmanRepository extends FeynmanRepository {
  _MemoryFeynmanRepository({
    List<FeynmanUnit> units = const [],
    List<StumbleMark> marks = const [],
  }) : _units = [...units],
       _marks = [...marks];

  final List<FeynmanUnit> _units;
  final List<StumbleMark> _marks;

  @override
  List<FeynmanUnit> get units =>
      _units.toList()..sort((a, b) => b.startedAt.compareTo(a.startedAt));

  @override
  List<StumbleMark> get marks =>
      _marks.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  FeynmanUnit? get activeUnit {
    for (final unit in _units) {
      if (unit.status == 'active') return unit;
    }
    return null;
  }

  @override
  Future<void> saveUnit(FeynmanUnit unit) async {
    _units
      ..removeWhere((item) => item.id == unit.id)
      ..add(unit);
  }

  @override
  Future<void> saveMark(StumbleMark mark) async {
    _marks
      ..removeWhere((item) => item.id == mark.id)
      ..add(mark);
  }

  @override
  Future<void> deleteMark(String id) async =>
      _marks.removeWhere((item) => item.id == id);

  @override
  Future<void> clear() async {
    _units.clear();
    _marks.clear();
  }
}
