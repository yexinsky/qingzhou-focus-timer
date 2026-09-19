import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/university.dart';
import '../data/repositories/university_repository.dart';
import 'college_preference_provider.dart';

final universityRepositoryProvider = Provider<UniversityRepository>(
  (ref) => UniversityRepository(),
);

/// 内置榜单：首次访问时从资产加载，之后常驻内存。
final universityRankingProvider =
    StateNotifierProvider<
      UniversityRankingNotifier,
      AsyncValue<UniversityRanking>
    >((ref) {
      return UniversityRankingNotifier(ref.watch(universityRepositoryProvider));
    });

class UniversityRankingNotifier
    extends StateNotifier<AsyncValue<UniversityRanking>> {
  UniversityRankingNotifier(this._repository)
    : super(const AsyncValue.loading()) {
    _load();
  }

  final UniversityRepository _repository;

  Future<void> _load() async {
    try {
      final ranking = await _repository.loadRanking();
      if (mounted) state = AsyncValue.data(ranking);
    } catch (error, stackTrace) {
      if (mounted) state = AsyncValue.error(error, stackTrace);
    }
  }
}

/// 排名筛选条件；null 表示不限制。
class UniversityFilter {
  const UniversityFilter({
    this.query = '',
    this.province,
    this.category,
    this.tag,
  });

  final String query;
  final String? province;
  final String? category;
  final String? tag;

  /// 是否未设置任何筛选条件。
  bool get isDefault =>
      query.isEmpty && province == null && category == null && tag == null;
}

final universityFilterProvider =
    StateNotifierProvider<UniversityFilterNotifier, UniversityFilter>((ref) {
      return UniversityFilterNotifier();
    });

class UniversityFilterNotifier extends StateNotifier<UniversityFilter> {
  UniversityFilterNotifier() : super(const UniversityFilter());

  void setQuery(String value) => state = UniversityFilter(
    query: value,
    province: state.province,
    category: state.category,
    tag: state.tag,
  );

  void setProvince(String? value) => state = UniversityFilter(
    query: state.query,
    province: value,
    category: state.category,
    tag: state.tag,
  );

  void setCategory(String? value) => state = UniversityFilter(
    query: state.query,
    province: state.province,
    category: value,
    tag: state.tag,
  );

  void setTag(String? value) => state = UniversityFilter(
    query: state.query,
    province: state.province,
    category: state.category,
    tag: value,
  );

  void reset() => state = const UniversityFilter();
}

/// 按筛选条件过滤院校，返回顺序保持官方排名顺序。
List<University> filterUniversities(
  List<University> universities,
  UniversityFilter filter,
) {
  final query = filter.query.trim();
  return universities.where((university) {
    if (query.isNotEmpty && !university.name.contains(query)) return false;
    if (filter.province != null && university.province != filter.province) {
      return false;
    }
    if (filter.category != null && university.category != filter.category) {
      return false;
    }
    if (filter.tag != null && !university.tags.contains(filter.tag)) {
      return false;
    }
    return true;
  }).toList();
}

final filteredUniversitiesProvider = Provider<List<University>>((ref) {
  final ranking = ref.watch(universityRankingProvider).valueOrNull;
  final filter = ref.watch(universityFilterProvider);
  final favorites = ref.watch(collegePreferenceProvider).favorites;
  if (ranking == null) return const [];
  var universities = ranking.universities;
  if (filter.tag == '意向') {
    // 意向筛选：没有院校带"意向"标签，须绕过 tag 检查改为与收藏集取交集
    universities = filterUniversities(
      universities,
      UniversityFilter(
        query: filter.query,
        province: filter.province,
        category: filter.category,
      ),
    );
    final favoriteSet = favorites.toSet();
    universities = universities
        .where((university) => favoriteSet.contains(university.name))
        .toList();
  } else {
    universities = filterUniversities(universities, filter);
  }
  return universities;
});

/// 榜单中出现的省份，按排名首次出现顺序。
final universityProvincesProvider = Provider<List<String>>((ref) {
  final ranking = ref.watch(universityRankingProvider).valueOrNull;
  if (ranking == null) return const [];
  return {
    for (final university in ranking.universities)
      if (university.province.isNotEmpty) university.province,
  }.toList();
});

/// 榜单中出现的院校类型，按排名首次出现顺序。
final universityCategoriesProvider = Provider<List<String>>((ref) {
  final ranking = ref.watch(universityRankingProvider).valueOrNull;
  if (ranking == null) return const [];
  return {
    for (final university in ranking.universities)
      if (university.category.isNotEmpty) university.category,
  }.toList();
});
