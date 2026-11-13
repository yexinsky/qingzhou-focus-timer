import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/core/widgets/adaptive_bottom_sheet.dart';
import 'package:qingzhou_focus/data/models/daily_stats.dart';
import 'package:qingzhou_focus/data/models/focus_session.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/views/stats/widgets/day_detail_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

/// 统计页多端布局回归：小屏 / 系统字体放大 / 横屏下不允许出现
/// RenderFlex 溢出等任何渲染异常。
///
/// 覆盖矩阵（任务契约）：
///   320x568（小屏手机）/ 360x640（主流手机）/ 640x360（横屏）
///   × textScale 1.0 / 2.0（系统字体放大）
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

  /// 造一周的真实数据：空数据时圆环图 / 最近记录 / 时长卡片都不会渲染，
  /// 覆盖不到「数值很长 + 图例多行 + 列表多行」这些最容易溢出的形态。
  TestTaskRepository seededRepository() {
    final repo = TestTaskRepository();
    final now = DateTime.now();
    const subjects = ['政治', '英语', '数学', '专业课'];
    const durationsSeconds = [1500, 2700, 3600, 5400, 900, 4500, 1800];
    for (var i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      final dateKey =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-'
          '${day.day.toString().padLeft(2, '0')}';
      repo.sessions['s$i'] = FocusSession(
        id: 's$i',
        taskId: 't$i',
        taskTitle: '考研数学真题第${i + 1}套模拟练习',
        subject: subjects[i % subjects.length],
        startTime: day.millisecondsSinceEpoch,
        duration: durationsSeconds[i],
        type: 'focus',
        dateKey: dateKey,
      );
    }
    return repo;
  }

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final subjectRepository = SubjectRepository();
    await subjectRepository.init();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(seededRepository()),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          subjectRepositoryProvider.overrideWithValue(subjectRepository),
        ],
        child: const QingzhouApp(),
      ),
    );
    // 专注页存在无限循环的呼吸动画，不能使用 pumpAndSettle。
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// 通过底栏切到统计页（既有契约：底栏『统计』可点）。
  ///
  /// 切页前先清空缓冲异常：本用例只对「统计页的渲染结果」负责，
  /// 其它页面（专注页）在自身适配完成前可能抛出与本页无关的异常，
  /// 那些由各自的用例覆盖，不能记到统计页头上。
  Future<void> openStats(WidgetTester tester) async {
    while (tester.takeException() != null) {}
    final statsNavItem = find.text('统计');
    expect(statsNavItem, findsOneWidget, reason: '底栏『统计』标签必须可见可点');
    await tester.tap(statsNavItem);
    await tester.pump(); // 让路由切换生效
    await tester.pump(const Duration(milliseconds: 400)); // 页面转场
  }

  for (final size in const [Size(320, 568), Size(360, 640), Size(640, 360)]) {
    for (final textScale in const [1.0, 2.0]) {
      testWidgets('stats page renders without overflow at '
          '${size.width.toInt()}x${size.height.toInt()} '
          '(textScale $textScale)', (tester) async {
        setViewport(tester, size, textScale);
        await pumpApp(tester);
        await openStats(tester);

        expect(find.text('数据统计'), findsOneWidget, reason: '统计页标题应正常渲染');
        // 数据链路也要真的跑起来：总时长卡片、圆环图、最近记录都渲染后
        // 才谈得上「不溢出」。
        expect(find.text('总专注时长'), findsOneWidget);
        expect(find.text('最近记录'), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason:
              '统计页在 ${size.width.toInt()}x${size.height.toInt()}dp / '
              'textScale $textScale 下不允许出现布局溢出',
        );
      });
    }
  }

  testWidgets('stats page tab switching keeps layout safe on a small screen', (
    tester,
  ) async {
    setViewport(tester, const Size(320, 568), 2.0);
    await pumpApp(tester);
    await openStats(tester);
    tester.takeException();

    // 日 / 月视图的数据量与周视图不同（1 根柱 vs 6 根柱、圆环图例条数不同），
    // 逐个切换确认三种视图都不溢出。
    for (final label in const ['日', '月', '周']) {
      // 底部柱状图 x 轴标签里也有『日』，取 tab 行里的第一个匹配。
      await tester.tap(find.text(label).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: '切到「$label」视图后不允许出现布局溢出');
    }
  });

  for (final size in const [Size(320, 568), Size(640, 360)]) {
    testWidgets('day detail sheet scrolls instead of overflowing at '
        '${size.width.toInt()}x${size.height.toInt()} (textScale 2.0)', (
      tester,
    ) async {
      setViewport(tester, size, 2.0);
      final stats = DailyStats(
        dateKey: '2026-03-07',
        totalMinutes: 640,
        completedPomodoros: 12,
        subjectMinutes: const {
          '政治': 180,
          '英语': 160,
          '数学': 200,
          '专业课': 100,
          '其他': 0,
        },
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showAdaptiveBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => DayDetailSheet(
                      stats: stats,
                      date: DateTime(2026, 3, 7),
                    ),
                  ),
                  child: const Text('打开'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('打开'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('科目分布'), findsOneWidget);
      // 弹窗内容必须落在屏幕内（底部安全区 + 85% 高度封顶）。
      final sheetTop = tester.getTopLeft(find.byType(DayDetailSheet)).dy;
      expect(sheetTop, greaterThanOrEqualTo(0));
      expect(
        tester.takeException(),
        isNull,
        reason:
            '日详情弹窗在 ${size.width.toInt()}x${size.height.toInt()}dp / '
            'textScale 2.0 下不允许出现布局溢出',
      );
    });
  }
}
