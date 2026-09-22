import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/app_update.dart';
import '../theme/app_colors.dart';
import '../../providers/update_provider.dart';

/// 设置页"检查更新"入口：手动检查不受"跳过此版本"影响，并把结果
/// （新版本弹窗 / 已是最新 / 检查失败）反馈给用户。
Future<void> checkForUpdateManually(BuildContext context, WidgetRef ref) async {
  final result = await ref
      .read(updateProvider.notifier)
      .checkForUpdate(manual: true);
  if (!context.mounted) return;
  final update = result.update;
  if (update != null) {
    await showUpdateDialog(context, update);
  } else if (result.failed) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('检查更新失败，请检查网络后重试')));
  } else {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('当前已是最新版本')));
  }
}

/// [onLaunch] 仅测试注入用，默认调用 url_launcher 拉起浏览器或应用商店。
Future<void> showUpdateDialog(
  BuildContext context,
  AppUpdate update, {
  Future<bool> Function(Uri uri)? onLaunch,
}) => showDialog<void>(
  context: context,
  // 非强制更新：点弹窗外部或返回键等同"下次再说"，下次启动仍会提醒。
  barrierDismissible: true,
  builder: (_) => UpdateDialog(update: update, onLaunch: onLaunch),
);

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({super.key, required this.update, this.onLaunch});

  final AppUpdate update;
  final Future<bool> Function(Uri uri)? onLaunch;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _skipChecked = false;
  // 缓存 future，避免弹窗每次重建都重取 PackageInfo 造成版本号闪烁。
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();

  void _toggleSkip(bool? value) {
    setState(() => _skipChecked = value ?? false);
    final notifier = ref.read(updateProvider.notifier);
    if (_skipChecked) {
      notifier.skipVersion(widget.update.version);
    } else {
      notifier.clearSkippedVersion();
    }
  }

  Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _updateNow() async {
    final url = widget.update.downloadUrlFor(Platform.operatingSystem);
    if (url == null) return;
    var opened = false;
    try {
      opened =
          await (widget.onLaunch ?? _defaultLaunch)(Uri.parse(url)) == true;
    } catch (_) {
      opened = false;
    }
    if (!mounted) return;
    if (opened) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开下载链接，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final update = widget.update;
    return AlertDialog(
      title: const Text('发现新版本'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FutureBuilder<PackageInfo>(
                future: _packageInfoFuture,
                builder: (_, snapshot) {
                  final current = snapshot.hasData
                      ? '（当前版本 v${snapshot.data!.version}）'
                      : '';
                  return Text(
                    'v${update.version}$current',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  );
                },
              ),
              if (update.releaseNotes.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  update.releaseNotes,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(height: 1.5),
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                value: _skipChecked,
                onChanged: _toggleSkip,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '跳过此版本，以后不再提醒',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('下次再说'),
        ),
        FilledButton(onPressed: _updateNow, child: const Text('立即更新')),
      ],
    );
  }
}
