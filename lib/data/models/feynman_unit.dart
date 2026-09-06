import 'package:hive/hive.dart';

part 'feynman_unit.g.dart';

@HiveType(typeId: 2)
class FeynmanUnit extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String? taskId;
  @HiveField(2)
  final String title;
  @HiveField(3)
  final String subject;
  @HiveField(4)
  final String chapter;
  @HiveField(5)
  final String topic;
  @HiveField(6)
  final int inputPlannedSeconds;
  @HiveField(7)
  final int outputPlannedSeconds;
  @HiveField(8)
  final int inputActualSeconds;
  @HiveField(9)
  final int outputActualSeconds;
  @HiveField(10)
  final int startedAt;
  @HiveField(11)
  final int? completedAt;
  @HiveField(12)
  final String status;
  @HiveField(13)
  final bool recommendReread;
  @HiveField(14)
  final String textOutput;
  @HiveField(15)
  final String phase;
  @HiveField(16)
  final int phaseStartedAt;
  @HiveField(17)
  final int accumulatedPhaseSeconds;

  FeynmanUnit({
    required this.id,
    this.taskId,
    required this.title,
    required this.subject,
    this.chapter = '',
    this.topic = '',
    this.inputPlannedSeconds = 1200,
    this.outputPlannedSeconds = 600,
    this.inputActualSeconds = 0,
    this.outputActualSeconds = 0,
    required this.startedAt,
    this.completedAt,
    this.status = 'active',
    this.recommendReread = false,
    this.textOutput = '',
    this.phase = 'input',
    int? phaseStartedAt,
    this.accumulatedPhaseSeconds = 0,
  }) : assert(outputPlannedSeconds * 2 >= inputPlannedSeconds),
       phaseStartedAt = phaseStartedAt ?? startedAt;

  FeynmanUnit copyWith({
    String? title,
    String? subject,
    String? chapter,
    String? topic,
    int? inputPlannedSeconds,
    int? outputPlannedSeconds,
    int? inputActualSeconds,
    int? outputActualSeconds,
    int? completedAt,
    String? status,
    bool? recommendReread,
    String? textOutput,
    String? phase,
    int? phaseStartedAt,
    int? accumulatedPhaseSeconds,
  }) => FeynmanUnit(
    id: id,
    taskId: taskId,
    title: title ?? this.title,
    subject: subject ?? this.subject,
    chapter: chapter ?? this.chapter,
    topic: topic ?? this.topic,
    inputPlannedSeconds: inputPlannedSeconds ?? this.inputPlannedSeconds,
    outputPlannedSeconds: outputPlannedSeconds ?? this.outputPlannedSeconds,
    inputActualSeconds: inputActualSeconds ?? this.inputActualSeconds,
    outputActualSeconds: outputActualSeconds ?? this.outputActualSeconds,
    startedAt: startedAt,
    completedAt: completedAt ?? this.completedAt,
    status: status ?? this.status,
    recommendReread: recommendReread ?? this.recommendReread,
    textOutput: textOutput ?? this.textOutput,
    phase: phase ?? this.phase,
    phaseStartedAt: phaseStartedAt ?? this.phaseStartedAt,
    accumulatedPhaseSeconds:
        accumulatedPhaseSeconds ?? this.accumulatedPhaseSeconds,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'title': title,
    'subject': subject,
    'chapter': chapter,
    'topic': topic,
    'inputPlannedSeconds': inputPlannedSeconds,
    'outputPlannedSeconds': outputPlannedSeconds,
    'inputActualSeconds': inputActualSeconds,
    'outputActualSeconds': outputActualSeconds,
    'startedAt': startedAt,
    'completedAt': completedAt,
    'status': status,
    'recommendReread': recommendReread,
    'textOutput': textOutput,
    'phase': phase,
    'phaseStartedAt': phaseStartedAt,
    'accumulatedPhaseSeconds': accumulatedPhaseSeconds,
  };
  factory FeynmanUnit.fromJson(Map<String, dynamic> j) => FeynmanUnit(
    id: j['id'] as String,
    taskId: j['taskId'] as String?,
    title: j['title'] as String,
    subject: j['subject'] as String,
    chapter: j['chapter'] as String? ?? '',
    topic: j['topic'] as String? ?? '',
    inputPlannedSeconds: j['inputPlannedSeconds'] as int? ?? 1200,
    outputPlannedSeconds: j['outputPlannedSeconds'] as int? ?? 600,
    inputActualSeconds: j['inputActualSeconds'] as int? ?? 0,
    outputActualSeconds: j['outputActualSeconds'] as int? ?? 0,
    startedAt: j['startedAt'] as int,
    completedAt: j['completedAt'] as int?,
    status: j['status'] as String? ?? 'active',
    recommendReread: j['recommendReread'] as bool? ?? false,
    textOutput: j['textOutput'] as String? ?? '',
    phase: j['phase'] as String? ?? 'input',
    phaseStartedAt: j['phaseStartedAt'] as int?,
    accumulatedPhaseSeconds: j['accumulatedPhaseSeconds'] as int? ?? 0,
  );
}
