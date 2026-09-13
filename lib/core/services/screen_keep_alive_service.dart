import 'package:wakelock_plus/wakelock_plus.dart';

/// 专注进行时的屏幕常亮控制。
/// 插件调用在测试环境或平台不支持时静默失败，不影响计时逻辑。
class ScreenKeepAliveService {
  void enable() {
    try {
      WakelockPlus.enable();
    } catch (_) {}
  }

  void disable() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }
}
