import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/task.dart';
import '../data/models/focus_session.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../core/utils/time_formatter.dart';

enum TimerState { idle, running, paused, completed }

class TimerStateData {
  final int timeLeft;
  final int totalTime;
  final TimerState state;
  final SessionType sessionType;
  final Task? currentTask;
  final int completedSessions;

  TimerStateData({
    required this.timeLeft,
    required this.totalTime,
    required this.state,
    required this.sessionType,
    this.currentTask,
    this.completedSessions = 0,
  });

  TimerStateData copyWith({
    int? timeLeft,
    int? totalTime,
    TimerState? state,
    SessionType? sessionType,
    Task? currentTask,
    int? completedSessions,
    bool clearTask = false,
  }) {
    return TimerStateData(
      timeLeft: timeLeft ?? this.timeLeft,
      totalTime: totalTime ?? this.totalTime,
      state: state ?? this.state,
      sessionType: sessionType ?? this.sessionType,
      currentTask: clearTask ? null : (currentTask ?? this.currentTask),
      completedSessions: completedSessions ?? this.completedSessions,
    );
  }

  double get progress => totalTime > 0 ? (totalTime - timeLeft) / totalTime : 0;
}

enum SessionType { focus, shortBreak, longBreak }

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

final timerProvider =
    StateNotifierProvider<TimerNotifier, TimerStateData>((ref) {
  final taskRepo = ref.watch(taskRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return TimerNotifier(taskRepo, settingsRepo);
});

class TimerNotifier extends StateNotifier<TimerStateData>
    with WidgetsBindingObserver {
  final TaskRepository _taskRepo;
  final SettingsRepository _settingsRepo;
  Timer? _timer;
  int? _startTime;

  TimerNotifier(this._taskRepo, this._settingsRepo)
      : super(TimerStateData(
          timeLeft: 25 * 60,
          totalTime: 25 * 60,
          state: TimerState.idle,
          sessionType: SessionType.focus,
        )) {
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  void _loadSettings() {
    final focusDuration = _settingsRepo.focusDuration;
    state = state.copyWith(
      timeLeft: focusDuration * 60,
      totalTime: focusDuration * 60,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.paused) {
      if (state.state == TimerState.running) {
        _timer?.cancel();
      }
    } else if (lifecycleState == AppLifecycleState.resumed) {
      if (state.state == TimerState.running) {
        _startTimer();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  void selectTask(Task task) {
    state = state.copyWith(currentTask: task);
  }

  void clearTask() {
    state = state.copyWith(clearTask: true);
  }

  void startTimer({Task? task}) {
    if (task != null) {
      state = state.copyWith(currentTask: task);
    }

    state = state.copyWith(state: TimerState.running);
    _startTime = DateTime.now().millisecondsSinceEpoch;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.timeLeft > 0) {
        state = state.copyWith(timeLeft: state.timeLeft - 1);
      } else {
        _onTimerComplete();
      }
    });
  }

  void pauseTimer() {
    _timer?.cancel();
    state = state.copyWith(state: TimerState.paused);
  }

  void resumeTimer() {
    state = state.copyWith(state: TimerState.running);
    _startTimer();
  }

  void toggleTimer() {
    if (state.state == TimerState.running) {
      pauseTimer();
    } else {
      resumeTimer();
    }
  }

  void resetTimer() {
    _timer?.cancel();
    final duration = state.sessionType == SessionType.focus
        ? _settingsRepo.focusDuration * 60
        : state.sessionType == SessionType.shortBreak
            ? _settingsRepo.breakDuration * 60
            : _settingsRepo.longBreakDuration * 60;
    state = state.copyWith(
      timeLeft: duration,
      totalTime: duration,
      state: TimerState.idle,
    );
  }

  void abandonSession() {
    _timer?.cancel();
    resetTimer();
    state = state.copyWith(clearTask: true);
  }

  Future<void> _onTimerComplete() async {
    _timer?.cancel();
    state = state.copyWith(state: TimerState.completed);

    if (state.sessionType == SessionType.focus && _startTime != null) {
      final session = FocusSession(
        id: const Uuid().v4(),
        taskId: state.currentTask?.id,
        taskTitle: state.currentTask?.title,
        subject: state.currentTask?.subject ?? '其他',
        startTime: _startTime!,
        duration: state.totalTime,
        type: 'focus',
        dateKey: TimeFormatter.getTodayKey(),
      );
      await _taskRepo.addSession(session);

      if (state.currentTask != null) {
        await _taskRepo.completeTask(state.currentTask!.id);
      }

      final newCompletedSessions = state.completedSessions + 1;
      state = state.copyWith(completedSessions: newCompletedSessions);
    }

    _startTime = null;
  }

  void startBreak() {
    final isLongBreak =
        (state.completedSessions > 0) &&
        (state.completedSessions % _settingsRepo.longBreakInterval == 0);
    final breakDuration = isLongBreak
        ? _settingsRepo.longBreakDuration * 60
        : _settingsRepo.breakDuration * 60;

    state = state.copyWith(
      timeLeft: breakDuration,
      totalTime: breakDuration,
      state: TimerState.idle,
      sessionType: isLongBreak ? SessionType.longBreak : SessionType.shortBreak,
    );
  }

  void switchToFocus() {
    final focusDuration = _settingsRepo.focusDuration * 60;
    state = state.copyWith(
      timeLeft: focusDuration,
      totalTime: focusDuration,
      state: TimerState.idle,
      sessionType: SessionType.focus,
    );
  }

  void setDuration(int minutes) {
    if (state.state == TimerState.idle) {
      state = state.copyWith(
        timeLeft: minutes * 60,
        totalTime: minutes * 60,
      );
    }
  }
}
