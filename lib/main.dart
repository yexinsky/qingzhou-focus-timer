import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'data/repositories/task_repository.dart';
import 'data/repositories/settings_repository.dart';
import 'providers/timer_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  final taskRepository = TaskRepository();
  await taskRepository.init();

  final settingsRepository = SettingsRepository();
  await settingsRepository.init();

  runApp(
    ProviderScope(
      overrides: [
        taskRepositoryProvider.overrideWithValue(taskRepository),
        settingsRepositoryProvider.overrideWithValue(settingsRepository),
      ],
      child: const QingzhouApp(),
    ),
  );
}
