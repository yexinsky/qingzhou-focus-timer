class TimeFormatter {
  TimeFormatter._();

  /// 格式化秒数为 MM:SS 格式
  static String formatSeconds(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// 格式化分钟数为 X小时X分 格式
  static String formatMinutes(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes分钟';
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '${hours}h';
    }
    return '${hours}h ${minutes}m';
  }

  /// 格式化分钟数为大字体显示格式
  static Map<String, dynamic> formatMinutesForDisplay(int totalMinutes) {
    if (totalMinutes < 60) {
      return {'hours': 0, 'minutes': totalMinutes, 'hasHours': false};
    }
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return {'hours': hours, 'minutes': minutes, 'hasHours': true};
  }

  /// 获取今天的日期字符串 (YYYY-MM-DD)
  static String getTodayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// 获取本周的日期范围
  static List<String> getWeekDateRange() {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (index) {
      final date = monday.add(Duration(days: index));
      return '${date.month}/${date.day}';
    });
  }
}
