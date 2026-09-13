import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/app_colors.dart';

/// 一个可选的学科条目（名称 + 稳定颜色）。
class SubjectOption {
  final String name;
  final int colorValue;

  const SubjectOption({required this.name, required this.colorValue});

  Color get color => Color(colorValue);

  Map<String, dynamic> toJson() => {'name': name, 'color': colorValue};

  factory SubjectOption.fromJson(Map<String, dynamic> json) => SubjectOption(
    name: json['name'] as String,
    colorValue: json['color'] as int,
  );
}

/// 学科配置仓库：学科列表用户可增删，持久化到 SharedPreferences。
///
/// 被删除的学科进入存档区，颜色保留在 [AppColors] 注册表里，
/// 让历史专注记录与统计仍按原学科色渲染；再次添加同名学科时恢复原色。
class SubjectRepository {
  static const String _storageKey = 'subject_config_v1';

  late SharedPreferences _prefs;
  List<SubjectOption> _active = const [];
  List<SubjectOption> _archived = const [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final raw = _prefs.getString(_storageKey);
    if (raw == null) {
      _active = [
        for (final name in AppColors.presetSubjectNames)
          SubjectOption(
            name: name,
            colorValue: AppColors.presetSubjectColorMap[name]!.toARGB32(),
          ),
      ];
      _archived = const [];
      await _persist();
    } else {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        _active = _decodeList(data['active']);
        _archived = _decodeList(data['archived']);
        if (_active.isEmpty && _archived.isEmpty) {
          _active = _defaultSubjects();
          await _persist();
        }
      } catch (_) {
        _active = _defaultSubjects();
        _archived = const [];
        await _persist();
      }
    }
    _syncColorRegistry();
  }

  /// 当前可选学科列表（顺序即展示顺序）。
  List<SubjectOption> get subjects => List.unmodifiable(_active);

  /// 新增学科。同名（含已删除的）不会重复：已存档的同名学科会被恢复并保留原色。
  /// 返回是否发生了变更。
  Future<bool> add(String rawName) async {
    final name = rawName.trim();
    if (name.isEmpty) return false;
    if (_active.any((s) => s.name == name)) return false;

    final archivedIndex = _archived.indexWhere((s) => s.name == name);
    if (archivedIndex >= 0) {
      final restored = _archived.removeAt(archivedIndex);
      _active.add(restored);
    } else {
      _active = [
        ..._active,
        SubjectOption(name: name, colorValue: _nextColor().toARGB32()),
      ];
    }
    _syncColorRegistry();
    await _persist();
    return true;
  }

  /// 删除学科（移入存档区，颜色保留供历史数据渲染）。返回是否发生了变更。
  Future<bool> remove(String name) async {
    final index = _active.indexWhere((s) => s.name == name);
    if (index < 0) return false;
    final removed = _active.removeAt(index);
    if (!_archived.any((s) => s.name == removed.name)) {
      _archived = [..._archived, removed];
    }
    await _persist();
    return true;
  }

  /// 为新学科分配颜色：优先取调色板中未被现有学科占用的颜色，全部占用时循环取色。
  Color _nextColor() {
    final used = _active.map((s) => Color(s.colorValue)).toSet();
    return AppColors.customSubjectPalette.firstWhere(
      (color) => !used.contains(color),
      orElse: () => AppColors.customSubjectPalette[_active.length %
          AppColors.customSubjectPalette.length],
    );
  }

  void _syncColorRegistry() {
    for (final subject in [..._active, ..._archived]) {
      AppColors.registerSubjectColor(subject.name, subject.color);
    }
  }

  List<SubjectOption> _decodeList(dynamic raw) => (raw as List<dynamic>? ?? [])
      .map(
        (item) => SubjectOption.fromJson((item as Map<String, dynamic>)),
      )
      .toList();

  List<SubjectOption> _defaultSubjects() => [
    for (final name in AppColors.presetSubjectNames)
      SubjectOption(
        name: name,
        colorValue: AppColors.presetSubjectColorMap[name]!.toARGB32(),
      ),
  ];

  Future<void> _persist() => _prefs.setString(
    _storageKey,
    jsonEncode({
      'active': [for (final s in _active) s.toJson()],
      'archived': [for (final s in _archived) s.toJson()],
    }),
  );
}
