class DailyStats {
  final String dateKey;
  final int totalMinutes;
  final int completedPomodoros;
  final Map<String, int> subjectMinutes;

  DailyStats({
    required this.dateKey,
    required this.totalMinutes,
    required this.completedPomodoros,
    required this.subjectMinutes,
  });

  DailyStats copyWith({
    String? dateKey,
    int? totalMinutes,
    int? completedPomodoros,
    Map<String, int>? subjectMinutes,
  }) {
    return DailyStats(
      dateKey: dateKey ?? this.dateKey,
      totalMinutes: totalMinutes ?? this.totalMinutes,
      completedPomodoros: completedPomodoros ?? this.completedPomodoros,
      subjectMinutes: subjectMinutes ?? this.subjectMinutes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'dateKey': dateKey,
      'totalMinutes': totalMinutes,
      'completedPomodoros': completedPomodoros,
      'subjectMinutes': subjectMinutes,
    };
  }

  factory DailyStats.fromJson(Map<String, dynamic> json) {
    return DailyStats(
      dateKey: json['dateKey'] as String,
      totalMinutes: json['totalMinutes'] as int,
      completedPomodoros: json['completedPomodoros'] as int,
      subjectMinutes: Map<String, int>.from(json['subjectMinutes'] as Map),
    );
  }

  factory DailyStats.empty(String dateKey) {
    return DailyStats(
      dateKey: dateKey,
      totalMinutes: 0,
      completedPomodoros: 0,
      subjectMinutes: {},
    );
  }
}

class WeeklyStats {
  final List<DailyStats> days;
  final int totalMinutes;
  final int totalPomodoros;

  WeeklyStats({
    required this.days,
    required this.totalMinutes,
    required this.totalPomodoros,
  });

  Map<String, double> get subjectPercentages {
    if (totalMinutes == 0) return {};
    final Map<String, double> percentages = {};
    int subjectTotal = 0;
    for (final day in days) {
      for (final entry in day.subjectMinutes.entries) {
        subjectTotal += entry.value;
      }
    }
    if (subjectTotal == 0) return {};
    for (final day in days) {
      for (final entry in day.subjectMinutes.entries) {
        percentages[entry.key] =
            (percentages[entry.key] ?? 0) + (entry.value / subjectTotal * 100);
      }
    }
    return percentages;
  }
}
