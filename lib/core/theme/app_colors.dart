import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // 主题背景色
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color surfaceDark = Color(0xFF121212);

  // 主色调 - 静谧蓝
  static const Color primaryLight = Color(0xFF426464);
  static const Color primaryDark = Color(0xFF6B9B9B);

  // 文字颜色
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF8E8E93);
  static const Color textPrimaryDark = Color(0xFFFAFAFA);
  static const Color textSecondaryDark = Color(0xFFB0B0B0);

  // 学科专属色（预设科目）
  static const Color subjectPolitics = Color(0xFF725959); // 政治 - 绛红
  static const Color subjectEnglish = Color(0xFF516074); // 英语 - 雾霾蓝
  static const Color subjectMath = Color(0xFF426464); // 数学 - 豆绿
  static const Color subjectMajor = Color(0xFF8B7B8B); // 专业课 - 灰紫
  static const Color subjectOther = Color(0xFF7A7A7A); // 其他 - 暖灰

  // 预设科目名单（首次启动种子数据，用户可增删）
  static const List<String> presetSubjectNames = [
    '政治',
    '英语',
    '数学',
    '专业课',
    '其他',
  ];

  static const Map<String, Color> presetSubjectColorMap = {
    '政治': subjectPolitics,
    '英语': subjectEnglish,
    '数学': subjectMath,
    '专业课': subjectMajor,
    '其他': subjectOther,
  };

  // 自定义科目的扩展调色板（低饱和莫兰迪系），按序分配未被占用的颜色
  static const List<Color> customSubjectPalette = [
    Color(0xFF6B8E71), // 灰绿
    Color(0xFF5C7A99), // 青蓝
    Color(0xFF995C5C), // 砖红
    Color(0xFF8A6F55), // 驼棕
    Color(0xFF4F7D7D), // 黛青
    Color(0xFFA0785C), // 杏褐
    Color(0xFF77808B), // 蓝灰
    Color(0xFF96819B), // 藕紫
  ];

  // 运行期注册的学科颜色（含自定义与已删除科目的存档色，保证历史记录着色稳定）
  static final Map<String, Color> _registeredSubjectColors = {};

  static void registerSubjectColor(String name, Color color) =>
      _registeredSubjectColors[name] = color;

  // 学科颜色 Map（预设 + 注册的自定义/存档色）
  static Map<String, Color> get subjectColorMap => {
    ...presetSubjectColorMap,
    ..._registeredSubjectColors,
  };

  // 获取学科颜色
  static Color getSubjectColor(String subject) {
    return subjectColorMap[subject] ?? subjectOther;
  }

  // 卡片颜色
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E1E1E);

  // 分割线
  static const Color dividerLight = Color(0xFFE5E5E5);
  static const Color dividerDark = Color(0xFF2C2C2C);

  // 警告色
  static const Color warning = Color(0xFFE67E22);
  static const Color error = Color(0xFFE74C3C);
  static const Color success = Color(0xFF27AE60);
}
