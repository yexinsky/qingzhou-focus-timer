import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/adaptive_bottom_sheet.dart';
import '../../core/widgets/update_dialog.dart';
import '../widgets/battery_guide_sheet.dart';
import '../../providers/data_management_provider.dart';
import '../../providers/session_feedback_provider.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timer_provider.dart';
import '../../providers/update_provider.dart';
import 'widgets/setting_tile.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final busy = ref.watch(dataManagementProvider);
    final updateChecking = ref.watch(
      updateProvider.select((state) => state.checking),
    );
    final primaryColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.primaryDark
        : AppColors.primaryLight;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const SizedBox(height: 60),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '设置',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '定制您的沉浸式学习仪式',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 32),
            _section(context, '专注计时', Icons.timer_outlined, [
              _duration(
                context,
                '默认专注时长',
                '设置每次启动时的标准计时',
                settings.focusDuration,
                (v) {
                  ref.read(settingsProvider.notifier).setFocusDuration(v);
                  ref.read(timerProvider.notifier).setDuration(v);
                },
              ),
              _duration(
                context,
                '短休息时长',
                '专注之间的休息时间',
                settings.breakDuration,
                (v) => ref.read(settingsProvider.notifier).setBreakDuration(v),
                max: 30,
              ),
              _duration(
                context,
                '长休息时长',
                '连续专注后的休息时间',
                settings.longBreakDuration,
                (v) =>
                    ref.read(settingsProvider.notifier).setLongBreakDuration(v),
                max: 60,
              ),
              _duration(
                context,
                '长休息间隔',
                '每 N 个番茄后触发长休息',
                settings.longBreakInterval,
                (v) =>
                    ref.read(settingsProvider.notifier).setLongBreakInterval(v),
                min: 2,
                max: 10,
                unit: '个',
              ),
            ]),
            const SizedBox(height: 24),
            _section(context, '自律增强', Icons.shield_outlined, [
              _switch(
                context,
                '严苛模式',
                '放弃专注时进行二次确认',
                settings.strictMode,
                primaryColor,
                (_) => ref.read(settingsProvider.notifier).toggleStrictMode(),
              ),
              _switch(
                context,
                '屏幕常亮',
                '专注进行时保持亮屏，防止中途锁定打断沉浸',
                settings.screenAlwaysOn,
                primaryColor,
                (v) => ref.read(settingsProvider.notifier).setScreenAlwaysOn(v),
              ),
              SettingTile(
                title: '白噪音',
                subtitle: '音频素材与播放功能尚未提供',
                trailing: Text(
                  '即将推出',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 24),
            _section(context, '系统权限', Icons.lock_outline, [
              SettingTile(
                title: '通知提醒',
                subtitle: settings.notificationEnabled
                    ? '已开启：专注结束会发送通知'
                    : '未开启：将无法接收专注结束提醒',
                icon: settings.notificationEnabled
                    ? null
                    : Icons.warning_amber_rounded,
                trailing: TextButton(
                  onPressed: () async {
                    if (!settings.notificationEnabled) {
                      final granted = await ref
                          .read(sessionFeedbackServiceProvider)
                          .requestNotificationPermission();
                      await ref
                          .read(settingsProvider.notifier)
                          .setNotificationEnabled(granted);
                      if (granted) return;
                    }
                    await ref
                        .read(sessionFeedbackServiceProvider)
                        .openNotificationSettings();
                  },
                  child: Text(settings.notificationEnabled ? '系统设置' : '去开启'),
                ),
              ),
              if (Platform.isAndroid) const _BatteryOptimizationTile(),
              _switch(
                context,
                '触感反馈',
                '计时结束时提供震动反馈',
                settings.vibrationEnabled,
                primaryColor,
                (v) =>
                    ref.read(settingsProvider.notifier).setVibrationEnabled(v),
                divider: false,
              ),
            ]),
            const SizedBox(height: 24),
            _section(context, '数据管理', Icons.storage_outlined, [
              SettingTile(
                title: '专注历史',
                subtitle: '查看并管理全部专注记录',
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/settings/history'),
              ),
              SettingTile(
                title: '导出备份',
                subtitle: '生成包含任务和专注记录的 JSON 文件',
                trailing: const Icon(Icons.ios_share),
                onTap: busy ? null : () => _exportBackup(context, ref),
              ),
              SettingTile(
                title: '导入备份',
                subtitle: '将当前数据替换为所选备份内容',
                trailing: const Icon(Icons.file_open_outlined),
                onTap: busy ? null : () => _importBackup(context, ref),
              ),
              SettingTile(
                title: '清空全部数据',
                subtitle: '永久删除任务和专注记录',
                showDivider: false,
                trailing: const Icon(
                  Icons.delete_forever_outlined,
                  color: AppColors.error,
                ),
                onTap: busy ? null : () => _clearAllData(context, ref),
              ),
            ]),
            const SizedBox(height: 24),
            _section(context, '关于', Icons.info_outline, [
              SettingTile(
                title: '检查更新',
                subtitle: '每次启动会自动检查，也可在此手动检查',
                showDivider: false,
                trailing: updateChecking
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                onTap: updateChecking
                    ? null
                    : () => checkForUpdateManually(context, ref),
              ),
            ]),
            const SizedBox(height: 48),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: .6),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.5,
                  color: AppColors.textSecondary.withValues(alpha: .6),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: dark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _duration(
    BuildContext context,
    String title,
    String subtitle,
    int value,
    ValueChanged<int> changed, {
    int min = 1,
    int max = 120,
    String unit = '分钟',
  }) => SettingTile(
    title: title,
    subtitle: subtitle,
    trailing: TextButton(
      onPressed: () => showAdaptiveBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => DurationPickerSheet(
          title: title,
          currentValue: value,
          minValue: min,
          maxValue: max,
          onChanged: changed,
        ),
      ),
      child: Text('$value $unit'),
    ),
  );

  Widget _switch(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    Color color,
    ValueChanged<bool> changed, {
    bool divider = true,
  }) => SettingTile(
    title: title,
    subtitle: subtitle,
    showDivider: divider,
    trailing: Transform.scale(
      scale: .8,
      child: CupertinoSwitch(
        value: value,
        activeTrackColor: color,
        onChanged: changed,
      ),
    ),
  );

  Widget _footer(BuildContext context) => FutureBuilder<PackageInfo>(
    future: PackageInfo.fromPlatform(),
    builder: (_, snapshot) {
      final version = snapshot.hasData
          ? '${snapshot.data!.version}+${snapshot.data!.buildNumber}'
          : '—';
      return Column(
        children: [
          Text(
            '轻舟 版本 $version',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 2,
              color: AppColors.textSecondary.withValues(alpha: .5),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '隐私政策与服务条款将在正式发布前提供',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary.withValues(alpha: .7),
            ),
          ),
        ],
      );
    },
  );

  Future<void> _exportBackup(BuildContext context, WidgetRef ref) async {
    try {
      final file = await ref
          .read(dataManagementProvider.notifier)
          .run((service) => service.exportToFile());
      if (!context.mounted) return;
      await Share.shareXFiles([XFile(file.path)], subject: '轻舟数据备份');
    } catch (error) {
      if (context.mounted) _showError(context, '导出失败：$error');
    }
  }

  Future<void> _importBackup(BuildContext context, WidgetRef ref) async {
    final selection = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    final path = selection?.files.single.path;
    if (path == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入并替换当前数据？'),
        content: const Text('导入会先验证备份，然后替换当前全部任务和专注记录。建议操作前先导出当前数据。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final summary = await ref
          .read(dataManagementProvider.notifier)
          .run((service) => service.importFromFile(File(path)));
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '导入完成：${summary.taskCount} 项任务，${summary.sessionCount} 条专注记录',
            ),
          ),
        );
    } catch (error) {
      if (context.mounted) _showError(context, '导入失败，当前数据未更改：$error');
    }
  }

  Future<void> _clearAllData(BuildContext context, WidgetRef ref) async {
    final first = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空全部数据？'),
        content: const Text('所有任务和专注记录都会永久删除。设置项不会被清除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('继续'),
          ),
        ],
      ),
    );
    if (first != true || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('再次确认'),
        content: const Text('此操作无法撤销。确定永久清空任务与专注记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留数据'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('永久清空'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(dataManagementProvider.notifier).clearAllData();
      if (context.mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('任务和专注记录已清空')));
    } catch (error) {
      if (context.mounted) _showError(context, '清空失败：$error');
    }
  }

  void _showError(BuildContext context, String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));
}

/// 电池优化白名单状态查询与申请入口，附各机型后台设置路径指引。
class _BatteryOptimizationTile extends ConsumerStatefulWidget {
  const _BatteryOptimizationTile();

  @override
  ConsumerState<_BatteryOptimizationTile> createState() =>
      _BatteryOptimizationTileState();
}

class _BatteryOptimizationTileState
    extends ConsumerState<_BatteryOptimizationTile> {
  bool? _ignoring;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final status = await Permission.ignoreBatteryOptimizations.status;
    if (!mounted) return;
    setState(() => _ignoring = status.isGranted);
  }

  Future<void> _request() async {
    await Permission.ignoreBatteryOptimizations.request();
    await _refresh();
    if (!mounted) return;
    if (_ignoring != true) await BatteryGuideSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final ignoring = _ignoring;
    return SettingTile(
      title: '电池优化白名单',
      subtitle: ignoring == null
          ? '正在检查电池优化状态…'
          : ignoring
          ? '已忽略电池优化，后台计时更稳定'
          : '未忽略：后台计时可能被系统中断；点按查看各机型设置路径',
      icon: ignoring == false ? Icons.warning_amber_rounded : null,
      onTap: () => BatteryGuideSheet.show(context),
      trailing: TextButton(
        onPressed: ignoring == false
            ? _request
            : () => BatteryGuideSheet.show(context),
        child: Text(ignoring == false ? '去开启' : '设置路径'),
      ),
    );
  }
}
