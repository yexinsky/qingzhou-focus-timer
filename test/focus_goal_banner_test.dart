import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/app.dart';
import 'package:qingzhou_focus/data/repositories/college_preference_repository.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/college_preference_provider.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

Future<void> _pumpApp(
  WidgetTester tester, {
  CollegePreferenceRepository? preferenceRepository,
}) async {
  SharedPreferences.setMockInitialValues({});
  final settingsRepository = SettingsRepository();
  await settingsRepository.init();
  final subjectRepository = SubjectRepository();
  await subjectRepository.init();
  final collegePreferenceRepository =
      preferenceRepository ?? CollegePreferenceRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(TestTaskRepository()),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
        subjectRepositoryProvider.overrideWithValue(subjectRepository),
        collegePreferenceRepositoryProvider.overrideWithValue(
          collegePreferenceRepository,
        ),
      ],
      child: const QingzhouApp(),
    ),
  );
  // 专注页存在无限循环的呼吸动画，不能使用 pumpAndSettle
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('未设置目标院校时专注页无横幅', (tester) async {
    await _pumpApp(tester);
    expect(find.textContaining('目标 '), findsNothing);
  });

  testWidgets('设置目标院校后专注页显示常驻横幅', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferenceRepository = CollegePreferenceRepository();
    await preferenceRepository.init();
    preferenceRepository.setTarget('浙江大学');

    await _pumpApp(tester, preferenceRepository: preferenceRepository);

    expect(find.textContaining('目标 浙江大学'), findsOneWidget);
    expect(find.textContaining('今日还没开始专注'), findsOneWidget);
  });

  testWidgets('点击横幅跳转到院校目标分段', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferenceRepository = CollegePreferenceRepository();
    await preferenceRepository.init();
    preferenceRepository.setTarget('浙江大学');

    await _pumpApp(tester, preferenceRepository: preferenceRepository);

    await tester.tap(find.textContaining('目标 浙江大学'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('院校'), findsWidgets);
    expect(find.text('考研倒计时'), findsOneWidget);
  });
}
