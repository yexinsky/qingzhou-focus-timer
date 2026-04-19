import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qingzhou_focus/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: QingzhouApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('专注'), findsWidgets);
  });
}
