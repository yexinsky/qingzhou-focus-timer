import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qingzhou_focus/data/models/app_update.dart';
import 'package:qingzhou_focus/data/repositories/update_repository.dart';
import 'package:qingzhou_focus/providers/update_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _currentInfo = PackageInfo(
  appName: 'qingzhou',
  packageName: 'com.qingzhou.qingzhou_focus',
  version: '1.1.0',
  buildNumber: '2',
);

const _manifestJson =
    '{"version": "1.2.0", "buildNumber": 3, '
    '"releaseNotes": "修复若干问题", "downloadUrl": "https://example.com/app.apk"}';

/// http.Response 默认按 latin1 编码，中文说明必须显式声明 utf-8。
http.Response _jsonResponse(String body) => http.Response(
  body,
  200,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

UpdateRepository _repo(
  MockClient client, {
  PackageInfo? info,
  SharedPreferences? prefs,
}) => UpdateRepository(
  client: client,
  packageInfo: info ?? _currentInfo,
  prefs: prefs,
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AppUpdate.tryParse', () {
    test('解析常规清单字段', () {
      final update = AppUpdate.tryParse(const {
        'version': '1.2.0',
        'buildNumber': 3,
        'releaseNotes': '更新说明',
        'downloadUrl': 'https://example.com/app.apk',
      });
      expect(update, isNotNull);
      expect(update!.version, '1.2.0');
      expect(update.buildNumber, 3);
      expect(update.releaseNotes, '更新说明');
      expect(update.downloadUrlFor('android'), 'https://example.com/app.apk');
    });

    test('downloadUrls 按平台覆盖通用下载地址', () {
      final update = AppUpdate.tryParse(const {
        'version': '1.2.0',
        'downloadUrl': 'https://example.com/default',
        'downloadUrls': {'android': 'https://example.com/android.apk'},
      });
      expect(
        update!.downloadUrlFor('android'),
        'https://example.com/android.apk',
      );
      expect(update.downloadUrlFor('ios'), 'https://example.com/default');
    });

    test('缺 version 或缺下载地址时返回 null', () {
      expect(
        AppUpdate.tryParse(const {'downloadUrl': 'https://a.b/c'}),
        isNull,
      );
      expect(AppUpdate.tryParse(const {'version': '1.2.0'}), isNull);
      expect(
        AppUpdate.tryParse(const {'version': '1.2.0', 'downloadUrl': ' '}),
        isNull,
      );
    });
  });

  group('UpdateRepository.isNewerVersion', () {
    test('逐段数值比较', () {
      expect(UpdateRepository.isNewerVersion('1.2.0', '1.1.0'), isTrue);
      expect(UpdateRepository.isNewerVersion('1.10.0', '1.9.0'), isTrue);
      expect(UpdateRepository.isNewerVersion('1.1.0', '1.2.0'), isFalse);
      expect(UpdateRepository.isNewerVersion('1.1.0', '1.1.0'), isFalse);
      expect(UpdateRepository.isNewerVersion('1.2', '1.1.9'), isTrue);
    });

    test('忽略预发布后缀，短版本号与补零等价', () {
      expect(UpdateRepository.isNewerVersion('1.2.0-beta', '1.1.0'), isTrue);
      expect(UpdateRepository.isNewerVersion('1.2', '1.2.0'), isFalse);
    });
  });

  group('UpdateRepository.fetchLatestUpdate', () {
    test('请求仓库配置的清单地址并解析结果', () async {
      Uri? requested;
      final repo = _repo(
        MockClient((request) async {
          requested = request.url;
          return _jsonResponse(_manifestJson);
        }),
      );
      final update = await repo.fetchLatestUpdate();
      expect(requested, Uri.parse(UpdateRepository.manifestUrl));
      expect(update!.version, '1.2.0');
    });

    test('非 200、非法 JSON、请求异常都静默返回 null', () async {
      expect(
        await _repo(
          MockClient((_) async => http.Response('not found', 404)),
        ).fetchLatestUpdate(),
        isNull,
      );
      expect(
        await _repo(
          MockClient((_) async => http.Response('not json', 200)),
        ).fetchLatestUpdate(),
        isNull,
      );
      expect(
        await _repo(
          MockClient((_) async => throw Exception('network down')),
        ).fetchLatestUpdate(),
        isNull,
      );
      expect(
        await _repo(
          MockClient((_) async => http.Response('[1, 2]', 200)),
        ).fetchLatestUpdate(),
        isNull,
      );
    });
  });

  group('UpdateRepository.isUpdateAvailable', () {
    test('远端版本号更新时可用', () async {
      final update = AppUpdate.tryParse(const {
        'version': '1.2.0',
        'downloadUrl': 'https://example.com/a',
      })!;
      expect(
        await _repo(
          MockClient((_) async => http.Response('', 200)),
        ).isUpdateAvailable(update),
        isTrue,
      );
    });

    test('版本号相同但构建号更高时可用（重打包热修）', () async {
      final repo = _repo(MockClient((_) async => http.Response('', 200)));
      final higherBuild = AppUpdate.tryParse(const {
        'version': '1.1.0',
        'buildNumber': 5,
        'downloadUrl': 'https://example.com/a',
      })!;
      expect(await repo.isUpdateAvailable(higherBuild), isTrue);
      final sameBuild = AppUpdate.tryParse(const {
        'version': '1.1.0',
        'buildNumber': 2,
        'downloadUrl': 'https://example.com/a',
      })!;
      expect(await repo.isUpdateAvailable(sameBuild), isFalse);
    });

    test('远端不比当前新时不可用', () async {
      final update = AppUpdate.tryParse(const {
        'version': '1.0.9',
        'downloadUrl': 'https://example.com/a',
      })!;
      expect(
        await _repo(
          MockClient((_) async => http.Response('', 200)),
        ).isUpdateAvailable(update),
        isFalse,
      );
    });
  });

  test('跳过版本持久化：写入后可读回，清除后为 null', () async {
    final repo = UpdateRepository();
    await repo.skipVersion('1.2.0');
    expect(await repo.getSkippedVersion(), '1.2.0');
    await repo.clearSkippedVersion();
    expect(await repo.getSkippedVersion(), isNull);
  });

  group('UpdateNotifier', () {
    test('自动检查：新版本写入 available；跳过后下次启动不再提示', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = _repo(
        MockClient((_) async => _jsonResponse(_manifestJson)),
        prefs: prefs,
      );
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(updateProvider.notifier)
          .checkForUpdate();
      expect(result.update!.version, '1.2.0');
      expect(container.read(updateProvider).available!.version, '1.2.0');

      await repo.skipVersion('1.2.0');
      final freshContainer = ProviderContainer(
        overrides: [
          updateRepositoryProvider.overrideWithValue(
            UpdateRepository(
              client: MockClient(
                (_) async => http.Response(_manifestJson, 200),
              ),
              packageInfo: _currentInfo,
              prefs: prefs,
            ),
          ),
        ],
      );
      addTearDown(freshContainer.dispose);
      final nextResult = await freshContainer
          .read(updateProvider.notifier)
          .checkForUpdate();
      expect(nextResult.update, isNull);
      expect(freshContainer.read(updateProvider).available, isNull);
    });

    test('手动检查：忽略已跳过的版本，但不触发自动弹窗', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('update_skipped_version', '1.2.0');
      final repo = _repo(
        MockClient((_) async => _jsonResponse(_manifestJson)),
        prefs: prefs,
      );
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(updateProvider.notifier)
          .checkForUpdate(manual: true);
      expect(result.update!.version, '1.2.0');
      expect(container.read(updateProvider).available, isNull);
    });

    test('已是最新版本时 available 保持为空', () async {
      final repo = _repo(
        MockClient(
          (_) async => http.Response(
            '{"version": "1.1.0", "downloadUrl": "https://example.com/a"}',
            200,
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(updateProvider.notifier)
          .checkForUpdate();
      expect(result.update, isNull);
      expect(container.read(updateProvider).available, isNull);
    });

    test('清单拉取失败：自动检查静默，手动检查返回 failed', () async {
      final repo = _repo(
        MockClient((_) async => http.Response('server error', 500)),
      );
      final container = ProviderContainer(
        overrides: [updateRepositoryProvider.overrideWithValue(repo)],
      );
      addTearDown(container.dispose);

      await container.read(updateProvider.notifier).checkForUpdate();
      expect(container.read(updateProvider).available, isNull);

      final manual = await container
          .read(updateProvider.notifier)
          .checkForUpdate(manual: true);
      expect(manual.failed, isTrue);
      expect(manual.update, isNull);
    });
  });
}
