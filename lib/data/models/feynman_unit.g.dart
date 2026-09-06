// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'feynman_unit.dart';

class FeynmanUnitAdapter extends TypeAdapter<FeynmanUnit> {
  @override
  final int typeId = 2;
  @override
  FeynmanUnit read(BinaryReader r) {
    final n = r.readByte();
    final f = <int, dynamic>{
      for (var i = 0; i < n; i++) r.readByte(): r.read(),
    };
    return FeynmanUnit(
      id: f[0] as String,
      taskId: f[1] as String?,
      title: f[2] as String,
      subject: f[3] as String,
      chapter: f[4] as String? ?? '',
      topic: f[5] as String? ?? '',
      inputPlannedSeconds: f[6] as int? ?? 1200,
      outputPlannedSeconds: f[7] as int? ?? 600,
      inputActualSeconds: f[8] as int? ?? 0,
      outputActualSeconds: f[9] as int? ?? 0,
      startedAt: f[10] as int,
      completedAt: f[11] as int?,
      status: f[12] as String? ?? 'active',
      recommendReread: f[13] as bool? ?? false,
      textOutput: f[14] as String? ?? '',
      phase: f[15] as String? ?? 'input',
      phaseStartedAt: f[16] as int?,
      accumulatedPhaseSeconds: f[17] as int? ?? 0,
    );
  }

  @override
  void write(BinaryWriter w, FeynmanUnit o) {
    w
      ..writeByte(18)
      ..writeByte(0)
      ..write(o.id)
      ..writeByte(1)
      ..write(o.taskId)
      ..writeByte(2)
      ..write(o.title)
      ..writeByte(3)
      ..write(o.subject)
      ..writeByte(4)
      ..write(o.chapter)
      ..writeByte(5)
      ..write(o.topic)
      ..writeByte(6)
      ..write(o.inputPlannedSeconds)
      ..writeByte(7)
      ..write(o.outputPlannedSeconds)
      ..writeByte(8)
      ..write(o.inputActualSeconds)
      ..writeByte(9)
      ..write(o.outputActualSeconds)
      ..writeByte(10)
      ..write(o.startedAt)
      ..writeByte(11)
      ..write(o.completedAt)
      ..writeByte(12)
      ..write(o.status)
      ..writeByte(13)
      ..write(o.recommendReread)
      ..writeByte(14)
      ..write(o.textOutput)
      ..writeByte(15)
      ..write(o.phase)
      ..writeByte(16)
      ..write(o.phaseStartedAt)
      ..writeByte(17)
      ..write(o.accumulatedPhaseSeconds);
  }
}
