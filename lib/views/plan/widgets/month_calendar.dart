import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/daily_goal_provider.dart';
import '../../../providers/task_provider.dart';

/// 自建中文月历：替换英文的 showDatePicker 与"今天/明天/选日期"分段按钮。
/// markedDates 用于在有任务的日期下方显示圆点。
class MonthCalendar extends ConsumerStatefulWidget {
  const MonthCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.onMonthChanged,
    this.markedDates = const {},
    this.showMarks = true,
    this.rangeEnd,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  /// 滑动/翻页切换月份时回调（yyyy-MM）
  final ValueChanged<String>? onMonthChanged;
  final Set<String> markedDates;

  /// 关闭时隐藏任务圆点（如任务表单内的纯日期选择场景）
  final bool showMarks;

  /// 范围选择的结束日期（与 selectedDate 组成起止区间并高亮）
  final DateTime? rangeEnd;

  @override
  ConsumerState<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends ConsumerState<MonthCalendar> {
  late PageController _controller;
  late int _headerPage;

  static const _totalMonths = 2400; // 2020-01 起 200 年
  static const _weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];

  DateTime get _today => _dayOnly(DateTime.now());

  static DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime _monthAt(int page) {
    final index = page.clamp(0, _totalMonths - 1);
    return DateTime(2020 + index ~/ 12, index % 12 + 1);
  }

  static int _pageOf(DateTime d) => (d.year - 2020) * 12 + d.month - 1;

  /// 'yyyy-MM' → 页索引；非法输入返回 null。
  static int? _pageOfMonthKey(String key) {
    final parts = key.split('-');
    if (parts.length != 2) return null;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) return null;
    return _pageOf(DateTime(year, month));
  }

  @override
  void initState() {
    super.initState();
    _headerPage = _pageOf(widget.selectedDate);
    _controller = PageController(initialPage: _headerPage);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(int page) {
    if (page < 0 || page > _totalMonths - 1) return;
    _controller.animateToPage(
      page,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  /// 响应外部翻月请求；已在该月或控制器未挂载时忽略。
  void _showMonth(int target) {
    if (!_controller.hasClients) return;
    final page = target.clamp(0, _totalMonths - 1);
    if (page == _headerPage) return;
    setState(() => _headerPage = page);
    _animateTo(page);
  }

  @override
  void didUpdateWidget(MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 只有外部改选了日期才跟随翻月：滑动不改 selectedDate，不能被误判为
    // "外部切换"——旧实现用 _initialPage 作锚，滑动后会把页面弹回选中月份。
    if (_dayOnly(oldWidget.selectedDate) == _dayOnly(widget.selectedDate)) {
      return;
    }
    _showMonth(_pageOf(widget.selectedDate));
  }

  /// 表格单元格高度：由「可用宽度」和「系统字体缩放」共同推导，不再写死 40。
  /// - 窄屏：格子宽度决定高度，保持接近正方形的观感；
  /// - 系统字体放大：数字需要更多竖直空间，下限随 textScaler 抬升；
  /// - 上限 56：横屏矮屏（高 360dp）时整块日历仍能塞进一屏。
  double _cellHeight(BuildContext context, double maxWidth) {
    final textScaler = MediaQuery.textScalerOf(context);
    final widthDriven = math.min(maxWidth / 7, 44.0);
    final textDriven = textScaler.scale(14) + 18;
    final height = math.max(widthDriven, math.max(textDriven, 32.0));
    return height.clamp(32.0, 56.0);
  }

  Widget _monthView(int page, double cellHeight) {
    final monthStart = _monthAt(page);
    final nextMonth = DateTime(monthStart.year, monthStart.month + 1);
    // 周一为一周起点
    final leadingBlanks =
        (DateTime(monthStart.year, monthStart.month).weekday - 1);
    final daysInMonth = nextMonth.difference(monthStart).inDays;
    final cells = leadingBlanks + daysInMonth;
    final rows = (cells / 7).ceil();

    // 范围起止（归一化 lo <= hi）
    DateTime? lo;
    DateTime? hi;
    if (widget.rangeEnd != null) {
      final a = _dayOnly(widget.selectedDate);
      final b = _dayOnly(widget.rangeEnd!);
      lo = a.isAfter(b) ? b : a;
      hi = a.isAfter(b) ? a : b;
    }

    return SizedBox(
      height: rows * cellHeight + 8,
      child: Column(
        children: [
          for (var row = 0; row < rows; row++)
            SizedBox(
              height: cellHeight,
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: _dayCell(
                        row * 7 + col - leadingBlanks,
                        monthStart,
                        daysInMonth,
                        lo,
                        hi,
                        cellHeight,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCell(
    int offset,
    DateTime monthStart,
    int daysInMonth,
    DateTime? lo,
    DateTime? hi,
    double cellHeight,
  ) {
    if (offset < 0 || offset >= daysInMonth) return const SizedBox.shrink();
    final date = DateTime(monthStart.year, monthStart.month, offset + 1);
    final dateKey = TasksNotifier.dateKey(date);
    final isStart = _dayOnly(widget.selectedDate) == date;
    final isEnd = widget.rangeEnd != null && _dayOnly(widget.rangeEnd!) == date;
    final selected = isStart || isEnd;
    final inRange =
        lo != null && hi != null && !date.isBefore(lo) && !date.isAfter(hi);
    final isToday = date == _today;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.primaryDark : AppColors.primaryLight;
    final muted = AppColors.textSecondary.withValues(alpha: .35);

    // 选中圆盘随格子高度收缩，避免小屏/矮屏时圆盘比格子还高。
    final discSize = math.min(cellHeight - 2, 36.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onDateSelected(date),
      child: Container(
        height: cellHeight,
        decoration: inRange
            ? BoxDecoration(
                color: primary.withValues(alpha: .12),
                borderRadius: BorderRadius.horizontal(
                  left: date == lo
                      ? Radius.circular(cellHeight / 2)
                      : Radius.zero,
                  right: date == hi
                      ? Radius.circular(cellHeight / 2)
                      : Radius.zero,
                ),
              )
            : null,
        child: Center(
          child: SizedBox(
            width: discSize,
            height: discSize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (selected)
                  Container(
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: .16),
                      shape: BoxShape.circle,
                      border: Border.all(color: primary, width: 1.4),
                    ),
                  ),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1,
                    fontWeight: selected || isToday
                        ? FontWeight.w600
                        : FontWeight.w400,
                    color: selected
                        ? primary
                        : isToday
                        ? (dark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary)
                        : muted,
                  ),
                ),
                if (widget.showMarks && widget.markedDates.contains(dateKey))
                  Positioned(
                    bottom: 3,
                    child: Container(
                      width: 4,
                      height: 4,
                      decoration: BoxDecoration(
                        color: selected ? primary : AppColors.subjectEnglish,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // plan 页把当前浏览月份写入 calendarMonthProvider（滑动时回写）。外部改该
    // provider（如点"今天"）时在此跟随翻页；以 _headerPage 作守卫，滑动自身的
    // 回写（onPageChanged 已先更新 _headerPage）必然 no-op，不会打断滑动。
    // 仅监听会回写月份的实例，表单内的纯日期选择实例不受影响。
    if (widget.onMonthChanged != null) {
      ref.listen<String>(calendarMonthProvider, (_, monthKey) {
        final target = _pageOfMonthKey(monthKey);
        if (target != null) _showMonth(target);
      });
    }
    final dark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final shownMonth = _monthAt(_headerPage);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              IconButton(
                onPressed: () => _animateTo(_headerPage - 1),
                icon: Icon(Icons.chevron_left, color: iconColor),
              ),
              Expanded(
                child: Text(
                  '${shownMonth.year}年${shownMonth.month}月',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _animateTo(_headerPage + 1),
                icon: Icon(Icons.chevron_right, color: iconColor),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            children: [
              for (final (i, label) in _weekdayLabels.indexed)
                Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        color: i >= 5 ? AppColors.textSecondary : iconColor,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        // PageView 高度按「最多 6 行 × 当前单元格高度」算，单元格高度由宽度
        // 与字体缩放推导（见 _cellHeight），因此横屏/大字体也不会横向或纵向
        // 撑破；日历整体高度仍是一屏可控的量。
        LayoutBuilder(
          builder: (context, constraints) {
            final cellHeight = _cellHeight(context, constraints.maxWidth - 8);
            return SizedBox(
              height: 6 * cellHeight + 8,
              child: PageView.builder(
                controller: _controller,
                itemCount: _totalMonths,
                onPageChanged: (page) {
                  setState(() => _headerPage = page);
                  final month = _monthAt(page);
                  widget.onMonthChanged?.call(
                    '${month.year}-${month.month.toString().padLeft(2, '0')}',
                  );
                },
                itemBuilder: (_, page) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _monthView(page, cellHeight),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
