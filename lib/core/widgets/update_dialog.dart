import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/app_update.dart';
import '../services/apk_download_service.dart';
import '../services/apk_install_service.dart';
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

/// [onLaunch]、[installer]、[downloader] 均为测试注入用；
/// 默认 Android 走应用内下载 + 系统安装器，其余平台打开浏览器下载页。
Future<void> showUpdateDialog(
  BuildContext context,
  AppUpdate update, {
  Future<bool> Function(Uri uri)? onLaunch,
  ApkInstallService? installer,
  ApkDownloadService? downloader,
}) => showDialog<void>(
  context: context,
  // 非强制更新：点弹窗外部或返回键等同"下次再说"，下次启动仍会提醒。
  barrierDismissible: true,
  builder: (_) => UpdateDialog(
    update: update,
    onLaunch: onLaunch,
    installer: installer,
    downloader: downloader,
  ),
);

class UpdateDialog extends ConsumerStatefulWidget {
  const UpdateDialog({
    super.key,
    required this.update,
    this.onLaunch,
    this.installer,
    this.downloader,
  });

  final AppUpdate update;
  final Future<bool> Function(Uri uri)? onLaunch;
  final ApkInstallService? installer;
  final ApkDownloadService? downloader;

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _skipChecked = false;
  bool _busy = false;
  late final ApkInstallService _installer =
      widget.installer ?? ApkInstallService();
  late final ApkDownloadService _downloader =
      widget.downloader ?? ApkDownloadService();
  // 缓存 future，避免弹窗每次重建都重取 PackageInfo 造成版本号闪烁。
  late final Future<PackageInfo> _packageInfoFuture =
      PackageInfo.fromPlatform();
  // 对话框的模态遮罩会挡住 SnackBar 的操作按钮，因此失败提示与
  // "浏览器下载"兜底入口内联在弹窗里展示。
  String? _error;
  Uri? _fallbackUri;

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
    if (_busy) return;
    final url = widget.update.downloadUrlFor(Platform.operatingSystem);
    if (url == null) return;
    setState(() => _error = null);
    if (!_installer.isSupported) {
      await _openInBrowser(Uri.parse(url));
      return;
    }
    await _updateInApp(Uri.parse(url));
  }

  /// 应用内更新：申请"安装未知应用"权限 → 下载（可取消）→ 调起系统安装器。
  /// 失败时不关闭弹窗，只在内联区域提示，并保留"浏览器下载"兜底入口。
  Future<void> _updateInApp(Uri uri) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      var granted = await _installer.hasInstallPermission();
      if (!granted) {
        granted = await _installer.requestInstallPermission();
      }
      if (!mounted) return;
      if (!granted) {
        _showError('需要先允许"安装未知应用"才能应用内更新', uri);
        return;
      }

      final outcome = await showDialog<_DownloadOutcome>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _ApkDownloadDialog(
          downloader: _downloader,
          url: uri.toString(),
          version: widget.update.version,
          sha256: widget.update.sha256,
        ),
      );
      if (!mounted || outcome == null || outcome.cancelled) return;
      final file = outcome.file;
      if (file == null) {
        _showError('安装包下载失败，请检查网络后重试', uri);
        return;
      }

      // 先关弹窗再调系统安装器：安装期间应用会退到后台，用户回来时看到正常界面。
      Navigator.of(context).pop();
      try {
        await _installer.installApk(file.path);
      } catch (_) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('无法调起系统安装器，请改用浏览器下载'),
            action: SnackBarAction(
              label: '浏览器下载',
              onPressed: () => _openInBrowser(uri, messenger: messenger),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openInBrowser(
    Uri uri, {
    ScaffoldMessengerState? messenger,
  }) async {
    var opened = false;
    try {
      opened = await (widget.onLaunch ?? _defaultLaunch)(uri) == true;
    } catch (_) {
      opened = false;
    }
    if (!mounted) {
      // 弹窗已关闭的兜底路径（如调起安装器失败后）：只提示，不再关闭弹窗。
      if (!opened) {
        messenger?.showSnackBar(
          const SnackBar(content: Text('无法打开下载链接，请稍后重试')),
        );
      }
      return;
    }
    if (opened) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('无法打开下载链接，请稍后重试')));
    }
  }

  void _showError(String message, Uri fallbackUri) {
    setState(() {
      _error = message;
      _fallbackUri = fallbackUri;
    });
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
              if (_error != null) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _fallbackUri == null
                          ? null
                          : () => _openInBrowser(_fallbackUri!),
                      child: const Text('浏览器下载'),
                    ),
                  ],
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
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('下次再说'),
        ),
        FilledButton(
          onPressed: _busy ? null : _updateNow,
          child: const Text('立即更新'),
        ),
      ],
    );
  }
}

class _DownloadOutcome {
  const _DownloadOutcome({this.file, this.cancelled = false});

  final File? file;
  final bool cancelled;
}

/// 下载进度弹窗：下载完成后以 [_DownloadOutcome] 关闭自身。
class _ApkDownloadDialog extends StatefulWidget {
  const _ApkDownloadDialog({
    required this.downloader,
    required this.url,
    required this.version,
    this.sha256 = '',
  });

  final ApkDownloadService downloader;
  final String url;
  final String version;
  final String sha256;

  @override
  State<_ApkDownloadDialog> createState() => _ApkDownloadDialogState();
}

class _ApkDownloadDialogState extends State<_ApkDownloadDialog> {
  int _received = 0;
  int? _total;
  bool _cancelled = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final file = await widget.downloader.downloadApk(
        widget.url,
        sha256: widget.sha256,
        isCancelled: () => _cancelled,
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      Navigator.of(context).pop(_DownloadOutcome(file: file));
    } on DownloadCancelledException {
      if (!mounted) return;
      Navigator.of(context).pop(const _DownloadOutcome(cancelled: true));
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop(const _DownloadOutcome());
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    double? progress;
    var detail = '已下载 ${_formatBytes(_received)}';
    if (total != null && total > 0) {
      progress = (_received / total).clamp(0.0, 1.0);
      detail =
          '${(progress * 100).toStringAsFixed(0)}%  '
          '${_formatBytes(_received)} / ${_formatBytes(total)}';
    }
    return AlertDialog(
      title: Text('正在下载 v${widget.version}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LinearProgressIndicator(value: progress),
          const SizedBox(height: 12),
          Text(
            detail,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _cancelled
              ? null
              : () => setState(() => _cancelled = true),
          child: Text(_cancelled ? '正在取消…' : '取消'),
        ),
      ],
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}
