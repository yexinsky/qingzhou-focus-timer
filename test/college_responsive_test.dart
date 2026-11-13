import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/repositories/college_preference_repository.dart';
import 'package:qingzhou_focus/data/repositories/discipline_repository.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/data/repositories/university_repository.dart';
import 'package:qingzhou_focus/providers/college_preference_provider.dart';
import 'package:qingzhou_focus/providers/discipline_provider.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/providers/university_provider.dart';
import 'package:qingzhou_focus/views/college/college_view.dart';
import 'package:qingzhou_focus/views/college/goal_pane.dart';
import 'package:qingzhou_focus/views/college/widgets/college_segment_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

/// 院校页多端布局回归（t4）。
///
/// 覆盖矩阵：320x568（小屏）/ 360x640（主流竖屏）/ 640x360（横屏）
/// × textScale 1.0 / 2.0（系统字体放大）。
///
/// 断言口径：
///  - 三段式布局在矮屏下不把面板压成 0，也不产生 RenderFlex 溢出；
///  - 分段控件（页面唯一导航）始终完整落在屏幕内；
///  - 目标分段的『考研倒计时』卡片、专业代码的条目、三个弹窗在
///    小屏 + 大字体 + 键盘弹起时都不会被裁到屏幕外。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void setViewport(WidgetTester tester, Size logicalSize, double textScale) {
    tester.view.physicalSize = logicalSize;
    tester.view.devicePixelRatio = 1.0;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  /// 整机 App：底栏可用、路由可跳（用于验证「底栏进入院校页」的真实链路）。
  Future<void> pumpApp(WidgetTester tester) async {
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

  bool isCollegeFailure(Object exception) {
    final text = exception.toString();
    return text.contains('views/college') ||
        text.contains('views\\college') ||
        text.contains('UniversityCard');
  }

  /// 取走当前挂起的异常，**只把院校页的算作失败**。
  ///
  /// 这里刻意不去改写 FlutterError.onError（改写后若不还原，框架会在
  /// 收尾时断言「测试 override 了 onError 却没恢复」）。用 takeException
  /// 取走即可：若异常来自其它页面（并行改版的专注页 / 计划页在极端字号
  /// 下的溢出），不属于本文件作用域，不判失败；来自院校页则直接报错。
  void expectNoCollegeOverflow(WidgetTester tester, String scenario) {
    final pending = tester.takeException();
    if (pending == null) {
      return;
    }
    expect(
      isCollegeFailure(pending),
      isFalse,
      reason: '$scenario：院校页不允许出现布局溢出，实际异常：\n$pending',
    );
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

  // ---------------------------------------------------------------- 测试数据

  const rankingJson = '''
{
  "meta": {"source": "软科中国大学排名（主榜）", "year": 2026, "generatedAt": "2026-04-01T00:00:00", "count": 4},
  "universities": [
    {"rank": "1", "name": "清华大学", "tags": ["双一流", "985", "211"], "province": "北京", "category": "综合", "score": "1087.1"},
    {"rank": "40", "name": "南京理工大学", "tags": ["211"], "province": "江苏", "category": "理工", "score": "312.6"},
    {"rank": "500+", "name": "中国科学院大学附属超长校名测试学院", "tags": ["双一流"], "province": "北京", "category": "综合", "score": null},
    {"rank": "88", "name": "郑州师范学院", "tags": [], "province": "河南", "category": "师范", "score": null}
  ]
}
''';

  const disciplineJson = '''
{
  "meta": {"source": "研究生教育学科专业目录（2022年）", "issuer": "教育部", "edition": 2022, "academicCount": 1, "professionalCount": 1},
  "categories": [
    {"code": "08", "name": "工学", "items": [
      {"code": "0812", "name": "计算机科学与技术", "type": "academic", "note": "同时设专业学位类别，代码为 0854"},
      {"code": "0854", "name": "电子信息", "type": "professional", "doctoral": true}
    ]}
  ]
}
''';

  Future<void> pumpCollegeView(
    WidgetTester tester, {
    String segment = 'ranking',
  }) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          universityRepositoryProvider.overrideWithValue(
            UniversityRepository(bundle: _StringAssetBundle(rankingJson)),
          ),
          disciplineRepositoryProvider.overrideWithValue(
            DisciplineRepository(bundle: _StringAssetBundle(disciplineJson)),
          ),
          collegePreferenceRepositoryProvider.overrideWithValue(
            CollegePreferenceRepository(),
          ),
          // 直接落在指定分段：小屏 + 超大字体下分段控件文字可能被压缩，
          // 用点按切段会引入与被测布局无关的点击命中不确定性。
          collegeSegmentProvider.overrideWith((ref) => segment),
        ],
        child: const MaterialApp(home: CollegeView()),
      ),
    );
    // 第一帧加载态，后续帧等资产解析 / 首帧布局完成
    await tester.pump();
    await tester.pump();
  }

  // ---------------------------------------------- 1) 整机链路：底栏进院校页

  const sizes = <Size>[Size(320, 568), Size(360, 640), Size(640, 360)];

  for (final size in sizes) {
    for (final textScale in const [1.0, 2.0]) {
      testWidgets('从底栏进入院校页不溢出 ${size.width.toInt()}x${size.height.toInt()} '
          '(textScale $textScale)', (tester) async {
        setViewport(tester, size, textScale);
        await pumpApp(tester);

        // 底栏项自带 ValueKey('nav_item_3')（MainShell），比按文案定位稳：
        // 矮屏之外的尺寸下页面标题也叫「院校」，按文案会命中两个。
        final navItem = find.byKey(const ValueKey('nav_item_3'));
        expect(navItem, findsOneWidget, reason: '底栏『院校』入口必须存在');
        await tester.tap(navItem);
        await tester.pump(); // 路由切换
        await tester.pump(const Duration(milliseconds: 400)); // 转场动画

        expect(find.byType(CollegeView), findsOneWidget, reason: '院校页应已渲染');
        // 分段控件是院校页唯一的导航，任何尺寸 / 字号下都必须完整可见
        expectInsideScreen(
          tester,
          find.byType(CollegeSegmentBar),
          size,
          label: '院校分段控件',
        );
        expectNoCollegeOverflow(
          tester,
          '${size.width.toInt()}x${size.height.toInt()} / textScale $textScale',
        );
      });
    }
  }

  // ------------------------------------ 2) 目标分段：考研倒计时卡片不溢出

  for (final size in sizes) {
    for (final textScale in const [1.0, 2.0]) {
      testWidgets(
        '目标分段不溢出且考研倒计时可见 ${size.width.toInt()}x${size.height.toInt()} '
        '(textScale $textScale)',
        (tester) async {
          setViewport(tester, size, textScale);
          await pumpCollegeView(tester, segment: 'goals');

          expect(find.text('考研倒计时'), findsOneWidget);
          expectInsideScreen(
            tester,
            find.text('考研倒计时'),
            size,
            label: '考研倒计时标签',
          );
          expect(
            tester.takeException(),
            isNull,
            reason:
                '目标分段在 ${size.width.toInt()}x${size.height.toInt()}dp / '
                'textScale $textScale 下不允许出现布局溢出',
          );
        },
      );
    }
  }

  // ------------------------------------- 3) 专业代码：窄屏大字体序号列不挤压

  testWidgets('专业代码 320x568 @textScale 2.0 展开后不溢出', (tester) async {
    setViewport(tester, const Size(320, 568), 2.0);
    await pumpCollegeView(tester);

    await tester.tap(find.text('专业代码'));
    await tester.pump();
    await tester.pump();

    expect(find.text('08 工学'), findsOneWidget);
    await tester.ensureVisible(find.text('08 工学'));
    await tester.pump();
    await tester.tap(find.text('08 工学'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('0812'), findsOneWidget);
    expect(find.text('计算机科学与技术'), findsOneWidget);
    // 代码列改为「内容定宽 + 本行 1/3 上限」，大字体下也不会把名称挤成竖排
    expect(tester.getSize(find.text('0812')).width, lessThanOrEqualTo(320 / 3));
    expect(tester.takeException(), isNull, reason: '专业代码在窄屏大字体下不允许溢出');
  });

  // ------------------------------------------- 4) 目标选择弹窗：小屏 / 横屏

  for (final size in const [Size(320, 568), Size(640, 360)]) {
    testWidgets('目标选择弹窗可滚动且不越界 ${size.width.toInt()}x${size.height.toInt()} '
        '(textScale 2.0)', (tester) async {
      setViewport(tester, size, 2.0);
      await pumpCollegeView(tester, segment: 'goals');

      await tester.tap(find.text('选择'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('选择目标院校'), findsOneWidget);
      expectInsideScreen(tester, find.text('选择目标院校'), size, label: '目标院校弹窗标题');
      expect(tester.takeException(), isNull, reason: '目标选择弹窗不允许溢出');

      // 内容整体可滚动：向上拖动后依旧不溢出，列表项可达
      await tester.drag(find.text('选择目标院校'), const Offset(0, -160));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull, reason: '目标选择弹窗滚动后不允许溢出');
    });
  }

  // ------------------------------- 5) 添加里程碑弹窗：横屏 + 键盘弹起仍可见

  testWidgets('添加里程碑弹窗 640x360 键盘弹起时按钮仍可见', (tester) async {
    setViewport(tester, const Size(640, 360), 2.0);
    // 模拟输入法弹起：Scaffold 收缩 + 弹窗底部 padding 需自行避让键盘
    tester.view.viewInsets = const FakeViewPadding(bottom: 200);
    addTearDown(tester.view.resetViewInsets);
    await pumpCollegeView(tester, segment: 'goals');

    // 横屏 + 大字体下里程碑卡片在首屏之外，ListView 懒加载还没建出『添加』。
    // 这里显式滚动「目标分段自己的」滚动视图（矮屏时标题区也是可滚的，
    // 直接找全局第一个 Scrollable 会拖错对象）。
    final paneScrollable = find
        .descendant(
          of: find.byType(GoalPane),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('添加'),
      120,
      scrollable: paneScrollable,
    );
    await tester.pump();
    await tester.tap(find.text('添加'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('添加里程碑'), findsWidgets);
    // 「添加里程碑」按钮固定在弹窗底部：即使表单区需要滚动，它也在屏内
    expectInsideScreen(
      tester,
      find.widgetWithText(FilledButton, '添加里程碑'),
      const Size(640, 360),
      label: '添加里程碑按钮',
    );
    expect(tester.takeException(), isNull, reason: '添加里程碑弹窗在键盘弹起时不允许溢出');

    // 表单可滚动：输入框区域滚动后按钮依然固定可见。
    // 拖动落在弹窗内层的滚动区上——键盘区域（y > 160）无法命中，
    // 直接拖输入框会触发「offset 不命中」警告。
    await tester.drag(
      find.byType(SingleChildScrollView).last,
      const Offset(0, -60),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expectInsideScreen(
      tester,
      find.widgetWithText(FilledButton, '添加里程碑'),
      const Size(640, 360),
      label: '添加里程碑按钮（滚动后）',
    );
    expect(tester.takeException(), isNull, reason: '添加里程碑弹窗滚动后不允许溢出');
  });

  // ------------------------------------- 6) 省份筛选弹窗：固定 360 的回归点

  for (final scenario in const <(Size, double)>[
    (Size(360, 640), 1.0),
    (Size(640, 360), 2.0),
  ]) {
    final size = scenario.$1;
    final textScale = scenario.$2;
    testWidgets('省份筛选弹窗不越界 ${size.width.toInt()}x${size.height.toInt()} '
        '(textScale $textScale)', (tester) async {
      setViewport(tester, size, textScale);
      await pumpCollegeView(tester);

      final provinceButton = find.text('省份');
      await tester.ensureVisible(provinceButton);
      await tester.pump();
      await tester.tap(provinceButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('选择省份'), findsOneWidget);
      expectInsideScreen(tester, find.text('选择省份'), size, label: '省份弹窗标题');
      expect(find.text('全部'), findsWidgets);
      expect(tester.takeException(), isNull, reason: '省份筛选弹窗不允许溢出');
    });
  }
}

class _StringAssetBundle extends AssetBundle {
  _StringAssetBundle(this.json);

  final String json;

  @override
  Future<String> loadString(String key, {bool cache = true}) async => json;

  @override
  Future<ByteData> load(String key) async =>
      ByteData.sublistView(Uint8List.fromList(utf8.encode(json)));
}
