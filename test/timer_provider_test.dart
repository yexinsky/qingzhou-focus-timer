import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/task.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:qingzhou_focus/providers/timer_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/test_repositories.dart';

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
}
