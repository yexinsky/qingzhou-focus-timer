import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets('Android back returns from pushed secondary page to parent', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/parent',
      routes: [
        GoRoute(
          path: '/parent',
          builder: (context, state) => Scaffold(
            body: Column(
              children: [
                const Text('父页面'),
                TextButton(
                  onPressed: () => context.push('/secondary'),
                  child: const Text('进入二级页面'),
                ),
              ],
            ),
          ),
        ),
        GoRoute(
          path: '/secondary',
          builder: (context, state) => const Scaffold(body: Text('二级页面')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('进入二级页面'));
    await tester.pumpAndSettle();
    expect(find.text('二级页面'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('父页面'), findsOneWidget);
    expect(find.text('二级页面'), findsNothing);
  });

  testWidgets('direct secondary route supplies a parent for Android back', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/secondary',
      routes: [
        GoRoute(
          path: '/parent',
          builder: (context, state) => const Scaffold(body: Text('父页面')),
        ),
        GoRoute(
          path: '/secondary',
          builder: (context, state) => const Scaffold(body: Text('二级页面')),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    expect(find.text('二级页面'), findsOneWidget);

    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(handled, isFalse);
    expect(find.text('二级页面'), findsOneWidget);
  });
}
