import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/college_preference_provider.dart';
import '../../providers/university_provider.dart';
import 'widgets/college_filter_bar.dart';
import 'widgets/university_card.dart';

/// 院校排名面板：软科榜单的搜索、筛选与列表。
class RankingPane extends ConsumerStatefulWidget {
  const RankingPane({super.key});

  @override
  ConsumerState<RankingPane> createState() => _RankingPaneState();
}

class _RankingPaneState extends ConsumerState<RankingPane> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // 筛选状态常驻 Provider，重新进入 tab 时恢复搜索词
    _searchController = TextEditingController(
      text: ref.read(universityFilterProvider).query,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// 清空搜索框与全部筛选条件；两处需同步，避免列表与搜索框状态不一致。
  void _clearFilters() {
    _searchController.clear();
    ref.read(universityFilterProvider.notifier).reset();
  }

  @override
  Widget build(BuildContext context) {
    final rankingAsync = ref.watch(universityRankingProvider);
    final filter = ref.watch(universityFilterProvider);
    final universities = ref.watch(filteredUniversitiesProvider);
    final favorites = ref.watch(collegePreferenceProvider).favorites;
    final provinces = ref.watch(universityProvincesProvider);
    final categories = ref.watch(universityCategoriesProvider);
    final ranking = rankingAsync.valueOrNull;
    final hasActiveFilter = !filter.isDefault;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ranking == null
                      ? '数据加载中…'
                      : hasActiveFilter
                      ? '已匹配 ${universities.length} / ${ranking.universities.length} 所'
                      : '${ranking.source} · ${ranking.year} · 共 ${ranking.universities.length} 所',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                CollegeFilterBar(
                  filter: filter,
                  searchController: _searchController,
                  provinces: provinces,
                  categories: categories,
                  onQueryChanged: (value) => ref
                      .read(universityFilterProvider.notifier)
                      .setQuery(value),
                  onTagChanged: (value) =>
                      ref.read(universityFilterProvider.notifier).setTag(value),
                  onProvinceChanged: (value) => ref
                      .read(universityFilterProvider.notifier)
                      .setProvince(value),
                  onCategoryChanged: (value) => ref
                      .read(universityFilterProvider.notifier)
                      .setCategory(value),
                ),
              ],
            ),
          ),
        ),
        rankingAsync.when(
          data: (_) => universities.isEmpty
              ? _emptySliver(
                  '未找到匹配的院校',
                  onClear: hasActiveFilter ? _clearFilters : null,
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: UniversityCard(
                          university: universities[index],
                          isFavorite: favorites.contains(
                            universities[index].name,
                          ),
                          onToggleFavorite: () => ref
                              .read(collegePreferenceProvider.notifier)
                              .toggleFavorite(universities[index].name),
                        ),
                      ),
                      childCount: universities.length,
                    ),
                  ),
                ),
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _emptySliver('榜单数据加载失败'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  SliverFillRemaining _emptySliver(String message, {VoidCallback? onClear}) {
    return SliverFillRemaining(
      hasScrollBody: false,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.school_outlined,
              size: 60,
              color: AppColors.textSecondary.withValues(alpha: .3),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (onClear != null) ...[
              const SizedBox(height: 8),
              TextButton(onPressed: onClear, child: const Text('清除筛选条件')),
            ],
          ],
        ),
      ),
    );
  }
}
