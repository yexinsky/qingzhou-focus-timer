import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/university_provider.dart';
import 'widgets/college_filter_bar.dart';
import 'widgets/university_card.dart';

class CollegeView extends ConsumerStatefulWidget {
  const CollegeView({super.key});

  @override
  ConsumerState<CollegeView> createState() => _CollegeViewState();
}

class _CollegeViewState extends ConsumerState<CollegeView> {
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

  @override
  Widget build(BuildContext context) {
    final rankingAsync = ref.watch(universityRankingProvider);
    final filter = ref.watch(universityFilterProvider);
    final universities = ref.watch(filteredUniversitiesProvider);
    final provinces = ref.watch(universityProvincesProvider);
    final categories = ref.watch(universityCategoriesProvider);
    final ranking = rankingAsync.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 42, 24, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '院校排名',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w300),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ranking == null
                          ? '数据加载中…'
                          : '${ranking.source} · ${ranking.year} · 共 ${ranking.universities.length} 所',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 16),
                    CollegeFilterBar(
                      filter: filter,
                      provinces: provinces,
                      categories: categories,
                      onQueryChanged: (value) => ref
                          .read(universityFilterProvider.notifier)
                          .setQuery(value),
                      onTagChanged: (value) => ref
                          .read(universityFilterProvider.notifier)
                          .setTag(value),
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
                  ? _emptySliver('未找到匹配的院校')
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: UniversityCard(
                              university: universities[index],
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
        ),
      ),
    );
  }

  SliverFillRemaining _emptySliver(String message) {
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
          ],
        ),
      ),
    );
  }
}
