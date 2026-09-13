import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/core/services/session_feedback_service.dart';
import 'package:qingzhou_focus/data/models/task.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

/// 记录预排/撤销调用，用于验证到点提醒与计时状态联动。
class _RecordingFeedback implements SessionFeedbackService {
  int? scheduledEndAt;
  bool? scheduledIsFocus;
  int cancelCount = 0;

  @override
  Future<void> scheduleSessionEndReminder({
    required int endAtMillis,
    required bool isFocusSession,
  }) async {
    scheduledEndAt = endAtMillis;
    scheduledIsFocus = isFocusSession;
  }

  @override
  Future<void> cancelSessionEndReminder() async => cancelCount++;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late TestTaskRepository taskRepository;
  late SettingsRepository settingsRepository;

  Future<TimerNotifier> createNotifier({DateTime Function()? now}) async {
    SharedPreferences.setMockInitialValues({});
    settingsRepository = SettingsRepository();
    await settingsRepository.init();
    taskRepository = TestTaskRepository();
    return TimerNotifier(taskRepository, settingsRepository, now: now);
  }

  test('initial state reflects configured focus duration', () async {
    SharedPreferences.setMockInitialValues({'focus_duration': 45});
    settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final notifier = TimerNotifier(TestTaskRepository(), settingsRepository);
    addTearDown(notifier.dispose);
    expect(notifier.state.state, TimerState.idle);
    expect(notifier.state.sessionType, SessionType.focus);
    expect(notifier.state.timeLeft, 45 * 60);
    expect(notifier.state.progress, 0);
  });

  test('duration can change only while idle and positive', () async {
    final notifier = await createNotifier();
    addTearDown(notifier.dispose);
    notifier.setDuration(60);
    expect(notifier.state.totalTime, 3600);
    notifier.startTimer();
    notifier.setDuration(90);
    expect(notifier.state.totalTime, 3600);
    notifier.setDuration(0);
    expect(notifier.state.totalTime, 3600);
  });

  test('task selection and abandonment clear session task', () async {
    final notifier = await createNotifier();
    addTearDown(notifier.dispose);
    final task = Task(
      id: '1',
      title: '高数',
      subject: '数学',
      dateKey: '2026-09-06',
      createdAt: 1,
    );
    notifier.selectTask(task);
    expect(notifier.state.currentTask?.id, '1');
    notifier.startTimer();
    notifier.abandonSession();
    expect(notifier.state.state, TimerState.idle);
    expect(notifier.state.currentTask, isNull);
  });

  test('subject focus is mutually exclusive with task focus', () async {
    final notifier = await createNotifier();
    addTearDown(notifier.dispose);
    final task = Task(
      id: '1',
      title: '高数',
      subject: '数学',
      dateKey: '2026-09-06',
      createdAt: 1,
    );
    notifier.selectSubject('英语');
    expect(notifier.state.currentSubject, '英语');
    expect(notifier.state.currentTask, isNull);
    notifier.selectTask(task);
    expect(notifier.state.currentSubject, isNull);
    expect(notifier.state.currentTask?.id, '1');
    notifier.abandonSession();
    expect(notifier.state.currentTask, isNull);
    expect(notifier.state.currentSubject, isNull);
  });

  test('finished flexible subject session records subject and title', () async {
    var clock = DateTime(2026, 9, 6, 10);
    final notifier = await createNotifier(now: () => clock);
    addTearDown(notifier.dispose);
    notifier.setFocusTimerMode(FocusTimerMode.stopwatch);
    notifier.selectSubject('数学');
    notifier.startTimer();
    clock = clock.add(const Duration(seconds: 30));
    expect(await notifier.finishFlexibleSession(), isTrue);
    final session = taskRepository.sessions.values.single;
    expect(session.subject, '数学');
    expect(session.taskTitle, '数学');
    expect(session.taskId, isNull);
    expect(session.duration, 30);
    // 专注目标在结束后保留，便于连续进行同一科目/任务的专注
    expect(notifier.state.currentSubject, '数学');
  });

  test('subject selection survives snapshot round-trip', () async {
    SharedPreferences.setMockInitialValues({
      'timer_session_snapshot_v1':
          '{"timeLeft":1500,"totalTime":1500,"state":"running","sessionType":"focus","task":null,"subject":"专业课","completedSessions":0,"startedAt":null,"endsAt":null}',
    });
    settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final notifier = TimerNotifier(TestTaskRepository(), settingsRepository);
    addTearDown(notifier.dispose);
    expect(notifier.state.currentSubject, '专业课');
    expect(notifier.state.currentTask, isNull);
  });

  test(
    'startTimer schedules end reminder at exact end time; pause cancels it',
    () async {
      var clock = DateTime(2026, 9, 6, 10);
      SharedPreferences.setMockInitialValues({'notification_enabled': true});
      settingsRepository = SettingsRepository();
      await settingsRepository.init();
      final feedback = _RecordingFeedback();
      final notifier = TimerNotifier(
        TestTaskRepository(),
        settingsRepository,
        now: () => clock,
        feedbackService: feedback,
      );
      addTearDown(notifier.dispose);

      notifier.setDuration(25);
      notifier.startTimer();
      await Future<void>.delayed(Duration.zero);
      expect(feedback.scheduledIsFocus, isTrue);
      expect(
        feedback.scheduledEndAt,
        clock.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
      );

      notifier.pauseTimer();
      await Future<void>.delayed(Duration.zero);
      expect(feedback.cancelCount, 1);

      clock = clock.add(const Duration(minutes: 5));
      notifier.resumeTimer();
      await Future<void>.delayed(Duration.zero);
      expect(feedback.cancelCount, 1);
      // 恢复时从暂停时刻的剩余时长（25 分钟）重新起算结束点，暂停期间不倒扣
      expect(
        feedback.scheduledEndAt,
        clock.add(const Duration(minutes: 25)).millisecondsSinceEpoch,
      );
    },
  );

  test('end reminder is skipped when notifications are disabled', () async {
    SharedPreferences.setMockInitialValues({});
    settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final feedback = _RecordingFeedback();
    final notifier = TimerNotifier(
      TestTaskRepository(),
      settingsRepository,
      feedbackService: feedback,
    );
    addTearDown(notifier.dispose);
    notifier.setDuration(25);
    notifier.startTimer();
    await Future<void>.delayed(Duration.zero);
    expect(feedback.scheduledEndAt, isNull);
  });

  test(
    'pause freezes clock-derived remaining time and resume runs again',
    () async {
      var clock = DateTime(2026, 9, 6, 10);
      final notifier = await createNotifier(now: () => clock);
      addTearDown(notifier.dispose);
      notifier.setDuration(1);
      notifier.startTimer();
      clock = clock.add(const Duration(seconds: 20));
      notifier.pauseTimer();
      expect(notifier.state.state, TimerState.paused);
      expect(notifier.state.timeLeft, 40);
      clock = clock.add(const Duration(minutes: 5));
      notifier.resumeTimer();
      expect(notifier.state.state, TimerState.running);
      expect(notifier.state.timeLeft, 40);
    },
  );

  test('short and long break selection follows completed count snapshot', () async {
    SharedPreferences.setMockInitialValues({
      'long_break_interval': 4,
      'timer_session_snapshot_v1':
          '{"timeLeft":0,"totalTime":1500,"state":"completed","sessionType":"focus","task":null,"completedSessions":3,"startedAt":null,"endsAt":null}',
    });
    settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final shortBreak = TimerNotifier(TestTaskRepository(), settingsRepository);
    addTearDown(shortBreak.dispose);
    shortBreak.startBreak();
    expect(shortBreak.state.sessionType, SessionType.shortBreak);
    expect(shortBreak.state.totalTime, 5 * 60);

    SharedPreferences.setMockInitialValues({
      'long_break_interval': 4,
      'timer_session_snapshot_v1':
          '{"timeLeft":0,"totalTime":1500,"state":"completed","sessionType":"focus","task":null,"completedSessions":4,"startedAt":null,"endsAt":null}',
    });
    final settings2 = SettingsRepository();
    await settings2.init();
    final longBreak = TimerNotifier(TestTaskRepository(), settings2);
    addTearDown(longBreak.dispose);
    longBreak.startBreak();
    expect(longBreak.state.sessionType, SessionType.longBreak);
    expect(longBreak.state.totalTime, 15 * 60);
  });

  test('flexible timer counts up, pauses, resumes and records once', () async {
    var clock = DateTime(2026, 9, 6, 10);
    final notifier = await createNotifier(now: () => clock);
    addTearDown(notifier.dispose);
    notifier.setFocusTimerMode(FocusTimerMode.stopwatch);
    expect(notifier.state.totalTime, 0);
    notifier.startTimer();
    clock = clock.add(const Duration(seconds: 35));
    notifier.pauseTimer();
    expect(notifier.state.totalTime, 35);
    clock = clock.add(const Duration(minutes: 5));
    notifier.resumeTimer();
    clock = clock.add(const Duration(seconds: 10));
    expect(await notifier.finishFlexibleSession(), isTrue);
    expect(taskRepository.sessions.length, 1);
    final session = taskRepository.sessions.values.single;
    expect(session.duration, 45);
    expect(session.isFlexible, isTrue);
    expect(notifier.state.completedSessions, 0);
    expect(await notifier.finishFlexibleSession(), isFalse);
    expect(taskRepository.sessions.length, 1);
  });

  test('abandoning flexible timer does not save a session', () async {
    var clock = DateTime(2026, 9, 6, 10);
    final notifier = await createNotifier(now: () => clock);
    addTearDown(notifier.dispose);
    notifier.setFocusTimerMode(FocusTimerMode.stopwatch);
    notifier.startTimer();
    clock = clock.add(const Duration(seconds: 15));
    notifier.abandonSession();
    expect(taskRepository.sessions, isEmpty);
    expect(notifier.state.state, TimerState.idle);
    expect(notifier.state.totalTime, 0);
  });

  test('running flexible timer restores elapsed wall-clock time', () async {
    final started = DateTime(2026, 9, 6, 10);
    SharedPreferences.setMockInitialValues({
      'timer_session_snapshot_v1':
          '{"timeLeft":0,"totalTime":20,"state":"running","sessionType":"focus","focusTimerMode":"stopwatch","task":null,"completedSessions":0,"startedAt":${started.millisecondsSinceEpoch},"endsAt":${started.millisecondsSinceEpoch}}',
    });
    settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final notifier = TimerNotifier(
      TestTaskRepository(),
      settingsRepository,
      now: () => started.add(const Duration(seconds: 75)),
    );
    addTearDown(notifier.dispose);
    expect(notifier.state.state, TimerState.running);
    expect(notifier.state.totalTime, 75);
  });
}
