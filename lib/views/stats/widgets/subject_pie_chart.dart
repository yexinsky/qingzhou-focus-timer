import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class SubjectPieChart extends StatelessWidget {
  final Map<String, double> percentages;
  final String? centerText;

  const SubjectPieChart({
    super.key,
    required this.percentages,
    this.centerText,
  });

  /// 圆环直径按可用宽度自适应（不再写死 140），窄屏给图例留出可读宽度。
  static double _pieSize(double availableWidth) =>
      (availableWidth * 0.36).clamp(88.0, 140.0);

  @override
  Widget build(BuildContext context) {
    if (percentages.isEmpty) {
      return const SizedBox();
    }

    final sortedEntries = percentages.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = sortedEntries.fold(0.0, (sum, e) => sum + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '学科分布',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width - 48;
            final size = _pieSize(width);
            final pie = _buildPie(context, sortedEntries, total, size);
            final legend = _buildLegend(context, sortedEntries, total);
            // 窄屏（小屏手机 / 分屏）或系统字体放大时，圆环与图例并排会
            // 把图例挤成一条细缝：改为上下堆叠，图例整行可用。
            final isNarrow = width < 300;
            final isLargeText =
                MediaQuery.textScalerOf(context).scale(14) > 14 * 1.3;
            if (isNarrow || isLargeText) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(alignment: Alignment.center, child: pie),
                  const SizedBox(height: 16),
                  legend,
                ],
              );
            }
            return Row(
              children: [
                SizedBox(width: size, height: size, child: pie),
                const SizedBox(width: 24),
                Expanded(child: legend),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildPie(
    BuildContext context,
    List<MapEntry<String, double>> entries,
    double total,
    double size,
  ) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _PieChartPainter(
          percentages: entries.map((e) => e.value / total * 100).toList(),
          colors: entries.map((e) => AppColors.getSubjectColor(e.key)).toList(),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (centerText != null) ...[
                Text(
                  centerText!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context,
    List<MapEntry<String, double>> entries,
    double total,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: entries.take(4).map((entry) {
        final color = AppColors.getSubjectColor(entry.key);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${(entry.value / total * 100).toInt()}%',
                maxLines: 1,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _PieChartPainter extends CustomPainter {
  final List<double> percentages;
  final List<Color> colors;

  _PieChartPainter({required this.percentages, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    // 圆环宽度随直径缩放：直径缩小时不会把中空圆心吃掉。
    final strokeWidth = (size.width * 0.14).clamp(10.0, 20.0);
    final radius = size.width / 2 - strokeWidth / 2 - 2;

    double startAngle = -3.14159 / 2;

    for (int i = 0; i < percentages.length; i++) {
      final sweepAngle = (percentages[i] / 100) * 2 * 3.14159;
      final paint = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle - 0.05,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.percentages != percentages ||
        oldDelegate.colors != colors;
  }
}
