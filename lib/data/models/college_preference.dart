import 'package:uuid/uuid.dart';

/// 院校板块的用户偏好：意向收藏、目标院校、考试日期与里程碑。
///
/// 以 SharedPreferences 单 key JSON 持久化（college_preference_repository）。
/// 院校以名称为键——排名榜单每年更新，名称键可跨年份稳定。
class CollegePreferences {
  final List<String> favorites;
  final String? target;
  final DateTime? examDate;
  final List<ExamMilestone> milestones;

  const CollegePreferences({
    this.favorites = const [],
    this.target,
    this.examDate,
    this.milestones = const [],
  });

  factory CollegePreferences.fromJson(Map<String, dynamic> json) {
    final target = (json['target'] as String?)?.trim();
    DateTime? examDate;
    final rawDate = json['examDate'] as String?;
    if (rawDate != null) {
      try {
        examDate = DateTime.parse(rawDate);
      } on FormatException {
        examDate = null;
      }
    }
    return CollegePreferences(
      favorites: (json['favorites'] as List<dynamic>? ?? const [])
          .map((name) => name.toString())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList(),
      target: target == null || target.isEmpty ? null : target,
      examDate: examDate,
      milestones: (json['milestones'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(ExamMilestone.fromJson)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'favorites': favorites,
    'target': target,
    'examDate': examDate?.toIso8601String(),
    'milestones': [for (final m in milestones) m.toJson()],
  };
}

/// 一条择校里程碑；date 为空表示不限日期。
class ExamMilestone {
  final String id;
  final String title;
  final DateTime? date;
  final bool done;

  const ExamMilestone({
    required this.id,
    required this.title,
    this.date,
    this.done = false,
  });

  factory ExamMilestone.fromJson(Map<String, dynamic> json) {
    DateTime? date;
    final rawDate = json['date'] as String?;
    if (rawDate != null) {
      try {
        date = DateTime.parse(rawDate);
      } on FormatException {
        date = null;
      }
    }
    return ExamMilestone(
      id: json['id'] as String? ?? const Uuid().v4(),
      title: json['title'] as String? ?? '',
      date: date,
      done: json['done'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'date': date?.toIso8601String(),
    'done': done,
  };
}
