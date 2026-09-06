// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task.dart';

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Task(
      id: fields[0] as String,
      title: fields[1] as String,
      subject: fields[2] as String,
      completed: fields[3] as bool? ?? false,
      dateKey: fields[4] as String,
      createdAt: fields[5] as int,
      priority: fields[6] as int? ?? 1,
      note: fields[7] as String? ?? '',
      estimatedPomodoros: fields[8] as int? ?? 1,
    );
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.subject)
      ..writeByte(3)
      ..write(obj.completed)
      ..writeByte(4)
      ..write(obj.dateKey)
      ..writeByte(5)
      ..write(obj.createdAt)
      ..writeByte(6)
      ..write(obj.priority)
      ..writeByte(7)
      ..write(obj.note)
      ..writeByte(8)
      ..write(obj.estimatedPomodoros);
  }

  @override
  int get hashCode => typeId.hashCode;
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
