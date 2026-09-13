import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App smoke test', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final subjectRepository = SubjectRepository();
    await subjectRepository.init();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(TestTaskRepository()),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          subjectRepositoryProvider.overrideWithValue(subjectRepository),
        ],
        child: const QingzhouApp(),
      ),
    );

    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('专注'), findsWidgets);
  });
}
