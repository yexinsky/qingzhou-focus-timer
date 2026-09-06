import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Platform feedback used when a focus or break session finishes.
class SessionFeedbackService {
  SessionFeedbackService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'qingzhou_session_completion';
  static const _channelName = '专注计时提醒';
  static const _channelDescription = '专注或休息计时结束时提醒';

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings();
    await _notifications.initialize(
      const InitializationSettings(
        android: android,
        iOS: darwin,
        macOS: darwin,
      ),
    );
    _initialized = true;
  }

  Future<bool> requestNotificationPermission() async {
    await initialize();
    if (kIsWeb) return false;
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null)
      return await android.requestNotificationsPermission() ?? false;
    final ios = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null)
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    return false;
  }

  Future<void> openNotificationSettings() async {
    await initialize();
    if (kIsWeb) return;
    await _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }

  Future<void> notifySessionCompleted({
    required bool isFocusSession,
    required bool notificationsEnabled,
    required bool vibrationEnabled,
  }) async {
    if (notificationsEnabled) {
      await initialize();
      if (!kIsWeb) {
        await _notifications.show(
          1001,
          isFocusSession ? '专注完成' : '休息结束',
          isFocusSession ? '做得很好，休息一下再继续。' : '准备好后，开始下一轮专注吧。',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
              enableVibration: false,
            ),
            iOS: DarwinNotificationDetails(presentSound: true),
            macOS: DarwinNotificationDetails(presentSound: true),
          ),
        );
      }
    }
    if (vibrationEnabled && !kIsWeb && (await Vibration.hasVibrator())) {
      await Vibration.vibrate(duration: 350);
    }
  }
}
