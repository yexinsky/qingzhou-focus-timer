import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../views/main_shell.dart';
import '../views/focus/focus_view.dart';
import '../views/plan/plan_view.dart';
import '../views/stats/stats_view.dart';
import '../views/settings/settings_view.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/focus',
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/focus',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const FocusView(),
          ),
        ),
        GoRoute(
          path: '/plan',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const PlanView(),
          ),
        ),
        GoRoute(
          path: '/stats',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const StatsView(),
          ),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const SettingsView(),
          ),
        ),
      ],
    ),
  ],
);

CustomTransitionPage _buildPage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        )),
        child: child,
      );
    },
  );
}
