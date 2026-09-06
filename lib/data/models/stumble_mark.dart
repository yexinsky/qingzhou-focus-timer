import 'package:hive/hive.dart';

part 'stumble_mark.g.dart';

@HiveType(typeId: 3)
class StumbleMark extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String unitId;
  @HiveField(2)
  final String subject;
  @HiveField(3)
  final String chapter;
  @HiveField(4)
  final String topic;
  @HiveField(5)
  final String keyword;
  @HiveField(6)
  final String note;
  @HiveField(7)
  final String reason;
  @HiveField(8)
  final int offsetSeconds;
  @HiveField(9)
  final int createdAt;
  @HiveField(10)
  final int severity;
  @HiveField(11)
  final bool resolved;
  @HiveField(12)
  final int? resolvedAt;
  StumbleMark({
    required this.id,
    required this.unitId,
    required this.subject,
    this.chapter = '',
    this.topic = '',
    this.keyword = '',
    this.note = '',
    this.reason = '',
    required this.offsetSeconds,
    required this.createdAt,
    this.severity = 2,
    this.resolved = false,
    this.resolvedAt,
  });
  StumbleMark copyWith({
    String? keyword,
    String? note,
    String? reason,
    int? severity,
    bool? resolved,
    int? resolvedAt,
  }) => StumbleMark(
    id: id,
    unitId: unitId,
    subject: subject,
    chapter: chapter,
    topic: topic,
    keyword: keyword ?? this.keyword,
    note: note ?? this.note,
    reason: reason ?? this.reason,
    offsetSeconds: offsetSeconds,
    createdAt: createdAt,
    severity: severity ?? this.severity,
    resolved: resolved ?? this.resolved,
    resolvedAt: resolvedAt ?? this.resolvedAt,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'unitId': unitId,
    'subject': subject,
    'chapter': chapter,
    'topic': topic,
    'keyword': keyword,
    'note': note,
    'reason': reason,
    'offsetSeconds': offsetSeconds,
    'createdAt': createdAt,
    'severity': severity,
    'resolved': resolved,
    'resolvedAt': resolvedAt,
  };
  factory StumbleMark.fromJson(Map<String, dynamic> j) => StumbleMark(
    id: j['id'] as String,
    unitId: j['unitId'] as String,
    subject: j['subject'] as String,
    chapter: j['chapter'] as String? ?? '',
    topic: j['topic'] as String? ?? '',
    keyword: j['keyword'] as String? ?? '',
    note: j['note'] as String? ?? '',
    reason: j['reason'] as String? ?? '',
    offsetSeconds: j['offsetSeconds'] as int? ?? 0,
    createdAt: j['createdAt'] as int,
    severity: j['severity'] as int? ?? 2,
    resolved: j['resolved'] as bool? ?? false,
    resolvedAt: j['resolvedAt'] as int?,
  );
}
