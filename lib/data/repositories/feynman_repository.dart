import 'package:hive/hive.dart';
import '../models/feynman_unit.dart';
import '../models/stumble_mark.dart';

class FeynmanRepository {
  static const unitBoxName = 'feynman_units', markBoxName = 'stumble_marks';
  late Box<FeynmanUnit> _units;
  late Box<StumbleMark> _marks;
  Future<void> init() async {
    if (!Hive.isAdapterRegistered(2))
      Hive.registerAdapter(FeynmanUnitAdapter());
    if (!Hive.isAdapterRegistered(3))
      Hive.registerAdapter(StumbleMarkAdapter());
    _units = await Hive.openBox<FeynmanUnit>(unitBoxName);
    _marks = await Hive.openBox<StumbleMark>(markBoxName);
  }

  List<FeynmanUnit> get units =>
      _units.values.toList()
        ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
  List<StumbleMark> get marks =>
      _marks.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  FeynmanUnit? get activeUnit {
    for (final u in units) {
      if (u.status == 'active') return u;
    }
    return null;
  }

  Future<void> saveUnit(FeynmanUnit u) => _units.put(u.id, u);
  Future<void> saveMark(StumbleMark m) => _marks.put(m.id, m);
  Future<void> deleteMark(String id) => _marks.delete(id);
  Future<void> replaceAll({
    required Iterable<FeynmanUnit> units,
    required Iterable<StumbleMark> marks,
  }) async {
    await _units.clear();
    await _marks.clear();
    await _units.putAll({for (final u in units) u.id: u});
    await _marks.putAll({for (final m in marks) m.id: m});
  }

  Future<void> clear() async {
    await _units.clear();
    await _marks.clear();
  }
}
