import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/core/constants/motivational_quotes.dart';
import 'package:qingzhou_focus/core/widgets/splash_overlay.dart';

void main() {
  String logoAssetOf(WidgetTester tester) {
    final provider = tester.widget<Image>(find.byType(Image)).image;
    // 传了 cacheWidth 时 Image.asset 会包一层 ResizeImage，这里取出内层资产
    final asset = provider is ResizeImage ? provider.imageProvider : provider;
    return (asset as AssetImage).assetName;
  }

  testWidgets('展示 logo 与励志语句，停留期满后淡出并回调', (tester) async {
    var finished = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SplashOverlay(quote: '日拱一卒，功不唐捐', onFinished: () => finished++),
      ),
    );

    expect(find.text('日拱一卒，功不唐捐'), findsOneWidget);
    // 浅色底用纸色版 logo：主色版的深绿底块在近白背景上过重
    expect(logoAssetOf(tester), 'design/logo/logo_cream.png');

    // 逐帧推进：先让淡入跑完，再逼近停留期终点
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 2500));
    expect(finished, 0, reason: '停留期内不应回调');

    // 停留期满触发淡出，有限动画应能被 pumpAndSettle 收敛
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pumpAndSettle();
    expect(finished, 1, reason: '淡出结束后回调一次');
  });

  testWidgets('深色模式使用深色版 logo，卸载后不残留定时器', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        home: SplashOverlay(quote: '先把今天划过去', onFinished: () {}),
      ),
    );

    expect(logoAssetOf(tester), 'design/logo/logo_dark.png');

    // 提前卸载：若 dispose 未取消停留定时器，测试收尾会报 pending timer
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(kSplashDuration);
    expect(find.byType(SplashOverlay), findsNothing);
  });

  test('语句清单非空且无重复，随机选取落在清单内', () {
    expect(MotivationalQuotes.all, isNotEmpty);
    expect(
      MotivationalQuotes.all.toSet(),
      hasLength(MotivationalQuotes.all.length),
    );
    expect(
      MotivationalQuotes.all,
      contains(MotivationalQuotes.pick(Random(7))),
    );
  });
}
