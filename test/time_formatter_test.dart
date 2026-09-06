import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/core/utils/time_formatter.dart';

void main() {
  group('TimeFormatter', () {
    test('formats seconds with zero padding and supports long durations', () {
      expect(TimeFormatter.formatSeconds(0), '00:00');
      expect(TimeFormatter.formatSeconds(65), '01:05');
      expect(TimeFormatter.formatSeconds(3605), '60:05');
    });

    test('formats minutes in Chinese for short and hour-based durations', () {
      expect(TimeFormatter.formatMinutes(0), '0分钟');
      expect(TimeFormatter.formatMinutes(59), '59分钟');
      expect(TimeFormatter.formatMinutes(60), '1h');
      expect(TimeFormatter.formatMinutes(125), '2h 5m');
    });

    test('returns structured display values', () {
      expect(TimeFormatter.formatMinutesForDisplay(42), {
        'hours': 0,
        'minutes': 42,
        'hasHours': false,
      });
      expect(TimeFormatter.formatMinutesForDisplay(135), {
        'hours': 2,
        'minutes': 15,
        'hasHours': true,
      });
    });

    test('today key uses YYYY-MM-DD format', () {
      expect(
        TimeFormatter.getTodayKey(),
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
    });

    test('week range always contains seven month/day labels', () {
      final range = TimeFormatter.getWeekDateRange();
      expect(range, hasLength(7));
      expect(range, everyElement(matches(RegExp(r'^\d{1,2}/\d{1,2}$'))));
    });
  });
}
