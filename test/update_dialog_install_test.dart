import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/core/services/apk_download_service.dart';
import 'package:qingzhou_focus/core/services/apk_install_service.dart';
import 'package:qingzhou_focus/core/widgets/update_dialog.dart';
import 'package:qingzhou_focus/data/models/app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _update = AppUpdate(
  version: '1.2.4',
  releaseNotes: '修复若干问题',
  downloadUrl: 'https://example.com/app.apk',
);

class _FakeInstaller extends ApkInstallService {
  _FakeInstaller({this.supported = true, this.permissionGranted = true})
    : super(isAndroid: false);

  final bool supported;
  bool permissionGranted;
  bool permissionRequested = false;
  final List<String> installed = [];

  @override
  bool get isSupported => supported;

  @override
  Future<bool> hasInstallPermission() async => permissionGranted;

  @override
  Future<bool> requestInstallPermission() async {
    permissionRequested = true;
    return permissionGranted;
  }

  @override
  Future<void> installApk(String filePath) async => installed.add(filePath);
}

class _FakeDownloader extends ApkDownloadService {
  _FakeDownloader(this.file);

  final File file;
  int calls = 0;

  @override
  Future<File> downloadApk(
    String url, {
    required void Function(int received, int? total) onProgress,
    bool Function()? isCancelled,
    String sha256 = '',
  }) async {
    calls++;
    onProgress(1024 * 1024, 2 * 1024 * 1024);
    onProgress(2 * 1024 * 1024, 2 * 1024 * 1024);
    return file;
  }
}

class _FailingDownloader extends ApkDownloadService {
  int calls = 0;

  @override
  Future<File> downloadApk(
    String url, {
    required void Function(int received, int? total) onProgress,
    bool Function()? isCancelled,
    String sha256 = '',
  }) async {
    calls++;
    throw const DownloadFailedException('simulated failure');
  }
}

/// 只有在收到取消信号后才结束的下载器，用于验证"取消下载"路径。
class _CancellableDownloader extends ApkDownloadService {
  @override
  Future<File> downloadApk(
    String url, {
    required void Function(int received, int? total) onProgress,
    bool Function()? isCancelled,
    String sha256 = '',
  }) async {
    onProgress(1024 * 1024, 60 * 1024 * 1024);
    while (!(isCancelled?.call() ?? false)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    throw const DownloadCancelledException();
  }
}

Future<void> openDialog(
  WidgetTester tester, {
  required ApkInstallService installer,
  required ApkDownloadService downloader,
  Future<bool> Function(Uri uri)? onLaunch,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showUpdateDialog(
                context,
                _update,
                installer: installer,
                downloader: downloader,
                onLaunch: onLaunch,
              ),
              child: const Text('打开弹窗'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('打开弹窗'));
  await tester.pumpAndSettle();
}

void main() {
  late Directory dir;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('qz_update_dialog_');
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  testWidgets('权限已授予：下载完成后调起系统安装器并关闭弹窗', (tester) async {
    final apk = File('${dir.path}${Platform.pathSeparator}app.apk')
      ..writeAsStringSync('apk-bytes');
    final installer = _FakeInstaller();
    final downloader = _FakeDownloader(apk);

    await openDialog(tester, installer: installer, downloader: downloader);
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(downloader.calls, 1);
    expect(installer.permissionRequested, isFalse);
    expect(installer.installed, [apk.path]);
    expect(find.text('发现新版本'), findsNothing);
  });

  testWidgets('未授予安装权限：先申请，被拒后不下载并提示可改用浏览器', (tester) async {
    var launched = false;
    final installer = _FakeInstaller(permissionGranted: false);
    final downloader = _FakeDownloader(File('${dir.path}/app.apk'));

    await openDialog(
      tester,
      installer: installer,
      downloader: downloader,
      onLaunch: (uri) async {
        launched = true;
        return true;
      },
    );
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(installer.permissionRequested, isTrue);
    expect(downloader.calls, 0);
    expect(find.textContaining('安装未知应用'), findsOneWidget);

    await tester.tap(find.text('浏览器下载'));
    await tester.pumpAndSettle();
    expect(launched, isTrue);
  });

  testWidgets('下载失败：提示失败且弹窗保持打开，可重试', (tester) async {
    final installer = _FakeInstaller();
    final downloader = _FailingDownloader();

    await openDialog(tester, installer: installer, downloader: downloader);
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(downloader.calls, 1);
    expect(find.textContaining('下载失败'), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
    expect(installer.installed, isEmpty);
  });

  testWidgets('取消下载：不调起安装器，回到更新弹窗', (tester) async {
    final installer = _FakeInstaller();

    await openDialog(
      tester,
      installer: installer,
      downloader: _CancellableDownloader(),
    );
    await tester.tap(find.text('立即更新'));
    await tester.pump();
    expect(find.text('正在下载 v1.2.4'), findsOneWidget);

    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();

    expect(installer.installed, isEmpty);
    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('非 Android：保持原有浏览器下载行为', (tester) async {
    var launched = false;
    final installer = _FakeInstaller(supported: false);

    await openDialog(
      tester,
      installer: installer,
      downloader: _FakeDownloader(File('${dir.path}/app.apk')),
      onLaunch: (uri) async {
        launched = true;
        return true;
      },
    );
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(launched, isTrue);
    expect(find.text('发现新版本'), findsNothing);
  });
}
