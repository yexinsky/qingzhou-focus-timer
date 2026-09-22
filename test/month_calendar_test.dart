import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/providers/daily_goal_provider.dart';
import 'package:qingzhou_focus/views/plan/widgets/month_calendar.dart';

/// 模拟 plan_view 接线：watch 月份 provider，并把滑动回写的月份写回 provider，
/// 使每次滑动都触发一次父级重建（旧实现"滑动回弹"的回归现场）。
class _Host extends ConsumerWidget {
  const _Host({required this.selectedDate, this.syncMonth = true});

  final DateTime selectedDate;
  final bool syncMonth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(calendarMonthProvider);
    return MaterialApp(
      home: Scaffold(
        body: MonthCalendar(
          selectedDate: selectedDate,
          onDateSelected: (_) {},
          onMonthChanged: syncMonth
              ? (monthKey) =>
                    ref.read(calendarMonthProvider.notifier).state = monthKey
              : null,
        ),
      ),
    );
  }
}

String _header(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data)
    .whereType<String>()
    .firstWhere((d) => d.contains('年') && d.contains('月'));

Future<ProviderContainer> _pumpHost(
  WidgetTester tester, {
  required DateTime selectedDate,
  bool syncMonth = true,
}) async {
  final container = ProviderContainer(
    overrides: [calendarMonthProvider.overrideWith((ref) => '2026-09')],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: _Host(selectedDate: selectedDate, syncMonth: syncMonth),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _swipeTo(WidgetTester tester, {required bool next}) async {
  await tester.fling(find.byType(PageView), Offset(next ? -400 : 400, 0), 1200);
  await tester.pumpAndSettle();
}

void main() {
  final selected = DateTime(2026, 9, 6);

  testWidgets('滑动翻月后父级重建不弹回', (tester) async {
    final container = await _pumpHost(tester, selectedDate: selected);
    expect(_header(tester), '2026年9月');

    await _swipeTo(tester, next: true);
    expect(_header(tester), '2026年10月');
    expect(container.read(calendarMonthProvider), '2026-10');

    await _swipeTo(tester, next: false);
    expect(_header(tester), '2026年9月');
    expect(container.read(calendarMonthProvider), '2026-09');
  });

  testWidgets('外部月份变更（点"今天"）时翻回目标月', (tester) async {
    final container = await _pumpHost(tester, selectedDate: selected);
    await _swipeTo(tester, next: true);
    expect(_header(tester), '2026年10月');

    container.read(calendarMonthProvider.notifier).state = '2026-09';
    await tester.pumpAndSettle();
    expect(_header(tester), '2026年9月');
  });

  testWidgets('外部改选其它月份日期后跟随翻页，回看原月份不被弹回', (tester) async {
    final container = await _pumpHost(tester, selectedDate: selected);
    // 用户滑到 10 月并在那里选了日期：plan_view 会同时更新 selectedDate 与月份
    await _swipeTo(tester, next: true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: _Host(selectedDate: DateTime(2026, 10, 20)),
      ),
    );
    await tester.pumpAndSettle();
    expect(_header(tester), '2026年10月');

    await _swipeTo(tester, next: false);
    expect(_header(tester), '2026年9月');
    expect(container.read(calendarMonthProvider), '2026-09');
  });

  testWidgets('表单内的日期选择实例（无 onMonthChanged）不跟随外部月份', (tester) async {
    final container = await _pumpHost(
      tester,
      selectedDate: selected,
      syncMonth: false,
    );
    container.read(calendarMonthProvider.notifier).state = '2026-11';
    await tester.pumpAndSettle();
    expect(_header(tester), '2026年9月');
  });
}
