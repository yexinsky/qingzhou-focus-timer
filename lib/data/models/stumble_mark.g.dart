// GENERATED CODE - DO NOT MODIFY BY HAND
part of 'stumble_mark.dart';

class StumbleMarkAdapter extends TypeAdapter<StumbleMark> {
  @override
  final int typeId = 3;
  @override
  StumbleMark read(BinaryReader r) {
    final n = r.readByte();
    final f = <int, dynamic>{
      for (var i = 0; i < n; i++) r.readByte(): r.read(),
    };
    return StumbleMark(
      id: f[0] as String,
      unitId: f[1] as String,
      subject: f[2] as String,
      chapter: f[3] as String? ?? '',
      topic: f[4] as String? ?? '',
      keyword: f[5] as String? ?? '',
      note: f[6] as String? ?? '',
      reason: f[7] as String? ?? '',
      offsetSeconds: f[8] as int? ?? 0,
      createdAt: f[9] as int,
      severity: f[10] as int? ?? 2,
      resolved: f[11] as bool? ?? false,
      resolvedAt: f[12] as int?,
    );
  }

  @override
  void write(BinaryWriter w, StumbleMark o) {
    w
      ..writeByte(13)
      ..writeByte(0)
      ..write(o.id)
      ..writeByte(1)
      ..write(o.unitId)
      ..writeByte(2)
      ..write(o.subject)
      ..writeByte(3)
      ..write(o.chapter)
      ..writeByte(4)
      ..write(o.topic)
      ..writeByte(5)
      ..write(o.keyword)
      ..writeByte(6)
      ..write(o.note)
      ..writeByte(7)
      ..write(o.reason)
      ..writeByte(8)
      ..write(o.offsetSeconds)
      ..writeByte(9)
      ..write(o.createdAt)
      ..writeByte(10)
      ..write(o.severity)
      ..writeByte(11)
      ..write(o.resolved)
      ..writeByte(12)
      ..write(o.resolvedAt);
  }
}
