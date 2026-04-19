import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'router/app_router.dart';

class QingzhouApp extends StatelessWidget {
  const QingzhouApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '轻舟',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      routerConfig: appRouter,
    );
  }
}
