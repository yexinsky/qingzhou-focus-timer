import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const String _focusDurationKey = 'focus_duration';
  static const String _breakDurationKey = 'break_duration';
  static const String _longBreakDurationKey = 'long_break_duration';
  static const String _longBreakIntervalKey = 'long_break_interval';
  static const String _strictModeKey = 'strict_mode';
  static const String _autoWhiteNoiseKey = 'auto_white_noise';
  static const String _notificationEnabledKey = 'notification_enabled';
  static const String _vibrationEnabledKey = 'vibration_enabled';
  static const String _firstLaunchKey = 'first_launch';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  int get focusDuration => _prefs.getInt(_focusDurationKey) ?? 25;
  Future<void> setFocusDuration(int minutes) =>
      _prefs.setInt(_focusDurationKey, minutes);

  int get breakDuration => _prefs.getInt(_breakDurationKey) ?? 5;
  Future<void> setBreakDuration(int minutes) =>
      _prefs.setInt(_breakDurationKey, minutes);

  int get longBreakDuration => _prefs.getInt(_longBreakDurationKey) ?? 15;
  Future<void> setLongBreakDuration(int minutes) =>
      _prefs.setInt(_longBreakDurationKey, minutes);

  int get longBreakInterval => _prefs.getInt(_longBreakIntervalKey) ?? 4;
  Future<void> setLongBreakInterval(int sessions) =>
      _prefs.setInt(_longBreakIntervalKey, sessions);

  bool get strictMode => _prefs.getBool(_strictModeKey) ?? false;
  Future<void> setStrictMode(bool enabled) =>
      _prefs.setBool(_strictModeKey, enabled);

  bool get autoWhiteNoise => _prefs.getBool(_autoWhiteNoiseKey) ?? false;
  Future<void> setAutoWhiteNoise(bool enabled) =>
      _prefs.setBool(_autoWhiteNoiseKey, enabled);

  bool get notificationEnabled =>
      _prefs.getBool(_notificationEnabledKey) ?? false;
  Future<void> setNotificationEnabled(bool enabled) =>
      _prefs.setBool(_notificationEnabledKey, enabled);

  bool get vibrationEnabled => _prefs.getBool(_vibrationEnabledKey) ?? true;
  Future<void> setVibrationEnabled(bool enabled) =>
      _prefs.setBool(_vibrationEnabledKey, enabled);

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<bool> remove(String key) => _prefs.remove(key);

  bool get isFirstLaunch => _prefs.getBool(_firstLaunchKey) ?? true;
  Future<void> setFirstLaunchComplete() =>
      _prefs.setBool(_firstLaunchKey, false);
}
