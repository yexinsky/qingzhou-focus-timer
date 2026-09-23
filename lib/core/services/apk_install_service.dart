import 'dart:io';

import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// 应用内安装 APK。
///
/// Android 上经 MethodChannel（qingzhou/apk_installer，实现见 MainActivity）
/// 调起系统安装器；"安装未知应用"权限经 permission_handler 跳系统设置页申请。
/// 非 Android 平台 [isSupported] 为 false，调用方回退到浏览器下载。
class ApkInstallService {
  ApkInstallService({bool? isAndroid, MethodChannel? channel})
    : _isAndroid = isAndroid ?? Platform.isAndroid,
      _channel = channel ?? const MethodChannel('qingzhou/apk_installer');

  final bool _isAndroid;
  final MethodChannel _channel;

  bool get isSupported => _isAndroid;

  Future<bool> hasInstallPermission() async {
    if (!_isAndroid) return false;
    return Permission.requestInstallPackages.isGranted;
  }

  /// 跳转系统"安装未知应用"设置页；用户返回后按实际授权结果返回。
  Future<bool> requestInstallPermission() async {
    if (!_isAndroid) return false;
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  /// 调起系统安装器安装 [filePath]（须位于 cacheDir/update/ 下）。
  Future<void> installApk(String filePath) async {
    if (!_isAndroid) return;
    await _channel.invokeMethod<bool>('install', {'path': filePath});
  }
}
