import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/college_preference.dart';

/// 院校偏好仓库：意向收藏、目标院校、考试日期与里程碑。
///
/// SharedPreferences 单 key JSON 存储。所有读写内部容错：
/// 未 init 或持久化失败时回退内存态，绝不向上抛异常
/// （main.dart 启动失败会阻断整个应用，参照 subject_repository 的兜底方式）。
class CollegePreferenceRepository {
  static const String _storageKey = 'college_preference_v1';

  SharedPreferences? _prefs;
  CollegePreferences _state = const CollegePreferences();

  Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final raw = _prefs!.getString(_storageKey);
      if (raw != null) {
        _state = CollegePreferences.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      }
    } catch (_) {
      // 解析失败等异常情况：保留内存默认值
    }
  }

  CollegePreferences get preferences => _state;

  CollegePreferences _update(CollegePreferences next) {
    _state = next;
    try {
      _prefs?.setString(_storageKey, jsonEncode(next.toJson()));
    } catch (_) {
      // 持久化失败不影响内存态
    }
    return _state;
  }

  CollegePreferences toggleFavorite(String name) {
    final favorites = List<String>.of(_state.favorites);
    if (favorites.contains(name)) {
      favorites.remove(name);
    } else {
      favorites.add(name);
    }
    return _update(
      CollegePreferences(
        favorites: favorites,
        target: _state.target,
        examDate: _state.examDate,
        milestones: _state.milestones,
      ),
    );
  }

  CollegePreferences setTarget(String? name) {
    final value = (name == null || name.trim().isEmpty) ? null : name.trim();
    return _update(
      CollegePreferences(
        favorites: _state.favorites,
        target: value,
        examDate: _state.examDate,
        milestones: _state.milestones,
      ),
    );
  }

  /// 设置自定义考试日期；传 null 恢复自动推算。
  CollegePreferences setExamDate(DateTime? date) {
    return _update(
      CollegePreferences(
        favorites: _state.favorites,
        target: _state.target,
        examDate: date,
        milestones: _state.milestones,
      ),
    );
  }

  CollegePreferences addMilestone(String title, DateTime? date) {
    final value = title.trim();
    if (value.isEmpty) return _state;
    final milestone = ExamMilestone(
      id: const Uuid().v4(),
      title: value,
      date: date,
    );
    return _update(
      CollegePreferences(
        favorites: _state.favorites,
        target: _state.target,
        examDate: _state.examDate,
        milestones: [..._state.milestones, milestone],
      ),
    );
  }

  CollegePreferences toggleMilestone(String id) {
    return _update(
      CollegePreferences(
        favorites: _state.favorites,
        target: _state.target,
        examDate: _state.examDate,
        milestones: [
          for (final milestone in _state.milestones)
            if (milestone.id == id)
              ExamMilestone(
                id: milestone.id,
                title: milestone.title,
                date: milestone.date,
                done: !milestone.done,
              )
            else
              milestone,
        ],
      ),
    );
  }

  CollegePreferences removeMilestone(String id) {
    return _update(
      CollegePreferences(
        favorites: _state.favorites,
        target: _state.target,
        examDate: _state.examDate,
        milestones: [
          for (final milestone in _state.milestones)
            if (milestone.id != id) milestone,
        ],
      ),
    );
  }
}
