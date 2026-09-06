import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'core/services/session_feedback_service.dart';
import 'data/repositories/settings_repository.dart';
import 'data/repositories/feynman_repository.dart';
import 'providers/feynman_provider.dart';
import 'data/repositories/task_repository.dart';
import 'providers/session_feedback_provider.dart';
import 'providers/timer_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
    );
    await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    final taskRepository = TaskRepository();
    await taskRepository.init();
    final feynmanRepository = FeynmanRepository();
    await feynmanRepository.init();
    final settingsRepository = SettingsRepository();
    await settingsRepository.init();
    final feedbackService = SessionFeedbackService();
    await feedbackService.initialize();

    runApp(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(taskRepository),
          settingsRepositoryProvider.overrideWithValue(settingsRepository),
          feynmanRepositoryProvider.overrideWithValue(feynmanRepository),
          sessionFeedbackServiceProvider.overrideWithValue(feedbackService),
        ],
        child: const QingzhouApp(),
      ),
    );
  } catch (error, stackTrace) {
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'qingzhou bootstrap',
        context: ErrorDescription('while initializing local application data'),
      ),
    );
    runApp(StartupErrorApp(error: error));
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({required this.error, super.key});
  final Object error;

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 20),
                const Text('轻舟暂时无法启动', style: TextStyle(fontSize: 22)),
                const SizedBox(height: 12),
                const Text(
                  '本地数据初始化失败。请完全关闭应用后重试；如果问题持续，请先保留数据并联系开发者。',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  error.runtimeType.toString(),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
