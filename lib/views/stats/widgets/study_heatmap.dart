import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/daily_stats.dart';

class StudyHeatmap extends StatelessWidget {
  final List<DailyStats> data;
  final void Function(DailyStats stats, DateTime date)? onDayTap;

  const StudyHeatmap({super.key, required this.data, this.onDayTap});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();

    final primary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryDark
        : AppColors.primaryLight;
    final totalWeeks = (data.length / 7).ceil();
    const cellSize = 12.0;
    const gap = 3.0;
    const leftMargin = 20.0;
    const topMargin = 16.0;

    final gridWidth = totalWeeks * (cellSize + gap) - gap;
    final gridHeight = 7 * (cellSize + gap) - gap;
    final totalWidth = leftMargin + gridWidth;
    final totalHeight = topMargin + gridHeight;

    return GestureDetector(
      onTapUp: (details) {
        if (onDayTap == null) return;
        final dx = details.localPosition.dx;
        final dy = details.localPosition.dy;
        if (dx < leftMargin || dy < topMargin) return;
        final col = ((dx - leftMargin) / (cellSize + gap)).floor();
        final row = ((dy - topMargin) / (cellSize + gap)).floor();
        if (col < 0 || col >= totalWeeks || row < 0 || row >= 7) return;
        final index = col * 7 + row;
        if (index >= data.length) return;
        final stats = data[index];
        final date = _parseDate(stats.dateKey);
        if (date != null) onDayTap!(stats, date);
      },
      child: SizedBox(
        width: totalWidth,
        height: totalHeight,
        child: CustomPaint(
          size: Size(totalWidth, totalHeight),
          painter: _HeatmapPainter(
            data: data,
            primary: primary,
            cellSize: cellSize,
            gap: gap,
            leftMargin: leftMargin,
            topMargin: topMargin,
            totalWeeks: totalWeeks,
          ),
        ),
      ),
    );
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

  _HeatmapPainter({
    required this.data,
    required this.primary,
    required this.cellSize,
    required this.gap,
    required this.leftMargin,
    required this.topMargin,
    required this.totalWeeks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawMonthLabels(canvas);
    _drawDayLabels(canvas);
    _drawCells(canvas);
  }

  void _drawMonthLabels(Canvas canvas) {
    final textPainter = TextPainter(
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    );

    int? lastMonth;
    for (var col = 0; col < totalWeeks; col++) {
      final index = col * 7;
      if (index >= data.length) break;
      final date = _parseDate(data[index].dateKey);
      if (date == null) continue;
      final month = date.month;
      if (month != lastMonth) {
        final monthNames = [
          '', '1月', '2月', '3月', '4月', '5月', '6月',
          '7月', '8月', '9月', '10月', '11月', '12月',
        ];
        textPainter.text = TextSpan(
          text: monthNames[month],
          style: TextStyle(
            color: primary.withValues(alpha: 0.5),
            fontSize: 9,
          ),
        );
        textPainter.layout();
        final x = leftMargin + col * (cellSize + gap);
        textPainter.paint(canvas, Offset(x, 0));
        lastMonth = month;
      }
    }
    textPainter.dispose();
  }

  void _drawDayLabels(Canvas canvas) {
    final textPainter = TextPainter(
      textAlign: TextAlign.right,
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    );
    const dayLabels = ['一', '', '三', '', '五', '', '日'];
    for (var row = 0; row < 7; row++) {
      if (dayLabels[row].isEmpty) continue;
      textPainter.text = TextSpan(
        text: dayLabels[row],
        style: TextStyle(
          color: primary.withValues(alpha: 0.4),
          fontSize: 9,
        ),
      );
      textPainter.layout();
      final y = topMargin + row * (cellSize + gap);
      textPainter.paint(canvas, Offset(0, y + 1));
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
