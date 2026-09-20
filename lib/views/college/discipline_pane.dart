import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../data/models/discipline.dart';
import '../../providers/discipline_provider.dart';

/// 专业代码面板：按门类浏览、按代码或名称搜索研究生学科专业目录。
class DisciplinePane extends ConsumerStatefulWidget {
  const DisciplinePane({super.key});

  @override
  ConsumerState<DisciplinePane> createState() => _DisciplinePaneState();
}

class _DisciplinePaneState extends ConsumerState<DisciplinePane> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    // 查询状态常驻 Provider，重新进入 tab 时恢复搜索词
    _searchController = TextEditingController(
      text: ref.read(disciplineQueryProvider),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clearFilters() {
    _searchController.clear();
    ref.read(disciplineQueryProvider.notifier).state = '';
    ref.read(disciplineCategoryProvider.notifier).state = null;
  }

  @override
  Widget build(BuildContext context) {
    final catalogAsync = ref.watch(disciplineCatalogProvider);
    final groups = ref.watch(filteredDisciplineGroupsProvider);
    final categories = ref.watch(disciplineCategoriesProvider);
    final categoryCode = ref.watch(disciplineCategoryProvider);
    final query = ref.watch(disciplineQueryProvider).trim();
    final catalog = catalogAsync.valueOrNull;
    final filterActive = query.isNotEmpty || categoryCode != null;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  catalog == null
                      ? '数据加载中…'
                      : '${catalog.source} · ${catalog.edition} 年版 · '
                            '共 ${catalog.totalCount} 项',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _searchController,
                  onChanged: (value) =>
                      ref.read(disciplineQueryProvider.notifier).state = value,
                  decoration: InputDecoration(
                    hintText: '搜索代码或名称，如 0812 / 计算机',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    filled: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  clipBehavior: Clip.none,
                  child: Row(
                    children: [
                      _categoryChip(context, null, '全部'),
                      for (final category in categories)
                        _categoryChip(context, category.code, category.name),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        catalogAsync.when(
          data: (_) => groups.isEmpty
              ? _emptySliver(
                  '未找到匹配的专业代码',
                  onClear: filterActive ? _clearFilters : null,
                )
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _CategorySection(
                        key: ValueKey('${groups[index].code}-$filterActive'),
                        group: groups[index],
                        initiallyExpanded: query.isNotEmpty,
                      ),
                      childCount: groups.length,
                    ),
                  ),
                ),
          loading: () => const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (_, _) => _emptySliver('目录数据加载失败'),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 110)),
      ],
    );
  }

  Widget _categoryChip(BuildContext context, String? value, String label) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = ref.watch(disciplineCategoryProvider) == value;
    final textColor = selected
        ? (dark ? AppColors.surfaceDark : Colors.white)
        : (dark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () =>
            ref.read(disciplineCategoryProvider.notifier).state = value,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? (dark ? AppColors.primaryDark : AppColors.primaryLight)
                : (dark ? AppColors.cardDark : AppColors.cardLight),
            borderRadius: BorderRadius.circular(10),
            border: selected
                ? null
                : Border.all(
                    color: dark
                        ? AppColors.dividerDark
                        : AppColors.dividerLight,
                  ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
            ),
          ),
        ),
      ),
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
              Icons.menu_book_outlined,
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

/// 一个学科门类的分组展示：未搜索时折叠，搜索态全部展开。
class _CategorySection extends StatelessWidget {
  const _CategorySection({
    super.key,
    required this.group,
    required this.initiallyExpanded,
  });

  final DisciplineCategory group;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: dark ? AppColors.cardDark : AppColors.cardLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16),
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          collapsedShape: const Border(),
          title: Row(
            children: [
              Text(
                '${group.code} ${group.name}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: dark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${group.items.length} 项',
                style: TextStyle(
                  fontSize: 12,
                  color: dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
          children: [
            for (final item in group.items) _ItemTile(item: item, dark: dark),
          ],
        ),
      ),
    );
  }
}

class _ItemTile extends StatelessWidget {
  const _ItemTile({required this.item, required this.dark});

  final DisciplineItem item;
  final bool dark;

  Color get _accent => dark ? AppColors.primaryDark : AppColors.primaryLight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              item.code,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _accent,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (item.note != null)
                      Text(
                        item.note!,
                        style: TextStyle(
                          fontSize: 12,
                          color: dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    _badge(item.professional ? '专业学位' : '一级学科'),
                    if (item.professional && item.doctoral) _badge('可授博士'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: dark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: _accent,
        ),
      ),
    );
  }
}
