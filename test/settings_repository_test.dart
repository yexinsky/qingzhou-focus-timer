import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/repositories/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = SettingsRepository();
    await repository.init();
  });

  test('defaults match product defaults', () {
    expect(repository.focusDuration, 25);
    expect(repository.breakDuration, 5);
    expect(repository.longBreakDuration, 15);
    expect(repository.longBreakInterval, 4);
    expect(repository.strictMode, isFalse);
    expect(repository.autoWhiteNoise, isFalse);
    expect(repository.notificationEnabled, isFalse);
    expect(repository.vibrationEnabled, isTrue);
    expect(repository.screenAlwaysOn, isTrue);
    expect(repository.isFirstLaunch, isTrue);
  });

  test('all settings persist through repository accessors', () async {
    await repository.setFocusDuration(45);
    await repository.setBreakDuration(10);
    await repository.setLongBreakDuration(20);
    await repository.setLongBreakInterval(3);
    await repository.setStrictMode(true);
    await repository.setAutoWhiteNoise(true);
    await repository.setNotificationEnabled(true);
    await repository.setVibrationEnabled(false);
    await repository.setScreenAlwaysOn(false);
    await repository.setFirstLaunchComplete();
    expect(repository.focusDuration, 45);
    expect(repository.breakDuration, 10);
    expect(repository.longBreakDuration, 20);
    expect(repository.longBreakInterval, 3);
    expect(repository.strictMode, isTrue);
    expect(repository.autoWhiteNoise, isTrue);
    expect(repository.notificationEnabled, isTrue);
    expect(repository.vibrationEnabled, isFalse);
    expect(repository.screenAlwaysOn, isFalse);
    expect(repository.isFirstLaunch, isFalse);
  });

  test('generic string storage supports timer snapshots', () async {
    expect(repository.getString('snapshot'), isNull);
    expect(
      await repository.setString('snapshot', '{"state":"paused"}'),
      isTrue,
    );
    expect(repository.getString('snapshot'), '{"state":"paused"}');
    expect(await repository.remove('snapshot'), isTrue);
    expect(repository.getString('snapshot'), isNull);
  });
}
