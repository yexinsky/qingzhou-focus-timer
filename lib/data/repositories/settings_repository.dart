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
  static const String _screenAlwaysOnKey = 'screen_always_on';
  static const String _firstLaunchKey = 'first_launch';
  static const String _whiteNoiseSoundIdKey = 'white_noise_sound_id';
  static const String _whiteNoiseVolumeKey = 'white_noise_volume';
  static const String _ambientSoundsKey = 'ambient_sounds_json';
  static const String _ambientLoopPlaylistKey = 'ambient_loop_playlist';
  static const String _dailyGoalsKey = 'daily_goals_json';
  static const String _defaultDailyGoalKey = 'default_daily_goal';

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

  bool get screenAlwaysOn => _prefs.getBool(_screenAlwaysOnKey) ?? true;
  Future<void> setScreenAlwaysOn(bool enabled) =>
      _prefs.setBool(_screenAlwaysOnKey, enabled);

  String? get whiteNoiseSoundId => _prefs.getString(_whiteNoiseSoundIdKey);
  Future<void> setWhiteNoiseSoundId(String? id) {
    if (id == null) return _prefs.remove(_whiteNoiseSoundIdKey);
    return _prefs.setString(_whiteNoiseSoundIdKey, id);
  }

  double get whiteNoiseVolume => _prefs.getDouble(_whiteNoiseVolumeKey) ?? 0.5;
  Future<void> setWhiteNoiseVolume(double vol) =>
      _prefs.setDouble(_whiteNoiseVolumeKey, vol);

  String get ambientSoundsJson => _prefs.getString(_ambientSoundsKey) ?? '[]';
  Future<void> setAmbientSoundsJson(String json) {
    return _prefs.setString(_ambientSoundsKey, json);
  }

  bool get ambientLoopPlaylist => _prefs.getBool(_ambientLoopPlaylistKey) ?? false;
  Future<void> setAmbientLoopPlaylist(bool value) =>
      _prefs.setBool(_ambientLoopPlaylistKey, value);

  /// 每日目标：{ "yyyy-MM-dd": 段数 }
  String get dailyGoalsJson => _prefs.getString(_dailyGoalsKey) ?? '{}';
  Future<void> setDailyGoalsJson(String json) =>
      _prefs.setString(_dailyGoalsKey, json);

  int get defaultDailyGoal => _prefs.getInt(_defaultDailyGoalKey) ?? 8;
  Future<void> setDefaultDailyGoal(int count) =>
      _prefs.setInt(_defaultDailyGoalKey, count);

  String? getString(String key) => _prefs.getString(key);
  Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  Future<bool> remove(String key) => _prefs.remove(key);

  bool get isFirstLaunch => _prefs.getBool(_firstLaunchKey) ?? true;
  Future<void> setFirstLaunchComplete() =>
      _prefs.setBool(_firstLaunchKey, false);
}
