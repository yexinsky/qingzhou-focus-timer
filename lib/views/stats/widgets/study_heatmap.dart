import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/layout_utils.dart';
import '../../../data/models/daily_stats.dart';

class StudyHeatmap extends StatelessWidget {
  final List<DailyStats> data;
  final void Function(DailyStats stats, DateTime date)? onDayTap;

  const StudyHeatmap({super.key, required this.data, this.onDayTap});

  static const double _cellSize = 12;
  static const double _cellGap = 3;
  static const double _labelFontSize = 9;
  static const List<String> _weekdayLabels = ['一', '', '三', '', '五', '', '日'];

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryDark
        : AppColors.primaryLight;

    // 图内标签跟随系统字体放大但封顶（原来固定 noScaling，放大字体时也
    // 不会溢出；封顶后既照顾弱视可读性，又不会把整年网格撑爆）。
    final labelScaler = MediaQuery.textScalerOf(context).clamp(
      minScaleFactor: 1.0,
      maxScaleFactor: LayoutUtils.maxTextScaleFactor,
    );

    // 边距由真实文本度量反推，不再感叹 20 / 16 两个魔法数字：
    // 字体放大时左边距 / 上边距随之变大，月份与周几标签不会被裁掉。
    final dayLabelWidth = _maxLabelWidth(_weekdayLabels, labelScaler);
    final monthLabelHeight = _labelHeight('12月', labelScaler);
    final leftMargin = dayLabelWidth + 5;
    final topMargin = monthLabelHeight + 4;

    final totalWeeks = (data.length / 7).ceil();
    if (totalWeeks <= 0) return const SizedBox.shrink();

    final gridWidth = totalWeeks * (_cellSize + _cellGap) - _cellGap;
    final gridHeight = 7 * (_cellSize + _cellGap) - _cellGap;
    final totalWidth = leftMargin + gridWidth;
    final totalHeight = topMargin + gridHeight;

    return GestureDetector(
      onTapUp: (details) {
        if (onDayTap == null) return;
        final dx = details.localPosition.dx;
        final dy = details.localPosition.dy;
        if (dx < leftMargin || dy < topMargin) return;
        final col = ((dx - leftMargin) / (_cellSize + _cellGap)).floor();
        final row = ((dy - topMargin) / (_cellSize + _cellGap)).floor();
        if (col < 0 || col >= totalWeeks || row < 0 || row >= 7) return;
        final index = col * 7 + row;
        if (index >= data.length) return;
        final stats = data[index];
        final date = _parseDate(stats.dateKey);
        if (date != null) onDayTap!(stats, date);
      },
      child: RepaintBoundary(
        child: SizedBox(
          width: totalWidth,
          height: totalHeight,
          child: CustomPaint(
            size: Size(totalWidth, totalHeight),
            painter: _HeatmapPainter(
              data: data,
              primary: primary,
              cellSize: _cellSize,
              gap: _cellGap,
              leftMargin: leftMargin,
              topMargin: topMargin,
              totalWeeks: totalWeeks,
              labelScaler: labelScaler,
              labelFontSize: _labelFontSize,
              weekdayLabels: _weekdayLabels,
            ),
          ),
        ),
      ),
    );
  }

  double _maxLabelWidth(List<String> labels, TextScaler scaler) {
    var maxWidth = 0.0;
    for (final label in labels) {
      if (label.isEmpty) continue;
      final painter = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(fontSize: _labelFontSize),
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
      )..layout();
      if (painter.width > maxWidth) maxWidth = painter.width;
      painter.dispose();
    }
    return maxWidth;
  }

  double _labelHeight(String label, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(fontSize: _labelFontSize),
      ),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout();
    final height = painter.height;
    painter.dispose();
    return height;
  }

  DateTime? _parseDate(String dateKey) {
    try {
      final parts = dateKey.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }
}

class _HeatmapPainter extends CustomPainter {
  final List<DailyStats> data;
  final Color primary;
  final double cellSize;
  final double gap;
  final double leftMargin;
  final double topMargin;
  final int totalWeeks;
  final TextScaler labelScaler;
  final double labelFontSize;
  final List<String> weekdayLabels;

  _HeatmapPainter({
    required this.data,
    required this.primary,
    required this.cellSize,
    required this.gap,
    required this.leftMargin,
    required this.topMargin,
    required this.totalWeeks,
    required this.labelScaler,
    required this.labelFontSize,
    required this.weekdayLabels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawMonthLabels(canvas, size);
    _drawDayLabels(canvas, size);
    _drawCells(canvas);
  }

  void _drawMonthLabels(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      textScaler: labelScaler,
      maxLines: 1,
      ellipsis: '…',
    );

    int? lastMonth;
    for (var col = 0; col < totalWeeks; col++) {
      final index = col * 7;
      if (index >= data.length) break;
      final date = _parseDate(data[index].dateKey);
      if (date == null) continue;
      final month = date.month;
      if (month != lastMonth) {
        textPainter.text = TextSpan(
          text: '$month月',
          style: TextStyle(
            color: primary.withValues(alpha: 0.5),
            fontSize: labelFontSize,
          ),
        );
        // 限制在剩余可用宽度内，月份标签永远不会画到画布外被裁掉。
        final x = leftMargin + col * (cellSize + gap);
        final available = (size.width - x).clamp(0.0, size.width);
        textPainter.layout(maxWidth: available);
        textPainter.paint(canvas, Offset(x, 0));
        lastMonth = month;
      }
    }
    textPainter.dispose();
  }

  void _drawDayLabels(Canvas canvas, Size size) {
    final textPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
      textScaler: labelScaler,
      maxLines: 1,
    );
    final labelBoxWidth = (leftMargin - 5).clamp(0.0, leftMargin);
    for (var row = 0; row < 7; row++) {
      if (weekdayLabels[row].isEmpty) continue;
      textPainter.text = TextSpan(
        text: weekdayLabels[row],
        style: TextStyle(
          color: primary.withValues(alpha: 0.4),
          fontSize: labelFontSize,
        ),
      );
      textPainter.layout(maxWidth: labelBoxWidth);
      final y =
          topMargin +
          row * (cellSize + gap) +
          (cellSize - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(0, y));
    }
    textPainter.dispose();
  }

  void _drawCells(Canvas canvas) {
    final paint = Paint()..style = PaintingStyle.fill;
    final today = DateTime.now();
    final todayKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

    for (var col = 0; col < totalWeeks; col++) {
      for (var row = 0; row < 7; row++) {
        final index = col * 7 + row;
        if (index >= data.length) continue;

        final stats = data[index];
        final isFuture = stats.dateKey.compareTo(todayKey) > 0;
        if (isFuture) continue;

        final opacity = _opacityForMinutes(stats.totalMinutes);
        paint.color = primary.withValues(alpha: opacity);

        final x = leftMargin + col * (cellSize + gap);
        final y = topMargin + row * (cellSize + gap);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, cellSize, cellSize),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, paint);
      }
    }
  }

  double _opacityForMinutes(int minutes) {
    if (minutes <= 0) return 0.08;
    if (minutes < 120) return 0.25;
    if (minutes < 240) return 0.50;
    if (minutes < 360) return 0.75;
    return 1.0;
  }

  DateTime? _parseDate(String dateKey) {
    try {
      final parts = dateKey.split('-');
      return DateTime(
        int.parse(parts[0]),
        int.parse(parts[1]),
        int.parse(parts[2]),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  bool shouldRepaint(covariant _HeatmapPainter oldDelegate) =>
      oldDelegate.data != data ||
      oldDelegate.primary != primary ||
      oldDelegate.cellSize != cellSize ||
      oldDelegate.gap != gap ||
      oldDelegate.leftMargin != leftMargin ||
      oldDelegate.topMargin != topMargin ||
      oldDelegate.totalWeeks != totalWeeks ||
      oldDelegate.labelScaler != labelScaler;
}
