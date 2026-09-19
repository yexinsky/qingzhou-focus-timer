import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/core/widgets/update_dialog.dart';
import 'package:qingzhou_focus/data/models/app_update.dart';
import 'package:qingzhou_focus/data/repositories/update_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _update = AppUpdate(
  version: '1.2.0',
  releaseNotes: '1. 新增自动更新检查\n2. 修复若干问题',
  downloadUrl: 'https://example.com/app.apk',
);

Uri? capturedUrl;

/// 渲染一个打开更新弹窗的宿主页面并弹窗。
///
/// [launchResult] 决定注入的 onLaunch 是否成功打开链接。
Future<void> openDialog(WidgetTester tester, {bool launchResult = true}) async {
  capturedUrl = null;
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showUpdateDialog(
                context,
                _update,
                onLaunch: (uri) async {
                  capturedUrl = uri;
                  return launchResult;
                },
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    capturedUrl = null;
  });

  testWidgets('展示新版本号与更新说明', (tester) async {
    await openDialog(tester);
    expect(find.text('发现新版本'), findsOneWidget);
    expect(find.text('1. 新增自动更新检查\n2. 修复若干问题'), findsOneWidget);
  });

  testWidgets('勾选跳过此版本后持久化，取消勾选清除', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('跳过此版本，以后不再提醒'));
    await tester.pumpAndSettle();
    expect(await UpdateRepository().getSkippedVersion(), '1.2.0');

    await tester.tap(find.text('跳过此版本，以后不再提醒'));
    await tester.pumpAndSettle();
    expect(await UpdateRepository().getSkippedVersion(), isNull);
  });

  testWidgets('点击立即更新会打开下载地址并关闭弹窗', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(capturedUrl, Uri.parse('https://example.com/app.apk'));
    expect(find.text('发现新版本'), findsNothing);
  });

  testWidgets('打不开下载地址时提示且弹窗保持打开', (tester) async {
    await openDialog(tester, launchResult: false);

    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();

    expect(find.text('无法打开下载链接，请稍后重试'), findsOneWidget);
    expect(find.text('发现新版本'), findsOneWidget);
  });

  testWidgets('点击下次再说只关闭弹窗，不持久化跳过', (tester) async {
    await openDialog(tester);

    await tester.tap(find.text('下次再说'));
    await tester.pumpAndSettle();

    expect(find.text('发现新版本'), findsNothing);
    expect(await UpdateRepository().getSkippedVersion(), isNull);
  });
}
