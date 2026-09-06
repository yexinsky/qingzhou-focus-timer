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
        Row(
          children: [
            SizedBox(
              width: 140,
              height: 140,
              child: CustomPaint(
                painter: _PieChartPainter(
                  percentages: sortedEntries
                      .map((e) => e.value / total * 100)
                      .toList(),
                  colors: sortedEntries
                      .map((e) => AppColors.getSubjectColor(e.key))
                      .toList(),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (centerText != null) ...[
                        Text(
                          centerText!,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                children: sortedEntries.take(4).map((entry) {
                  final color = AppColors.getSubjectColor(entry.key);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                        Text(
                          '${(entry.value / total * 100).toInt()}%',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ],
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
    final radius = size.width / 2 - 8;
    const strokeWidth = 20.0;

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
