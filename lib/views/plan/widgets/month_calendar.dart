import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
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
  late int _initialPage;
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

  @override
  void initState() {
    super.initState();
    _initialPage = _pageOf(widget.selectedDate);
    _headerPage = _initialPage;
    _controller = PageController(initialPage: _initialPage);
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

  @override
  void didUpdateWidget(MonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_pageOf(widget.selectedDate) != _initialPage &&
        _controller.hasClients &&
        (_controller.page == null ||
            _controller.page!.round() == _initialPage)) {
      // 外部切换月份（如点击"回今天"）时同步翻页
      _initialPage = _pageOf(widget.selectedDate);
      setState(() => _headerPage = _initialPage);
      _animateTo(_initialPage);
    }
  }

  Widget _monthView(int page) {
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
      height: rows * 40.0 + 8,
      child: Column(
        children: [
          for (var row = 0; row < rows; row++)
            SizedBox(
              height: 40,
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
  ) {
    if (offset < 0 || offset >= daysInMonth) return const SizedBox.shrink();
    final date = DateTime(monthStart.year, monthStart.month, offset + 1);
    final dateKey = TasksNotifier.dateKey(date);
    final isStart = _dayOnly(widget.selectedDate) == date;
    final isEnd = widget.rangeEnd != null && _dayOnly(widget.rangeEnd!) == date;
    final selected = isStart || isEnd;
    final inRange = lo != null && hi != null && !date.isBefore(lo) && !date.isAfter(hi);
    final isToday = date == _today;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final primary = dark ? AppColors.primaryDark : AppColors.primaryLight;
    final muted = AppColors.textSecondary.withValues(alpha: .35);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => widget.onDateSelected(date),
      child: Container(
        height: 40,
        decoration: inRange
            ? BoxDecoration(
                color: primary.withValues(alpha: .12),
                borderRadius: BorderRadius.horizontal(
                  left: date == lo ? const Radius.circular(20) : Radius.zero,
                  right: date == hi ? const Radius.circular(20) : Radius.zero,
                ),
              )
            : null,
        child: Center(
          child: SizedBox(
            width: 36,
            height: 36,
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
                        ? (dark ? AppColors.textPrimaryDark : AppColors.textPrimary)
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
        SizedBox(
          height: 6 * 40.0 + 8,
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
              child: _monthView(page),
            ),
          ),
        ),
      ],
    );
  }
}
