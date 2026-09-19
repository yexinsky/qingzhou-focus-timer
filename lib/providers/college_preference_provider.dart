import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/college_preference.dart';
import '../data/repositories/college_preference_repository.dart';

final collegePreferenceRepositoryProvider =
    Provider<CollegePreferenceRepository>(
      (ref) => CollegePreferenceRepository(),
    );

/// 院校 tab 顶部分段：排名 / 专业代码 / 目标；切换 tab 后仍保留所选分段。
/// 声明在此而非 college_view，供专注页横幅跳转时引用，避免连带视图依赖。
final collegeSegmentProvider = StateProvider<String>((ref) => 'ranking');

final collegePreferenceProvider =
    StateNotifierProvider<CollegePreferenceNotifier, CollegePreferences>((ref) {
      return CollegePreferenceNotifier(
        ref.watch(collegePreferenceRepositoryProvider),
      );
    });

class CollegePreferenceNotifier extends StateNotifier<CollegePreferences> {
  CollegePreferenceNotifier(this._repository) : super(_repository.preferences);

  final CollegePreferenceRepository _repository;

  void toggleFavorite(String name) => state = _repository.toggleFavorite(name);

  void setTarget(String? name) => state = _repository.setTarget(name);

  void setExamDate(DateTime? date) => state = _repository.setExamDate(date);

  void addMilestone(String title, DateTime? date) =>
      state = _repository.addMilestone(title, date);

  void toggleMilestone(String id) => state = _repository.toggleMilestone(id);

  void removeMilestone(String id) => state = _repository.removeMilestone(id);
}

/// 倒计时快照：date 为实际采用的考试日期，isAuto 标识是否为自动推算。
class ExamCountdown {
  final DateTime date;
  final int daysRemaining;
  final bool isAuto;

  const ExamCountdown({
    required this.date,
    required this.daysRemaining,
    required this.isAuto,
  });
}

/// 倒计时：自定义日期优先，否则自动推算考研初试日（当年 12 月倒数第二个周六，
/// 已过则推下一年）。daysRemaining 按自然日计算，考试当天为 0，已开考为负。
ExamCountdown? examCountdownFor(CollegePreferences preferences, DateTime now) {
  final isAuto = preferences.examDate == null;
  final date = preferences.examDate ?? nextExamDate(now);
  final today = DateTime(now.year, now.month, now.day);
  final targetDay = DateTime(date.year, date.month, date.day);
  return ExamCountdown(
    date: date,
    daysRemaining: targetDay.difference(today).inDays,
    isAuto: isAuto,
  );
}

final examCountdownProvider = Provider<ExamCountdown?>((ref) {
  final preferences = ref.watch(collegePreferenceProvider);
  return examCountdownFor(preferences, DateTime.now());
});

/// 下一次考研初试日期：12 月倒数第二个周六（初试通常为周六日两天）。
DateTime nextExamDate(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  var year = now.year;
  while (true) {
    final dec31 = DateTime(year, 12, 31);
    final lastSaturday = dec31.subtract(
      Duration(days: (dec31.weekday - DateTime.saturday) % 7),
    );
    final exam = lastSaturday.subtract(const Duration(days: 7));
    if (!exam.isBefore(today)) return exam;
    year++;
  }
}
