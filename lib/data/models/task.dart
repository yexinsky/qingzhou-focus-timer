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

  Task({
    required this.id,
    required this.title,
    required this.subject,
    this.completed = false,
    required this.dateKey,
    required this.createdAt,
  });

  Task copyWith({
    String? id,
    String? title,
    String? subject,
    bool? completed,
    String? dateKey,
    int? createdAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      completed: completed ?? this.completed,
      dateKey: dateKey ?? this.dateKey,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'completed': completed,
      'dateKey': dateKey,
      'createdAt': createdAt,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as String,
      title: json['title'] as String,
      subject: json['subject'] as String,
      completed: json['completed'] as bool? ?? false,
      dateKey: json['dateKey'] as String,
      createdAt: json['createdAt'] as int,
    );
  }
}
