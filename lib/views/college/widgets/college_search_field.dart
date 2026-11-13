import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// 院校页统一的搜索输入框。
///
/// 排名页、专业代码页与「选择目标院校」弹层都用它，保证三处描边、
/// 圆角与聚焦反馈完全一致：底色沿用卡片色，外加一圈淡描边——输入区
/// 才从整页留白里「认得出来」；获得焦点时描边加深并换成主色。
class CollegeSearchField extends StatelessWidget {
  const CollegeSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = dark ? AppColors.dividerDark : AppColors.dividerLight;
    final accent = dark ? AppColors.primaryDark : AppColors.primaryLight;

    OutlineInputBorder outline(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );

    return TextField(
      controller: controller,
      autofocus: autofocus,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: const Icon(Icons.search, size: 20),
        isDense: true,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        border: outline(borderColor),
        enabledBorder: outline(borderColor),
        focusedBorder: outline(accent, 1.4),
        disabledBorder: outline(borderColor),
      ),
    );
  }
}
