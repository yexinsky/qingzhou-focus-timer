import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:vibration/vibration.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Platform feedback used when a focus or break session finishes.
class SessionFeedbackService {
  SessionFeedbackService({FlutterLocalNotificationsPlugin? notifications})
    : _notifications = notifications ?? FlutterLocalNotificationsPlugin();

  static const _channelId = 'qingzhou_session_completion';
  static const _channelName = '专注计时提醒';
  static const _channelDescription = '专注或休息计时结束时提醒';

  /// 到点提醒的固定通知 id：开始计时时预排，结束/暂停/放弃时撤销。
  static const _reminderId = 1001;

  final FlutterLocalNotificationsPlugin _notifications;
  bool _initialized = false;
  bool _exactAlarmsAllowed = false;

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
    _initTimezone();
    await _resolveExactAlarmSupport();
    _initialized = true;
  }

  /// zonedSchedule 需要时区数据库与设备本地时区。
  Future<void> _initTimezone() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // 时区名无法解析时保持默认位置；预排时刻可能偏移，但系统通知仍会送达
    }
  }

  Future<void> _resolveExactAlarmSupport() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    _exactAlarmsAllowed =
        await android?.canScheduleExactNotifications() ?? false;
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

  /// 在计时结束时刻预排系统通知，进程被杀或退后台后仍会准点送达。
  Future<void> scheduleSessionEndReminder({
    required int endAtMillis,
    required bool isFocusSession,
  }) async {
    if (kIsWeb) return;
    await initialize();
    await _notifications.zonedSchedule(
      _reminderId,
      isFocusSession ? '专注完成' : '休息结束',
      isFocusSession ? '做得很好，休息一下再继续。' : '准备好后，开始下一轮专注吧。',
      tz.TZDateTime.from(
        DateTime.fromMillisecondsSinceEpoch(endAtMillis),
        tz.local,
      ),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
          enableVibration: true,
          category: AndroidNotificationCategory.alarm,
        ),
        iOS: DarwinNotificationDetails(presentSound: true, presentAlert: true),
        macOS: DarwinNotificationDetails(presentSound: true),
      ),
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      androidScheduleMode: _exactAlarmsAllowed
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  /// 撤销预排的到点提醒（暂停 / 放弃 / 手动结束 / 已完成时调用）。
  Future<void> cancelSessionEndReminder() async {
    if (kIsWeb) return;
    await _notifications.cancel(_reminderId);
  }

  /// 计时完成时的触感反馈；系统通知由预排提醒负责准点送达，这里不再重复发送。
  Future<void> notifySessionCompleted({
    required bool isFocusSession,
    required bool notificationsEnabled,
    required bool vibrationEnabled,
  }) async {
    if (vibrationEnabled && !kIsWeb && (await Vibration.hasVibrator())) {
      await Vibration.vibrate(duration: 350);
    }
  }
}
