import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/models/task.dart';
import '../data/models/focus_session.dart';
import '../data/repositories/task_repository.dart';
import '../data/repositories/settings_repository.dart';
import '../core/services/session_feedback_service.dart';
import 'session_feedback_provider.dart';
import 'stats_provider.dart';

enum TimerState { idle, running, paused, completed }

enum SessionType { focus, shortBreak, longBreak }

enum FocusTimerMode { countdown, stopwatch }

class TimerStateData {
  final int timeLeft;
  final int totalTime;
  final TimerState state;
  final SessionType sessionType;
  final Task? currentTask;
  final int completedSessions;
  final FocusTimerMode focusTimerMode;

  TimerStateData({
    required this.timeLeft,
    required this.totalTime,
    required this.state,
    required this.sessionType,
    this.currentTask,
    this.completedSessions = 0,
    this.focusTimerMode = FocusTimerMode.countdown,
  });

  TimerStateData copyWith({
    int? timeLeft,
    int? totalTime,
    TimerState? state,
    SessionType? sessionType,
    Task? currentTask,
    int? completedSessions,
    FocusTimerMode? focusTimerMode,
    bool clearTask = false,
  }) => TimerStateData(
    timeLeft: timeLeft ?? this.timeLeft,
    totalTime: totalTime ?? this.totalTime,
    state: state ?? this.state,
    sessionType: sessionType ?? this.sessionType,
    currentTask: clearTask ? null : (currentTask ?? this.currentTask),
    completedSessions: completedSessions ?? this.completedSessions,
    focusTimerMode: focusTimerMode ?? this.focusTimerMode,
  );

  bool get isFlexible => focusTimerMode == FocusTimerMode.stopwatch;

  int get displayedSeconds => isFlexible ? totalTime : timeLeft;

  double get progress =>
      isFlexible ? 0 : (totalTime > 0 ? (totalTime - timeLeft) / totalTime : 0);
}

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(),
);
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);
final timerProvider = StateNotifierProvider<TimerNotifier, TimerStateData>((
  ref,
) {
  return TimerNotifier(
    ref.watch(taskRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
    feedbackService: ref.watch(sessionFeedbackServiceProvider),
    onSessionRecorded: () {
      ref.read(statsRefreshProvider.notifier).state++;
    },
  );
});

class TimerNotifier extends StateNotifier<TimerStateData>
    with WidgetsBindingObserver {
  static const _snapshotKey = 'timer_session_snapshot_v1';
  final TaskRepository _taskRepo;
  final SettingsRepository _settingsRepo;
  final DateTime Function() _now;
  final Uuid _uuid;
  final SessionFeedbackService? _feedbackService;
  final void Function()? _onSessionRecorded;
  Timer? _timer;
  int? _startedAt;
  int? _endsAt;
  bool _completing = false;

  TimerNotifier(
    this._taskRepo,
    this._settingsRepo, {
    DateTime Function()? now,
    Uuid? uuid,
    SessionFeedbackService? feedbackService,
    void Function()? onSessionRecorded,
  }) : _now = now ?? DateTime.now,
       _uuid = uuid ?? const Uuid(),
       _feedbackService = feedbackService,
       _onSessionRecorded = onSessionRecorded,
       super(
         TimerStateData(
           timeLeft: 25 * 60,
           totalTime: 25 * 60,
           state: TimerState.idle,
           sessionType: SessionType.focus,
         ),
       ) {
    WidgetsBinding.instance.addObserver(this);
    _restoreSnapshot();
  }

  void _restoreSnapshot() {
    final raw = _settingsRepo.getString(_snapshotKey);
    if (raw == null) {
      _loadDefaultDuration();
      return;
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final savedState = TimerState.values.byName(data['state'] as String);
      final sessionType = SessionType.values.byName(
        data['sessionType'] as String,
      );
      final taskData = data['task'] as Map<String, dynamic>?;
      state = TimerStateData(
        timeLeft: data['timeLeft'] as int,
        totalTime: data['totalTime'] as int,
        state: savedState,
        sessionType: sessionType,
        currentTask: taskData == null ? null : Task.fromJson(taskData),
        completedSessions: data['completedSessions'] as int? ?? 0,
        focusTimerMode: FocusTimerMode.values.byName(
          data['focusTimerMode'] as String? ?? 'countdown',
        ),
      );
      _startedAt = data['startedAt'] as int?;
      _endsAt = data['endsAt'] as int?;
      if (savedState == TimerState.running && _endsAt != null) {
        _syncWithClock();
        if (state.state == TimerState.running) _startTicker();
      }
    } catch (_) {
      _clearSnapshot();
      _loadDefaultDuration();
    }
  }

  void _loadDefaultDuration() {
    final seconds = _settingsRepo.focusDuration * 60;
    state = state.copyWith(timeLeft: seconds, totalTime: seconds);
  }

  Future<void> _persistSnapshot() => _settingsRepo.setString(
    _snapshotKey,
    jsonEncode({
      'timeLeft': state.timeLeft,
      'totalTime': state.totalTime,
      'state': state.state.name,
      'sessionType': state.sessionType.name,
      'task': state.currentTask?.toJson(),
      'completedSessions': state.completedSessions,
      'focusTimerMode': state.focusTimerMode.name,
      'startedAt': _startedAt,
      'endsAt': _endsAt,
    }),
  );

  Future<void> _clearSnapshot() => _settingsRepo.remove(_snapshotKey);

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycleState) {
    if (lifecycleState == AppLifecycleState.resumed &&
        state.state == TimerState.running) {
      _syncWithClock();
      if (state.state == TimerState.running) _startTicker();
    } else if (lifecycleState == AppLifecycleState.paused ||
        lifecycleState == AppLifecycleState.inactive ||
        lifecycleState == AppLifecycleState.detached) {
      _timer?.cancel();
      if (state.state == TimerState.running) _persistSnapshot();
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
    _persistSnapshot();
  }

  void clearTask() {
    state = state.copyWith(clearTask: true);
    _persistSnapshot();
  }

  void startTimer({Task? task}) {
    if (state.state == TimerState.running ||
        state.state == TimerState.completed)
      return;
    if (task != null) state = state.copyWith(currentTask: task);
    final now = _now().millisecondsSinceEpoch;
    _startedAt ??= now;
    _endsAt = state.isFlexible ? now : now + state.timeLeft * 1000;
    state = state.copyWith(state: TimerState.running);
    _persistSnapshot();
    _startTicker();
  }

  void _startTicker() {
    _timer?.cancel();
    _syncWithClock();
    if (state.state != TimerState.running) return;
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _syncWithClock(),
    );
  }

  void _syncWithClock() {
    if (state.state != TimerState.running || _endsAt == null) return;
    if (state.isFlexible) {
      final seconds = ((_now().millisecondsSinceEpoch - _endsAt!) / 1000)
          .floor();
      if (seconds >= 0 && seconds != state.totalTime) {
        state = state.copyWith(totalTime: seconds, timeLeft: 0);
      }
      return;
    }
    final milliseconds = _endsAt! - _now().millisecondsSinceEpoch;
    final seconds = milliseconds <= 0 ? 0 : (milliseconds / 1000).ceil();
    if (seconds != state.timeLeft) state = state.copyWith(timeLeft: seconds);
    if (seconds == 0) _onTimerComplete();
  }

  void pauseTimer() {
    if (state.state != TimerState.running) return;
    _syncWithClock();
    if (state.state != TimerState.running) return;
    _timer?.cancel();
    _endsAt = null;
    state = state.copyWith(state: TimerState.paused);
    _persistSnapshot();
  }

  void resumeTimer() {
    if (state.state == TimerState.paused) {
      if (state.isFlexible) {
        final now = _now().millisecondsSinceEpoch;
        _endsAt = now - state.totalTime * 1000;
        state = state.copyWith(state: TimerState.running);
        _persistSnapshot();
        _startTicker();
      } else {
        startTimer();
      }
    }
  }

  void toggleTimer() {
    state.state == TimerState.running ? pauseTimer() : resumeTimer();
  }

  void resetTimer() {
    _timer?.cancel();
    final duration = _durationFor(state.sessionType);
    _startedAt = null;
    _endsAt = null;
    _completing = false;
    state = state.copyWith(
      timeLeft: state.isFlexible ? 0 : duration,
      totalTime: state.isFlexible ? 0 : duration,
      state: TimerState.idle,
    );
    _clearSnapshot();
  }

  int _durationFor(SessionType type) => type == SessionType.focus
      ? _settingsRepo.focusDuration * 60
      : type == SessionType.shortBreak
      ? _settingsRepo.breakDuration * 60
      : _settingsRepo.longBreakDuration * 60;

  void abandonSession() {
    resetTimer();
    state = state.copyWith(clearTask: true);
  }

  Future<void> _onTimerComplete() async {
    if (_completing || state.state != TimerState.running) return;
    _completing = true;
    _timer?.cancel();
    state = state.copyWith(timeLeft: 0, state: TimerState.completed);
    await _persistSnapshot();
    if (state.sessionType == SessionType.focus && _startedAt != null) {
      final session = FocusSession(
        id: _uuid.v4(),
        taskId: state.currentTask?.id,
        taskTitle: state.currentTask?.title,
        subject: state.currentTask?.subject ?? '其他',
        startTime: _startedAt!,
        duration: state.totalTime,
        type: 'focus',
        timerMode: 'countdown',
        dateKey: _dateKey(DateTime.fromMillisecondsSinceEpoch(_startedAt!)),
      );
      await _taskRepo.addSession(session);
      _onSessionRecorded?.call();
      state = state.copyWith(completedSessions: state.completedSessions + 1);
    }
    await _feedbackService?.notifySessionCompleted(
      isFocusSession: state.sessionType == SessionType.focus,
      notificationsEnabled: _settingsRepo.notificationEnabled,
      vibrationEnabled: _settingsRepo.vibrationEnabled,
    );
    _startedAt = null;
    _endsAt = null;
    _completing = false;
    await _persistSnapshot();
  }

  String _dateKey(DateTime date) =>
      "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";

  void startBreak({bool startImmediately = false}) {
    if (state.sessionType != SessionType.focus ||
        state.state != TimerState.completed)
      return;
    final interval = _settingsRepo.longBreakInterval;
    final isLong =
        interval > 0 &&
        state.completedSessions > 0 &&
        state.completedSessions % interval == 0;
    _prepareSession(
      isLong ? SessionType.longBreak : SessionType.shortBreak,
      clearTask: false,
    );
    if (startImmediately) startTimer();
  }

  void switchToFocus({bool startImmediately = false}) {
    if (state.sessionType == SessionType.focus &&
        state.state == TimerState.running)
      return;
    _prepareSession(SessionType.focus, clearTask: false);
    if (startImmediately) startTimer();
  }

  void _prepareSession(SessionType type, {required bool clearTask}) {
    _timer?.cancel();
    _startedAt = null;
    _endsAt = null;
    _completing = false;
    final duration = _durationFor(type);
    state = state.copyWith(
      timeLeft: duration,
      totalTime: duration,
      state: TimerState.idle,
      sessionType: type,
      clearTask: clearTask,
    );
    _persistSnapshot();
  }

  void setFocusTimerMode(FocusTimerMode mode) {
    if (state.state != TimerState.idle ||
        state.sessionType != SessionType.focus)
      return;
    if (state.focusTimerMode == mode) return;
    final seconds = mode == FocusTimerMode.stopwatch
        ? 0
        : _settingsRepo.focusDuration * 60;
    state = state.copyWith(
      focusTimerMode: mode,
      timeLeft: seconds,
      totalTime: seconds,
    );
    _persistSnapshot();
  }

  Future<bool> finishFlexibleSession() async {
    if (!state.isFlexible ||
        state.sessionType != SessionType.focus ||
        (state.state != TimerState.running &&
            state.state != TimerState.paused) ||
        _completing) {
      return false;
    }
    if (state.state == TimerState.running) _syncWithClock();
    final duration = state.totalTime;
    if (duration <= 0 || _startedAt == null) return false;
    _completing = true;
    _timer?.cancel();
    final session = FocusSession(
      id: _uuid.v4(),
      taskId: state.currentTask?.id,
      taskTitle: state.currentTask?.title,
      subject: state.currentTask?.subject ?? '其他',
      startTime: _startedAt!,
      duration: duration,
      type: 'focus',
      timerMode: 'stopwatch',
      dateKey: _dateKey(DateTime.fromMillisecondsSinceEpoch(_startedAt!)),
    );
    await _taskRepo.addSession(session);
    _onSessionRecorded?.call();
    _timer?.cancel();
    _startedAt = null;
    _endsAt = null;
    _completing = false;
    state = state.copyWith(timeLeft: 0, totalTime: 0, state: TimerState.idle);
    await _clearSnapshot();
    return true;
  }

  void setDuration(int minutes) {
    if (state.state != TimerState.idle || minutes <= 0) return;
    state = state.copyWith(timeLeft: minutes * 60, totalTime: minutes * 60);
    _persistSnapshot();
  }
}
