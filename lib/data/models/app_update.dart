/// 远端更新清单（update/version.json）的解析结果。
class AppUpdate {
  const AppUpdate({
    required this.version,
    this.buildNumber = 0,
    this.releaseNotes = '',
    this.downloadUrl = '',
    this.downloadUrls = const {},
    this.sha256 = '',
  });

  final String version;

  /// 同版本号重新打包时的构建号，清单未提供时为 0（不参与比较）。
  final int buildNumber;

  final String releaseNotes;

  /// 各平台通用下载地址。
  final String downloadUrl;

  /// 按平台覆盖下载地址，键为 Platform.operatingSystem（android / ios / …）。
  final Map<String, String> downloadUrls;

  /// APK 的 SHA-256（十六进制，大小写不敏感）。清单提供时，
  /// 应用内下载完成后会校验，不通过则拒绝安装。
  final String sha256;

  /// 解析失败（缺 version 或没有任何下载地址）时返回 null，由调用方静默忽略。
  static AppUpdate? tryParse(Map<String, dynamic> json) {
    final version = (json['version'] ?? '').toString().trim();
    if (version.isEmpty) return null;

    final platformUrls = <String, String>{};
    final rawPlatformUrls = json['downloadUrls'];
    if (rawPlatformUrls is Map) {
      rawPlatformUrls.forEach((key, value) {
        final url = value?.toString().trim() ?? '';
        if (key != null && url.isNotEmpty) platformUrls[key.toString()] = url;
      });
    }

    final downloadUrl = (json['downloadUrl'] ?? '').toString().trim();
    if (downloadUrl.isEmpty && platformUrls.isEmpty) return null;

    return AppUpdate(
      version: version,
      buildNumber: int.tryParse('${json['buildNumber'] ?? ''}') ?? 0,
      releaseNotes: (json['releaseNotes'] ?? '').toString(),
      downloadUrl: downloadUrl,
      downloadUrls: Map.unmodifiable(platformUrls),
      sha256: (json['sha256'] ?? '').toString().trim(),
    );
  }

  String? downloadUrlFor(String platform) =>
      downloadUrls[platform] ?? (downloadUrl.isEmpty ? null : downloadUrl);
}
