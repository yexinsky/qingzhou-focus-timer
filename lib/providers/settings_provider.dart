import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/settings_repository.dart';
import 'timer_provider.dart';

class SettingsState {
  final int focusDuration;
  final int breakDuration;
  final int longBreakDuration;
  final int longBreakInterval;
  final bool strictMode;
  final bool autoWhiteNoise;
  final bool notificationEnabled;
  final bool vibrationEnabled;

  SettingsState({
    required this.focusDuration,
    required this.breakDuration,
    required this.longBreakDuration,
    required this.longBreakInterval,
    required this.strictMode,
    required this.autoWhiteNoise,
    required this.notificationEnabled,
    required this.vibrationEnabled,
  });

  SettingsState copyWith({
    int? focusDuration,
    int? breakDuration,
    int? longBreakDuration,
    int? longBreakInterval,
    bool? strictMode,
    bool? autoWhiteNoise,
    bool? notificationEnabled,
    bool? vibrationEnabled,
  }) {
    return SettingsState(
      focusDuration: focusDuration ?? this.focusDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      longBreakDuration: longBreakDuration ?? this.longBreakDuration,
      longBreakInterval: longBreakInterval ?? this.longBreakInterval,
      strictMode: strictMode ?? this.strictMode,
      autoWhiteNoise: autoWhiteNoise ?? this.autoWhiteNoise,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, SettingsState>(
  (ref) {
    final settingsRepo = ref.watch(settingsRepositoryProvider);
    return SettingsNotifier(settingsRepo);
  },
);

class SettingsNotifier extends StateNotifier<SettingsState> {
  final SettingsRepository _settingsRepo;

  SettingsNotifier(this._settingsRepo)
    : super(
        SettingsState(
          focusDuration: _settingsRepo.focusDuration,
          breakDuration: _settingsRepo.breakDuration,
          longBreakDuration: _settingsRepo.longBreakDuration,
          longBreakInterval: _settingsRepo.longBreakInterval,
          strictMode: _settingsRepo.strictMode,
          autoWhiteNoise: _settingsRepo.autoWhiteNoise,
          notificationEnabled: _settingsRepo.notificationEnabled,
          vibrationEnabled: _settingsRepo.vibrationEnabled,
        ),
      );

  Future<void> setFocusDuration(int minutes) async {
    await _settingsRepo.setFocusDuration(minutes);
    state = state.copyWith(focusDuration: minutes);
  }

  Future<void> setBreakDuration(int minutes) async {
    await _settingsRepo.setBreakDuration(minutes);
    state = state.copyWith(breakDuration: minutes);
  }

  Future<void> setLongBreakDuration(int minutes) async {
    await _settingsRepo.setLongBreakDuration(minutes);
    state = state.copyWith(longBreakDuration: minutes);
  }

  Future<void> setLongBreakInterval(int sessions) async {
    await _settingsRepo.setLongBreakInterval(sessions);
    state = state.copyWith(longBreakInterval: sessions);
  }

  Future<void> toggleStrictMode() async {
    final newValue = !state.strictMode;
    await _settingsRepo.setStrictMode(newValue);
    state = state.copyWith(strictMode: newValue);
  }

  Future<void> toggleAutoWhiteNoise() async {
    final newValue = !state.autoWhiteNoise;
    await _settingsRepo.setAutoWhiteNoise(newValue);
    state = state.copyWith(autoWhiteNoise: newValue);
  }

  Future<void> setNotificationEnabled(bool enabled) async {
    await _settingsRepo.setNotificationEnabled(enabled);
    state = state.copyWith(notificationEnabled: enabled);
  }

  Future<void> setVibrationEnabled(bool enabled) async {
    await _settingsRepo.setVibrationEnabled(enabled);
    state = state.copyWith(vibrationEnabled: enabled);
  }
}
