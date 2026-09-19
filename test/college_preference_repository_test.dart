import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/college_preference.dart';
import 'package:qingzhou_focus/data/repositories/college_preference_repository.dart';
import 'package:qingzhou_focus/providers/college_preference_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CollegePreferenceRepository', () {
    late CollegePreferenceRepository repository;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      repository = CollegePreferenceRepository();
      await repository.init();
    });

    test('初始状态为空', () {
      expect(repository.preferences.favorites, isEmpty);
      expect(repository.preferences.target, isNull);
      expect(repository.preferences.examDate, isNull);
      expect(repository.preferences.milestones, isEmpty);
    });

    test('收藏切换并持久化往返', () async {
      repository.toggleFavorite('清华大学');
      expect(repository.preferences.favorites, ['清华大学']);

      // 新实例重新 init 应读回持久化数据
      final reloaded = CollegePreferenceRepository();
      await reloaded.init();
      expect(reloaded.preferences.favorites, ['清华大学']);

      reloaded.toggleFavorite('清华大学');
      expect(reloaded.preferences.favorites, isEmpty);
    });

    test('目标院校设置与清除', () {
      repository.setTarget('浙江大学');
      expect(repository.preferences.target, '浙江大学');

      repository.setTarget(null);
      expect(repository.preferences.target, isNull);
    });

    test('考试日期设置与恢复自动', () {
      repository.setExamDate(DateTime(2027, 6, 7));
      expect(repository.preferences.examDate, DateTime(2027, 6, 7));

      repository.setExamDate(null);
      expect(repository.preferences.examDate, isNull);
    });

    test('里程碑增删改并持久化', () async {
      repository.addMilestone('网上报名', DateTime(2026, 10, 25));
      repository.addMilestone('完成数学一轮', null);
      expect(repository.preferences.milestones, hasLength(2));
      expect(repository.preferences.milestones.first.title, '网上报名');
      expect(
        repository.preferences.milestones.first.date,
        DateTime(2026, 10, 25),
      );
      expect(repository.preferences.milestones.last.date, isNull);

      final id = repository.preferences.milestones.first.id;
      repository.toggleMilestone(id);
      expect(repository.preferences.milestones.first.done, isTrue);

      repository.removeMilestone(id);
      expect(repository.preferences.milestones, hasLength(1));
      expect(repository.preferences.milestones.first.title, '完成数学一轮');

      final reloaded = CollegePreferenceRepository();
      await reloaded.init();
      expect(reloaded.preferences.milestones.first.title, '完成数学一轮');
      expect(reloaded.preferences.milestones.first.done, isFalse);
    });

    test('空标题的里程碑被忽略', () {
      repository.addMilestone('   ', null);
      expect(repository.preferences.milestones, isEmpty);
    });

    test('损坏 JSON 容错回退默认值', () async {
      SharedPreferences.setMockInitialValues({
        'college_preference_v1': '{broken json',
      });
      final broken = CollegePreferenceRepository();
      await broken.init();
      expect(broken.preferences.favorites, isEmpty);
      expect(broken.preferences.target, isNull);
    });

    test('未初始化时可内存态使用不崩溃', () {
      final raw = CollegePreferenceRepository();
      raw.toggleFavorite('复旦大学');
      expect(raw.preferences.favorites, ['复旦大学']);
      raw.setTarget('复旦大学');
      expect(raw.preferences.target, '复旦大学');
    });
  });

  group('nextExamDate', () {
    test('当年 12 月倒数第二个周六', () {
      expect(nextExamDate(DateTime(2026, 9, 19)), DateTime(2026, 12, 19));
      expect(nextExamDate(DateTime(2026, 12, 1)), DateTime(2026, 12, 19));
    });

    test('考试当天返回当天', () {
      expect(nextExamDate(DateTime(2026, 12, 19)), DateTime(2026, 12, 19));
    });

    test('已过则推下一年', () {
      expect(nextExamDate(DateTime(2026, 12, 25)), DateTime(2027, 12, 18));
    });
  });

  group('examCountdownFor', () {
    test('无自定义日期时自动推算', () {
      final countdown = examCountdownFor(
        const CollegePreferences(),
        DateTime(2026, 9, 19),
      );
      expect(countdown!.isAuto, isTrue);
      expect(countdown.date, DateTime(2026, 12, 19));
      expect(countdown.daysRemaining, 91);
    });

    test('自定义日期优先，可为过去日期', () {
      final countdown = examCountdownFor(
        CollegePreferences(examDate: DateTime(2020, 1, 1)),
        DateTime(2026, 9, 19),
      );
      expect(countdown!.isAuto, isFalse);
      expect(countdown.daysRemaining, isNegative);
    });

    test('考试当天为 0 天', () {
      final countdown = examCountdownFor(
        CollegePreferences(examDate: DateTime(2026, 12, 19)),
        DateTime(2026, 12, 19, 15, 30),
      );
      expect(countdown!.daysRemaining, 0);
    });
  });
}
