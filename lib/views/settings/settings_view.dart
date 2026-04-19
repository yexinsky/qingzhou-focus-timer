import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../providers/timer_provider.dart';
import 'widgets/setting_tile.dart';

class SettingsView extends ConsumerWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryDark : AppColors.primaryLight;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              _buildSection(
                context,
                title: '专注计时',
                icon: PhosphorIcons.timer(PhosphorIconsStyle.regular),
                children: [
                  _buildDurationTile(
                    context,
                    ref,
                    title: '默认专注时长',
                    subtitle: '设置每次启动时的标准计时',
                    value: settings.focusDuration,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setFocusDuration(value);
                      ref.read(timerProvider.notifier).setDuration(value);
                    },
                  ),
                  _buildDurationTile(
                    context,
                    ref,
                    title: '短休息时长',
                    subtitle: '专注之间的休息时间',
                    value: settings.breakDuration,
                    maxValue: 30,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setBreakDuration(value);
                    },
                  ),
                  _buildDurationTile(
                    context,
                    ref,
                    title: '长休息时长',
                    subtitle: '连续专注后的休息时间',
                    value: settings.longBreakDuration,
                    maxValue: 60,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setLongBreakDuration(value);
                    },
                  ),
                  _buildDurationTile(
                    context,
                    ref,
                    title: '长休息间隔',
                    subtitle: '每 N 个番茄后触发长休息',
                    value: settings.longBreakInterval,
                    minValue: 2,
                    maxValue: 10,
                    unit: '个',
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).setLongBreakInterval(value);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: '自律增强',
                icon: PhosphorIcons.shieldCheck(PhosphorIconsStyle.regular),
                children: [
                  _buildSwitchTile(
                    context,
                    title: '严苛模式',
                    subtitle: '计时期间禁止中途退出专注',
                    value: settings.strictMode,
                    primaryColor: primaryColor,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).toggleStrictMode();
                    },
                  ),
                  _buildSwitchTile(
                    context,
                    title: '自动开启白噪音',
                    subtitle: '沉浸入定后自动播放所选音频',
                    value: settings.autoWhiteNoise,
                    primaryColor: primaryColor,
                    onChanged: (value) {
                      ref.read(settingsProvider.notifier).toggleAutoWhiteNoise();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                title: '系统权限',
                icon: PhosphorIcons.lock(PhosphorIconsStyle.regular),
                children: [
                  SettingTile(
                    title: '通知提醒',
                    subtitle: settings.notificationEnabled
                        ? '已开启：专注结束会发送通知'
                        : '未开启：将无法接收专注结束提醒',
                    icon: settings.notificationEnabled
                        ? null
                        : PhosphorIcons.warning(PhosphorIconsStyle.regular),
                    trailing: TextButton(
                      onPressed: () {
                        // TODO: 打开系统设置
                      },
                      child: Text(
                        settings.notificationEnabled ? '已开启' : '去开启',
                        style: TextStyle(
                          color: settings.notificationEnabled
                              ? AppColors.textSecondary
                              : AppColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    showDivider: true,
                  ),
                  SettingTile(
                    title: '触感反馈',
                    subtitle: '在关键操作时提供细腻的物理反馈',
                    trailing: Transform.scale(
                      scale: 0.8,
                      child: CupertinoSwitch(
                        value: settings.vibrationEnabled,
                        activeTrackColor: primaryColor,
                        onChanged: (value) {
                          ref.read(settingsProvider.notifier).setVibrationEnabled(value);
                        },
                      ),
                    ),
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 48),
              _buildFooter(context),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.5,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
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
            color: isDark ? AppColors.cardDark : AppColors.cardLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDurationTile(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    String? subtitle,
    required int value,
    int minValue = 1,
    int maxValue = 120,
    String unit = '分钟',
    required Function(int) onChanged,
  }) {
    return SettingTile(
      title: title,
      subtitle: subtitle,
      trailing: GestureDetector(
        onTap: () => _showDurationPicker(
          context,
          title: title,
          currentValue: value,
          minValue: minValue,
          maxValue: maxValue,
          onChanged: onChanged,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.dividerLight.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$value',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w300,
                ),
          ),
        ),
      ),
    );
  }

  void _showDurationPicker(
    BuildContext context, {
    required String title,
    required int currentValue,
    int minValue = 1,
    int maxValue = 120,
    required Function(int) onChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DurationPickerSheet(
        title: title,
        currentValue: currentValue,
        minValue: minValue,
        maxValue: maxValue,
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required bool value,
    required Color primaryColor,
    required Function(bool) onChanged,
  }) {
    return SettingTile(
      title: title,
      subtitle: subtitle,
      trailing: Transform.scale(
        scale: 0.8,
        child: CupertinoSwitch(
          value: value,
          activeTrackColor: primaryColor,
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Column(
      children: [
        Text(
          '轻舟 版本 2.4.0',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                letterSpacing: 2,
                color: AppColors.textSecondary.withValues(alpha: 0.5),
              ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '隐私政策',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(width: 24),
            Text(
              '服务条款',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ],
    );
  }
}
