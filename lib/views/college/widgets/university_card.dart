import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/university.dart';
import 'college_tag_colors.dart';

class UniversityCard extends StatelessWidget {
  const UniversityCard({
    super.key,
    required this.university,
    required this.isFavorite,
    required this.onToggleFavorite,
  });

  final University university;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final accent = dark ? AppColors.primaryDark : AppColors.primaryLight;
    final isTop3 =
        university.rank == '1' ||
        university.rank == '2' ||
        university.rank == '3';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? AppColors.cardDark : AppColors.cardLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 高度与名称行（收藏图标 20 + 上下 padding 4）一致，使序号与校名垂直居中对齐
          SizedBox(
            width: 44,
            height: 28,
            child: Center(
              child: Text(
                university.rank,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                  color: isTop3 ? accent : AppColors.textSecondary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        university.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: dark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: onToggleFavorite,
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          isFavorite
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                          size: 20,
                          color: isFavorite
                              ? const Color(0xFFD9A441)
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      university.score ?? '—',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: university.score == null
                            ? (dark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondary)
                            : accent,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (university.province.isNotEmpty ||
                        university.category.isNotEmpty)
                      Text(
                        [
                          if (university.province.isNotEmpty)
                            university.province,
                          if (university.category.isNotEmpty)
                            university.category,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    for (final tag in university.tags) _tagBadge(tag, dark),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagBadge(String tag, bool dark) {
    final color = collegeTagColor(tag, dark: dark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
