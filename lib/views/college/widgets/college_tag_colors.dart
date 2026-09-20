import 'package:flutter/material.dart';

/// 院校层次标签（双一流/985/211）的专属配色，取自项目莫兰迪扩展色板：
/// 双一流=灰绿、985=砖红、211=青蓝、意向=驼棕，同色系明暗有别，便于一眼区分院校层次。
Color collegeTagColor(String tag, {required bool dark}) {
  final Color base = switch (tag) {
    '双一流' => const Color(0xFF6B8E71),
    '985' => const Color(0xFF995C5C),
    '211' => const Color(0xFF5C7A99),
    '意向' => const Color(0xFF8A6F55),
    _ => const Color(0xFF7A7A7A),
  };
  // 深色模式下底色很暗，向白色提亮以保持徽章文字对比度
  return dark ? Color.lerp(base, Colors.white, 0.25)! : base;
}
