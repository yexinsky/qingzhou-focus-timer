import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../data/repositories/update_repository.dart';

/// 用户取消了下载。
class DownloadCancelledException implements Exception {
  const DownloadCancelledException();

  @override
  String toString() => 'DownloadCancelledException';
}

/// 所有候选地址（直连 + 加速代理）都失败。
class DownloadFailedException implements Exception {
  const DownloadFailedException(this.cause);

  final Object? cause;

  @override
  String toString() => 'DownloadFailedException($cause)';
}

/// 下载完成但 sha256 校验不通过（文件损坏或与清单不符）。
class DownloadIntegrityException implements Exception {
  const DownloadIntegrityException({
    required this.expected,
    required this.actual,
  });

  final String expected;
  final String actual;

  @override
  String toString() =>
      'DownloadIntegrityException(expected: $expected, actual: $actual)';
}

/// APK 下载服务：地址策略与清单获取一致（直连失败依次尝试加速代理），
/// 流式写入应用缓存目录（cacheDir/update/），支持进度回调、中途取消，
/// 以及清单提供 sha256 时的完整性校验。
class ApkDownloadService {
  ApkDownloadService({http.Client? client, Directory? targetDir})
    : _clientOverride = client,
      _dirOverride = targetDir;

  /// 建立连接（等到响应头）的超时。
  static const Duration _connectTimeout = Duration(seconds: 20);

  /// 两次收到数据之间的最长间隔，用于识别卡死的连接。
  static const Duration _stallTimeout = Duration(seconds: 30);

  /// 进度回调节流：每累计 256KB 回调一次，避免逐块重建 UI。
  static const int _progressStepBytes = 256 * 1024;

  final http.Client? _clientOverride;
  final Directory? _dirOverride;

  Future<Directory> _targetDir() async {
    final override = _dirOverride;
    if (override != null) return override;
    final cache = await getTemporaryDirectory();
    return Directory('${cache.path}${Platform.pathSeparator}update');
  }

  /// 下载 [url] 指向的 APK，成功后返回本地文件。
  ///
  /// [onProgress] 收到（已下载字节, 总字节或 null）；[isCancelled] 返回 true
  /// 时抛 [DownloadCancelledException] 并清掉半成品；[sha256] 非空时校验通过才返回。
  Future<File> downloadApk(
    String url, {
    required void Function(int received, int? total) onProgress,
    bool Function()? isCancelled,
    String sha256 = '',
  }) async {
    final candidates = [
      url,
      for (final prefix in UpdateRepository.proxyPrefixes) '$prefix$url',
    ];
    final dir = await _targetDir();
    if (!dir.existsSync()) await dir.create(recursive: true);
    // 清掉上一次更新残留的安装包，避免缓存里堆积多个几十 MB 的 APK
    await _removeOtherApks(dir);
    final file = File(
      '${dir.path}${Platform.pathSeparator}${_fileNameOf(url)}',
    );

    Object? lastError;
    for (final candidate in candidates) {
      try {
        await _downloadOnce(
          candidate,
          file,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        await _verifySha256(file, sha256);
        return file;
      } on DownloadCancelledException {
        _deleteQuietly(file);
        rethrow;
      } on DownloadIntegrityException {
        // 校验失败不换代理重试：再拉一遍几十 MB 既慢又大概率仍不匹配，
        // 直接交给调用方提示（安装时系统还会做签名校验兜底）。
        _deleteQuietly(file);
        rethrow;
      } catch (e) {
        lastError = e;
        _deleteQuietly(file);
      }
    }
    throw DownloadFailedException(lastError ?? 'no candidate url available');
  }

  Future<void> _downloadOnce(
    String url,
    File file, {
    required void Function(int received, int? total) onProgress,
    bool Function()? isCancelled,
  }) async {
    final client = _clientOverride ?? http.Client();
    try {
      final response = await client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(_connectTimeout);
      if (response.statusCode != 200) {
        throw HttpException('HTTP ${response.statusCode}', uri: Uri.parse(url));
      }
      final total = response.contentLength;
      final sink = file.openWrite();
      var received = 0;
      var lastReported = 0;
      try {
        await for (final chunk in response.stream.timeout(_stallTimeout)) {
          if (isCancelled?.call() ?? false) {
            throw const DownloadCancelledException();
          }
          sink.add(chunk);
          received += chunk.length;
          if (received - lastReported >= _progressStepBytes) {
            lastReported = received;
            onProgress(received, total);
          }
        }
      } finally {
        await sink.close();
      }
      onProgress(received, total ?? received);
    } finally {
      if (_clientOverride == null) client.close();
    }
  }

  Future<void> _verifySha256(File file, String expected) async {
    final normalized = expected.trim().toLowerCase();
    if (normalized.isEmpty) return;
    final actual = await _sha256Of(file);
    if (actual != normalized) {
      _deleteQuietly(file);
      throw DownloadIntegrityException(expected: normalized, actual: actual);
    }
  }

  Future<String> _sha256Of(File file) async {
    final sink = _SingleDigestSink();
    final hasher = sha256.startChunkedConversion(sink);
    await for (final chunk in file.openRead()) {
      hasher.add(chunk);
    }
    hasher.close();
    return sink.digest?.toString() ?? '';
  }

  /// 从下载地址取文件名；取不到或不是 .apk 时回退为 update.apk。
  static String _fileNameOf(String url) {
    final segments = Uri.tryParse(url)?.pathSegments ?? const <String>[];
    final raw = segments.isEmpty ? '' : segments.last;
    final safe = raw.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '');
    return safe.toLowerCase().endsWith('.apk') ? safe : 'update.apk';
  }

  static Future<void> _removeOtherApks(Directory dir) async {
    try {
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.toLowerCase().endsWith('.apk')) {
          _deleteQuietly(entity);
        }
      }
    } catch (_) {
      // 清理失败不影响本次下载
    }
  }

  static void _deleteQuietly(File file) {
    try {
      if (file.existsSync()) file.deleteSync();
    } catch (_) {
      // 忽略：残留文件会在下次下载前统一清理
    }
  }
}

class _SingleDigestSink implements Sink<Digest> {
  Digest? digest;

  @override
  void add(Digest data) => digest = data;

  @override
  void close() {}
}
