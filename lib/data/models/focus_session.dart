import 'package:hive/hive.dart';

part 'focus_session.g.dart';

@HiveType(typeId: 1)
class FocusSession extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String? taskId;

  @HiveField(2)
  final String? taskTitle;

  @HiveField(3)
  final String subject;

  @HiveField(4)
  final int startTime;

  @HiveField(5)
  final int duration;

  @HiveField(6)
  final String type;

  @HiveField(7)
  final String dateKey;

  FocusSession({
    required this.id,
    this.taskId,
    this.taskTitle,
    required this.subject,
    required this.startTime,
    required this.duration,
    required this.type,
    required this.dateKey,
  });

  FocusSession copyWith({
    String? id,
    String? taskId,
    String? taskTitle,
    String? subject,
    int? startTime,
    int? duration,
    String? type,
    String? dateKey,
  }) {
    return FocusSession(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      taskTitle: taskTitle ?? this.taskTitle,
      subject: subject ?? this.subject,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      type: type ?? this.type,
      dateKey: dateKey ?? this.dateKey,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'taskId': taskId,
      'taskTitle': taskTitle,
      'subject': subject,
      'startTime': startTime,
      'duration': duration,
      'type': type,
      'dateKey': dateKey,
    };
  }

  factory FocusSession.fromJson(Map<String, dynamic> json) {
    return FocusSession(
      id: json['id'] as String,
      taskId: json['taskId'] as String?,
      taskTitle: json['taskTitle'] as String?,
      subject: json['subject'] as String,
      startTime: json['startTime'] as int,
      duration: json['duration'] as int,
      type: json['type'] as String,
      dateKey: json['dateKey'] as String,
    );
  }
}
