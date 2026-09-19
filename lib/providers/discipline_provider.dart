import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/discipline.dart';
import '../data/repositories/discipline_repository.dart';

final disciplineRepositoryProvider = Provider<DisciplineRepository>(
  (ref) => DisciplineRepository(),
);

/// 内置专业目录：首次访问时从资产加载，之后常驻内存。
final disciplineCatalogProvider =
    StateNotifierProvider<
      DisciplineCatalogNotifier,
      AsyncValue<DisciplineCatalog>
    >((ref) {
      return DisciplineCatalogNotifier(ref.watch(disciplineRepositoryProvider));
    });

class DisciplineCatalogNotifier
    extends StateNotifier<AsyncValue<DisciplineCatalog>> {
  DisciplineCatalogNotifier(this._repository)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final DisciplineRepository _repository;

  Future<void> _load() async {
    try {
      final catalog = await _repository.loadCatalog();
      if (mounted) state = AsyncValue.data(catalog);
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// 搜索词（代码或名称片段）。
final disciplineQueryProvider = StateProvider<String>((ref) => '');

/// 选中的学科门类代码，null 表示全部门类。
final disciplineCategoryProvider = StateProvider<String?>((ref) => null);

/// 门类芯片可选项（全量，来自目录本身）。
final disciplineCategoriesProvider = Provider<List<DisciplineCategory>>((ref) {
  final catalog = ref.watch(disciplineCatalogProvider).valueOrNull;
  if (catalog == null) return const [];
  return catalog.categories;
});

/// 按门类与搜索词过滤后的分组结果；搜索时组内仅保留命中条目。
final filteredDisciplineGroupsProvider = Provider<List<DisciplineCategory>>((
  ref,
) {
  final catalog = ref.watch(disciplineCatalogProvider).valueOrNull;
  final query = ref.watch(disciplineQueryProvider).trim();
  final categoryCode = ref.watch(disciplineCategoryProvider);
  if (catalog == null) return const [];
  var groups = catalog.categories;
  if (categoryCode != null) {
    groups = groups.where((group) => group.code == categoryCode).toList();
  }
  if (query.isEmpty) return groups;
  final result = <DisciplineCategory>[];
  for (final group in groups) {
    final items = group.items.where((item) => item.matches(query)).toList();
    if (items.isNotEmpty) {
      result.add(
        DisciplineCategory(code: group.code, name: group.name, items: items),
      );
    }
  }
  return result;
});

/// 是否设置了任何筛选条件（搜索词或门类）。
final disciplineFilterActiveProvider = Provider<bool>((ref) {
  return ref.watch(disciplineQueryProvider).trim().isNotEmpty ||
      ref.watch(disciplineCategoryProvider) != null;
});
