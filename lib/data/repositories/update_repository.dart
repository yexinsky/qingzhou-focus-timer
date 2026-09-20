import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update.dart';

/// 应用内更新检查：拉取远端版本清单，与当前安装版本比较，并持久化
/// 用户"跳过此版本"的选择。
///
/// 检查结果只决定是否提示，不负责下载与安装：确认更新即打开下载页。
class UpdateRepository {
  UpdateRepository({
    http.Client? client,
    SharedPreferences? prefs,
    PackageInfo? packageInfo,
  }) : _clientOverride = client,
       _prefsOverride = prefs,
       _packageInfoOverride = packageInfo;

  /// 远端版本清单地址。发布新版本时更新仓库内 update/version.json；
  /// 若改用其他托管源（Gitee、自有服务器），替换本常量即可，字段见
  /// [AppUpdate.tryParse]。
  static const String manifestUrl =
      'https://raw.githubusercontent.com/yexinsky/qingzhou-focus-timer/main/update/version.json';

  /// 国内加速代理列表，按顺序尝试，任一成功即返回。
  static const List<String> _proxyPrefixes = [
    'https://ghfast.top/',
    'https://gh-proxy.com/',
  ];

  /// 用户选择"跳过此版本"后记录的版本号。
  static const String _skippedVersionKey = 'update_skipped_version';

  static const Duration _timeout = Duration(seconds: 8);

  final http.Client? _clientOverride;
  final SharedPreferences? _prefsOverride;
  final PackageInfo? _packageInfoOverride;

  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> get _prefs {
    final override = _prefsOverride;
    if (override != null) return Future.value(override);
    return _prefsFuture ??= SharedPreferences.getInstance();
  }

  Future<PackageInfo> get _packageInfo {
    final override = _packageInfoOverride;
    if (override != null) return Future.value(override);
    return PackageInfo.fromPlatform();
  }

  /// 拉取并解析远端清单。先尝试直连，失败后依次尝试加速代理；
  /// 全部失败返回 null——更新检查必须静默失败，绝不阻塞或打断正常启动。
  Future<AppUpdate?> fetchLatestUpdate() async {
    final urls = [manifestUrl, for (final p in _proxyPrefixes) '$p$manifestUrl'];
    final client = _clientOverride ?? http.Client();
    try {
      for (final url in urls) {
        try {
          final response = await client
              .get(Uri.parse(url), headers: {'Accept': 'application/json'})
              .timeout(_timeout);
          if (response.statusCode != 200) continue;
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is! Map<String, dynamic>) continue;
          return AppUpdate.tryParse(decoded);
        } catch (_) {
          continue;
        }
      }
      return null;
    } finally {
      if (_clientOverride == null) client.close();
    }
  }

  /// 远端版本是否比当前安装的新；版本号相同时比较构建号（用于重打包热修）。
  Future<bool> isUpdateAvailable(AppUpdate update) async {
    final info = await _packageInfo;
    if (isNewerVersion(update.version, info.version)) return true;
    if (update.version.trim() == info.version.trim() &&
        update.buildNumber > 0) {
      return update.buildNumber > (int.tryParse(info.buildNumber) ?? 0);
    }
    return false;
  }

  /// 逐段数值比较点分版本号，忽略 "-beta" 之类的后缀；前缀相同的
  /// 短版本号视为相等（1.2 与 1.2.0 等价）。
  static bool isNewerVersion(String remote, String local) {
    final remoteParts = _versionParts(remote);
    final localParts = _versionParts(local);
    final length = remoteParts.length > localParts.length
        ? remoteParts.length
        : localParts.length;
    for (var i = 0; i < length; i++) {
      final remoteValue = i < remoteParts.length ? remoteParts[i] : 0;
      final localValue = i < localParts.length ? localParts[i] : 0;
      if (remoteValue != localValue) return remoteValue > localValue;
    }
    return false;
  }

  static List<int> _versionParts(String version) => version
      .split('-')
      .first
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList();

  Future<String?> getSkippedVersion() async =>
      (await _prefs).getString(_skippedVersionKey);

  Future<void> skipVersion(String version) =>
      _prefs.then((prefs) => prefs.setString(_skippedVersionKey, version));

  Future<void> clearSkippedVersion() =>
      _prefs.then((prefs) => prefs.remove(_skippedVersionKey));
}
