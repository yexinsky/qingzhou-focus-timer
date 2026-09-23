import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:qingzhou_focus/core/services/apk_download_service.dart';

const _releaseUrl =
    'https://github.com/yexinsky/qingzhou-focus-timer/releases/download/'
    'v1.2.4/qingzhou-focus-v1.2.4.apk';

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('qz_apk_download_');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  List<int> payload(int size) => List<int>.generate(size, (i) => i % 251);

  MockClient streamingClient(
    Future<http.StreamedResponse> Function(http.BaseRequest request) handler,
  ) => MockClient.streaming((request, _) => handler(request));

  http.StreamedResponse okResponse(List<int> bytes) => http.StreamedResponse(
    Stream.fromIterable([
      bytes.sublist(0, bytes.length ~/ 2),
      bytes.sublist(bytes.length ~/ 2),
    ]),
    200,
    contentLength: bytes.length,
  );

  test('下载成功：写入缓存目录、文件名取自下载地址、sha256 校验通过', () async {
    final bytes = payload(600 * 1024);
    final service = ApkDownloadService(
      client: streamingClient((_) async => okResponse(bytes)),
      targetDir: dir,
    );
    final progress = <int>[];

    final file = await service.downloadApk(
      _releaseUrl,
      sha256: sha256.convert(bytes).toString(),
      onProgress: (received, total) => progress.add(received),
    );

    expect(file.path, endsWith('qingzhou-focus-v1.2.4.apk'));
    expect(await file.readAsBytes(), bytes);
    expect(progress.length, greaterThan(1));
    expect(progress.last, bytes.length);
  });

  test('sha256 不匹配：抛异常并删除半成品', () async {
    final service = ApkDownloadService(
      client: streamingClient((_) async => okResponse(payload(1024))),
      targetDir: dir,
    );

    await expectLater(
      service.downloadApk(
        _releaseUrl,
        sha256: 'deadbeef',
        onProgress: (_, _) {},
      ),
      throwsA(isA<DownloadIntegrityException>()),
    );
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('中途取消：抛 DownloadCancelledException 并清理文件', () async {
    final service = ApkDownloadService(
      client: streamingClient(
        (_) async => okResponse(payload(2 * 1024 * 1024)),
      ),
      targetDir: dir,
    );
    var cancelled = false;

    await expectLater(
      service.downloadApk(
        _releaseUrl,
        isCancelled: () => cancelled,
        onProgress: (received, _) {
          if (received >= 256 * 1024) cancelled = true;
        },
      ),
      throwsA(isA<DownloadCancelledException>()),
    );
    expect(dir.listSync().whereType<File>(), isEmpty);
  });

  test('直连失败后回退到加速代理', () async {
    final requested = <String>[];
    final service = ApkDownloadService(
      client: streamingClient((request) async {
        requested.add(request.url.toString());
        if (requested.length == 1) {
          return http.StreamedResponse(const Stream.empty(), 500);
        }
        return okResponse(payload(1024));
      }),
      targetDir: dir,
    );

    final file = await service.downloadApk(_releaseUrl, onProgress: (_, _) {});

    expect(requested.first, _releaseUrl);
    expect(requested[1], startsWith('https://ghfast.top/'));
    expect(file.existsSync(), isTrue);
  });

  test('所有候选地址都失败：抛 DownloadFailedException', () async {
    final service = ApkDownloadService(
      client: streamingClient(
        (_) async => http.StreamedResponse(const Stream.empty(), 502),
      ),
      targetDir: dir,
    );

    await expectLater(
      service.downloadApk(_releaseUrl, onProgress: (_, _) {}),
      throwsA(isA<DownloadFailedException>()),
    );
    expect(dir.listSync().whereType<File>(), isEmpty);
  });
}
