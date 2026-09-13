import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/subject_repository.dart';

final subjectRepositoryProvider = Provider<SubjectRepository>(
  (ref) => SubjectRepository(),
);

final subjectsProvider = StateNotifierProvider<SubjectsNotifier,
    List<SubjectOption>>((ref) {
  return SubjectsNotifier(ref.watch(subjectRepositoryProvider));
});

class SubjectsNotifier extends StateNotifier<List<SubjectOption>> {
  final SubjectRepository _repository;

  /// 仓库在应用启动时已完成初始化（含预设种子与颜色注册），构造时直接同步。
  SubjectsNotifier(this._repository) : super(_repository.subjects);

  Future<bool> add(String name) async {
    final changed = await _repository.add(name);
    if (changed) state = _repository.subjects;
    return changed;
  }

  Future<bool> remove(String name) async {
    final changed = await _repository.remove(name);
    if (changed) state = _repository.subjects;
    return changed;
  }
}
