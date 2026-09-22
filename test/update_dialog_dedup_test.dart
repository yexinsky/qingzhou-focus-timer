import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/models/app_update.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/data/repositories/update_repository.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/providers/update_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

const _update = AppUpdate(
  version: '9.9.9',
  releaseNotes: '回归用例固定版本',
  downloadUrl: 'https://example.com/app.apk',
);

/// 固定返回"有新版本 9.9.9"的假仓库，隔离网络与本地存储。
class _FakeUpdateRepository extends UpdateRepository {
  @override
  Future<AppUpdate?> fetchLatestUpdate() async => _update;

  @override
  Future<bool> isUpdateAvailable(AppUpdate update) async => true;

  @override
  Future<String?> getSkippedVersion() async => null;
}

Future<void> _pumpApp(WidgetTester tester, ProviderContainer container) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const QingzhouApp()),
  );
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  Future<ProviderContainer> buildContainer() async {
    SharedPreferences.setMockInitialValues({});
    final settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final subjectRepository = SubjectRepository();
    await subjectRepository.init();
    return ProviderContainer(
      overrides: [
        taskRepositoryProvider.overrideWithValue(TestTaskRepository()),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        subjectRepositoryProvider.overrideWithValue(subjectRepository),
        updateRepositoryProvider.overrideWithValue(_FakeUpdateRepository()),
      ],
    );
  }

  setUp(() async {
    container = await buildContainer();
    addTearDown(container.dispose);
  });

  testWidgets('available 驻留时再次状态变更不重复弹出更新弹窗', (tester) async {
    await _pumpApp(tester, container);

    // 自动检查命中新版本 → 弹窗一次。
    await container.read(updateProvider.notifier).checkForUpdate();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('发现新版本'), findsOneWidget);

    // 用户点"下次再说"关闭弹窗。
    await tester.tap(find.text('下次再说'));
    await tester.pumpAndSettle();
    expect(find.text('发现新版本'), findsNothing);

    // available 仍驻留于状态；再次状态变更（如再次自动/手动检查引起的
    // checking 翻转与同版本 available）不得重复弹窗。
    await container.read(updateProvider.notifier).checkForUpdate();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('发现新版本'), findsNothing);
  });
}
