// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'focus_session.dart';

class FocusSessionAdapter extends TypeAdapter<FocusSession> {
  @override
  final int typeId = 1;

  @override
  FocusSession read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FocusSession(
      id: fields[0] as String,
      taskId: fields[1] as String?,
      taskTitle: fields[2] as String?,
      subject: fields[3] as String,
      startTime: fields[4] as int,
      duration: fields[5] as int,
      type: fields[6] as String,
      dateKey: fields[7] as String,
      timerMode: fields[8] as String? ?? 'countdown',
    );
  }

  @override
  void write(BinaryWriter writer, FocusSession obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.taskId)
      ..writeByte(2)
      ..write(obj.taskTitle)
      ..writeByte(3)
      ..write(obj.subject)
      ..writeByte(4)
      ..write(obj.startTime)
      ..writeByte(5)
      ..write(obj.duration)
      ..writeByte(6)
      ..write(obj.type)
      ..writeByte(7)
      ..write(obj.dateKey)
      ..writeByte(8)
      ..write(obj.timerMode);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FocusSessionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
