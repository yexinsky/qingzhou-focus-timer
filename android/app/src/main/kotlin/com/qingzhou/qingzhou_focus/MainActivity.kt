package com.qingzhou.qingzhou_focus

import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_NAME)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> {
                        // 参数为空说明 Dart 侧调用有误，直接拒绝，避免误装其它文件
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("invalid_args", "缺少 APK 路径参数 path", null)
                            return@setMethodCallHandler
                        }
                        // 先判断文件是否存在，给出比底层异常更明确的错误码
                        val apkFile = File(path)
                        if (!apkFile.exists()) {
                            result.error("file_missing", "APK 文件不存在: $path", null)
                            return@setMethodCallHandler
                        }
                        try {
                            // 通过 FileProvider 生成 content:// URI 并临时授权，
                            // 否则 Android 7+ 直接暴露 file:// 会抛 FileUriExposedException
                            val apkUri = FileProvider.getUriForFile(
                                this,
                                "$packageName.fileprovider",
                                apkFile
                            )
                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, APK_MIME_TYPE)
                                // 系统安装器属于新的任务栈，且需临时读权限才能读取该 URI
                                flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or
                                    Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(installIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            // 常见原因：未开启"安装未知应用"、系统无安装器、缓存文件被清理
                            result.error("install_failed", e.message ?: e.toString(), null)
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val CHANNEL_NAME = "qingzhou/apk_installer"
        const val APK_MIME_TYPE = "application/vnd.android.package-archive"
    }
}
