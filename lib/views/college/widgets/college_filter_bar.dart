import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/layout_utils.dart';
import '../../../core/widgets/adaptive_bottom_sheet.dart';
import '../../../providers/university_provider.dart';
import 'college_search_field.dart';
import 'college_tag_colors.dart';

/// 排名筛选栏：搜索框 + 标签胶囊（全部/双一流/985/211）+ 省份、类型选择按钮。
class CollegeFilterBar extends StatelessWidget {
  const CollegeFilterBar({
    super.key,
    required this.filter,
    required this.searchController,
    required this.provinces,
    required this.categories,
    required this.onQueryChanged,
    required this.onTagChanged,
    required this.onProvinceChanged,
    required this.onCategoryChanged,
  });

  final UniversityFilter filter;
  final TextEditingController searchController;
  final List<String> provinces;
  final List<String> categories;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String?> onProvinceChanged;
  final ValueChanged<String?> onCategoryChanged;

  static const List<String> _tagOptions = ['双一流', '985', '211', '意向'];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CollegeSearchField(
          controller: searchController,
          hintText: '搜索院校名称',
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          child: Row(
            children: [
              _tagChip(context, null, '全部'),
              for (final tag in _tagOptions) _tagChip(context, tag, tag),
              const SizedBox(width: 8),
              _selectButton(
                context,
                label: '省份',
                value: filter.province,
                onTap: () => _showOptionSheet(
                  context,
                  title: '选择省份',
                  options: provinces,
                  selected: filter.province,
                  onSelected: onProvinceChanged,
                ),
              ),
              const SizedBox(width: 8),
              _selectButton(
                context,
                label: '类型',
                value: filter.category,
                onTap: () => _showOptionSheet(
                  context,
                  title: '选择类型',
                  options: categories,
                  selected: filter.category,
                  onSelected: onCategoryChanged,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _tagChip(BuildContext context, String? value, String label) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final selected = filter.tag == value;
    // 选中态用实色填充+反白文字，未选中态描边+正文色，避免看起来像禁用
    final fillColor = selected
        ? value == null
              ? (dark ? AppColors.primaryDark : AppColors.primaryLight)
              : collegeTagColor(value, dark: dark)
        : null;
    final textColor = selected
        ? (dark ? AppColors.surfaceDark : Colors.white)
        : (dark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onTagChanged(value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: selected
                ? fillColor
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

  Widget _selectButton(
    BuildContext context, {
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final active = value != null;
    final textColor = active
        ? (dark ? AppColors.surfaceDark : Colors.white)
        : (dark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? (dark ? AppColors.primaryDark : AppColors.primaryLight)
              : (dark ? AppColors.cardDark : AppColors.cardLight),
          borderRadius: BorderRadius.circular(10),
          border: active
              ? null
              : Border.all(
                  color: dark ? AppColors.dividerDark : AppColors.dividerLight,
                ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value ?? label,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
            const SizedBox(width: 2),
            Icon(Icons.keyboard_arrow_down, size: 16, color: textColor),
          ],
        ),
      ),
    );
  }

  void _showOptionSheet(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String? selected,
    required ValueChanged<String?> onSelected,
  }) {
    showAdaptiveBottomSheet(
      context: context,
      builder: (sheetContext) {
        final dark = Theme.of(sheetContext).brightness == Brightness.dark;
        // 面板高度按屏幕可用高度取比例（矮屏 / 横屏自动变矮），
        // 选项列表在其中滚动，避免固定 360 在横屏时超出屏幕。
        final maxContentHeight =
            (LayoutUtils.availableHeight(sheetContext) * .7).clamp(
              180.0,
              480.0,
            );
        return Container(
          decoration: BoxDecoration(
            color: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxContentHeight),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(sheetContext).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        _optionTile(
                          sheetContext,
                          '全部',
                          null,
                          selected,
                          onSelected,
                        ),
                        for (final option in options)
                          _optionTile(
                            sheetContext,
                            option,
                            option,
                            selected,
                            onSelected,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _optionTile(
    BuildContext context,
    String label,
    String? value,
    String? selected,
    ValueChanged<String?> onSelected,
  ) {
    final isSelected = selected == value;
    // 外面那层 Container 自带背景色，ListTile 的水波纹画在更上层的 Material 上
    // 会被遮住（框架会报 "ink splashes may be invisible" 断言）。这里给每个
    // 选项自己一层透明 Material 承接水波纹，视觉与交互都不变。
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          label,
          style: TextStyle(
            color: isSelected ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
        trailing: isSelected
            ? Icon(
                Icons.check,
                size: 18,
                color: Theme.of(context).colorScheme.primary,
              )
            : null,
        onTap: () {
          onSelected(value);
          Navigator.of(context).pop();
        },
      ),
    );
  }
}
