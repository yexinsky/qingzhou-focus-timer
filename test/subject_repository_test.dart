import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/core/theme/app_colors.dart';
import 'package:qingzhou_focus/data/repositories/subject_repository.dart';
import 'package:qingzhou_focus/providers/subject_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SubjectRepository> createRepository({
    Map<String, Object> initialValues = const {},
  }) async {
    SharedPreferences.setMockInitialValues(initialValues);
    final repository = SubjectRepository();
    await repository.init();
    return repository;
  }

  List<String> names(SubjectRepository repository) =>
      repository.subjects.map((s) => s.name).toList();

  test('first init seeds preset subjects with preset colors', () async {
    final repository = await createRepository();
    expect(names(repository), AppColors.presetSubjectNames);
    for (final subject in repository.subjects) {
      expect(
        subject.colorValue,
        AppColors.presetSubjectColorMap[subject.name]!.toARGB32(),
      );
    }
  });

  test('add custom subject appends it with an unused palette color', () async {
    final repository = await createRepository();
    expect(await repository.add('日语'), isTrue);
    expect(names(repository).last, '日语');
    final japaneseColor = repository.subjects.last.color;
    expect(AppColors.customSubjectPalette.contains(japaneseColor), isTrue);
    final presetColors = repository.subjects
        .take(AppColors.presetSubjectNames.length)
        .map((s) => s.color)
        .toSet();
    expect(presetColors.contains(japaneseColor), isFalse);
  });

  test('adding a duplicate active subject is rejected', () async {
    final repository = await createRepository();
    expect(await repository.add('数学'), isFalse);
    expect(names(repository).length, AppColors.presetSubjectNames.length);
  });

  test('remove archives subject but keeps its color registered', () async {
    final repository = await createRepository();
    final mathColor = AppColors.presetSubjectColorMap['数学']!;
    expect(await repository.remove('数学'), isTrue);
    expect(names(repository), isNot(contains('数学')));
    expect(AppColors.getSubjectColor('数学'), mathColor);
  });

  test('re-adding an archived subject revives its original color', () async {
    final repository = await createRepository();
    final mathColor = AppColors.presetSubjectColorMap['数学']!;
    await repository.remove('数学');
    await repository.add('数学');
    expect(names(repository), contains('数学'));
    expect(AppColors.getSubjectColor('数学'), mathColor);
  });

  test('subject config survives repository restart', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = SubjectRepository();
    await repository.init();
    await repository.remove('政治');
    await repository.add('日语');

    // 同一 mock 存储上重新初始化，模拟应用重启
    final reloaded = SubjectRepository();
    await reloaded.init();
    expect(names(reloaded), isNot(contains('政治')));
    expect(names(reloaded), contains('日语'));
    // 已删除科目的颜色仍可查（历史记录着色稳定）
    expect(
      AppColors.getSubjectColor('政治'),
      AppColors.presetSubjectColorMap['政治']!,
    );
  });

  test('corrupted storage falls back to presets', () async {
    final repository = await createRepository(
      initialValues: {'subject_config_v1': 'not-json{'},
    );
    expect(names(repository), AppColors.presetSubjectNames);
  });

  test('subjects notifier exposes repository mutations', () async {
    final repository = await createRepository();
    final notifier = SubjectsNotifier(repository);
    expect(notifier.state.map((s) => s.name), AppColors.presetSubjectNames);
    expect(await notifier.add('二外'), isTrue);
    expect(notifier.state.last.name, '二外');
    expect(await notifier.remove('二外'), isTrue);
    expect(notifier.state.map((s) => s.name), isNot(contains('二外')));
  });

  test(
    'palette color assignment skips colors used by active subjects',
    () async {
      final repository = await createRepository();
      await repository.add('科目A');
      await repository.add('科目B');
      expect(repository.subjects[5].color, AppColors.customSubjectPalette[0]);
      expect(repository.subjects[6].color, AppColors.customSubjectPalette[1]);
    },
  );

  test('Color round-trips through stored int value', () async {
    const color = Color(0xFF6B8E71);
    expect(Color(color.toARGB32()), color);
  });
}
