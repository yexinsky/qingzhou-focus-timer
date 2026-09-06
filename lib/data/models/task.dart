import 'package:hive/hive.dart';

part 'task.g.dart';

@HiveType(typeId: 0)
class Task extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String subject;
  @HiveField(3)
  final bool completed;
  @HiveField(4)
  final String dateKey;
  @HiveField(5)
  final int createdAt;

  /// 0 = low, 1 = normal, 2 = high. Appended for Hive compatibility.
  @HiveField(6)
  final int priority;
  @HiveField(7)
  final String note;
  @HiveField(8)
  final int estimatedPomodoros;

  Task({
    required this.id,
    required this.title,
    required this.subject,
    this.completed = false,
    required this.dateKey,
    required this.createdAt,
    this.priority = 1,
    this.note = '',
    this.estimatedPomodoros = 1,
  });

  Task copyWith({
    String? id,
    String? title,
    String? subject,
    bool? completed,
    String? dateKey,
    int? createdAt,
    int? priority,
    String? note,
    int? estimatedPomodoros,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    subject: subject ?? this.subject,
    completed: completed ?? this.completed,
    dateKey: dateKey ?? this.dateKey,
    createdAt: createdAt ?? this.createdAt,
    priority: priority ?? this.priority,
    note: note ?? this.note,
    estimatedPomodoros: estimatedPomodoros ?? this.estimatedPomodoros,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subject': subject,
    'completed': completed,
    'dateKey': dateKey,
    'createdAt': createdAt,
    'priority': priority,
    'note': note,
    'estimatedPomodoros': estimatedPomodoros,
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'] as String,
    title: json['title'] as String,
    subject: json['subject'] as String,
    completed: json['completed'] as bool? ?? false,
    dateKey: json['dateKey'] as String,
    createdAt: json['createdAt'] as int,
    priority: json['priority'] as int? ?? 1,
    note: json['note'] as String? ?? '',
    estimatedPomodoros: json['estimatedPomodoros'] as int? ?? 1,
  );
}
