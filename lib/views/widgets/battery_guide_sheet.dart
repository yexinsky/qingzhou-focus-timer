import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_bottom_sheet.dart';

class _RomGuide {
  final String brand;
  final String path;
  const _RomGuide(this.brand, this.path);
}

const _romGuides = <_RomGuide>[
  _RomGuide('小米 / 红米 (MIUI)', '设置 → 应用设置 → 应用管理 → 轻舟 → 省电策略 → 无限制；并在 自启动管理 中允许轻舟自启动'),
  _RomGuide('华为 / 荣耀 (EMUI)', '设置 → 电池 → 更多电池设置 关闭"休眠时始终保持网络连接"后，进入 应用启动管理 → 轻舟 → 关闭自动管理，手动开启全部允许'),
  _RomGuide('OPPO / 一加 (ColorOS)', '设置 → 电池 → 应用耗电管理 → 轻舟 → 允许完全后台行为 / 关闭智能后台管控'),
  _RomGuide('vivo / iQOO (OriginOS)', '设置 → 电池 → 后台功耗管理 → 轻舟 → 允许后台高耗电；设置 → 应用 → 轻舟 → 自启动开启'),
  _RomGuide('三星 (One UI)', '设置 → 电池 → 后台使用限制 → 确保"轻舟"不在休眠应用 / 深度休眠应用列表中'),
  _RomGuide('原生 Android / 其他', '长按轻舟图标 → 应用信息 → 电池 → 选择"无限制 / 不受限制"'),
];

/// 电池优化白名单的各 ROM 设置路径指引。
class BatteryGuideSheet extends StatelessWidget {
  const BatteryGuideSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAdaptiveBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const BatteryGuideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Text(
                '各机型后台设置路径',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Text(
                '开启"忽略电池优化"后，建议再按机型检查自启动与后台权限，'
                '避免专注计时在后台被系统中断。',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 12),
            for (final guide in _romGuides)
              ListTile(
                dense: true,
                leading: Icon(
                  Icons.phone_android_outlined,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                title: Text(guide.brand),
                subtitle: Text(
                  guide.path,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }
}
