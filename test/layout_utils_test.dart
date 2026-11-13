import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/core/utils/layout_utils.dart';

void main() {
  group('LayoutUtils', () {
    testWidgets('availableHeight 扣掉安全区与键盘遮挡', (tester) async {
      late double height;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            padding: EdgeInsets.only(top: 24, bottom: 34),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Builder(
            builder: (context) {
              height = LayoutUtils.availableHeight(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      // 640 - (24 + 34) - 300 = 282
      expect(height, closeTo(282, 0.001));
    });

    testWidgets('availableWidth 扣掉左右安全区', (tester) async {
      late double width;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            padding: EdgeInsets.only(left: 10, right: 10),
          ),
          child: Builder(
            builder: (context) {
              width = LayoutUtils.availableWidth(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(width, closeTo(340, 0.001));
    });

    testWidgets('isCompactHeight 在横屏/键盘弹起时为 true', (tester) async {
      Future<bool> compactFor(MediaQueryData data) async {
        late bool value;
        await tester.pumpWidget(
          MediaQuery(
            data: data,
            child: Builder(
              builder: (context) {
                value = LayoutUtils.isCompactHeight(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
        return value;
      }

      expect(
        await compactFor(const MediaQueryData(size: Size(640, 360))),
        isTrue,
      );
      expect(
        await compactFor(const MediaQueryData(size: Size(360, 800))),
        isFalse,
      );
      // 键盘弹起后剩余高度不足阈值
      expect(
        await compactFor(
          const MediaQueryData(
            size: Size(360, 800),
            viewInsets: EdgeInsets.only(bottom: 400),
          ),
        ),
        isTrue,
      );
    });

    testWidgets('ClampedTextScale 把 2.0 的字体缩放压到上限', (tester) async {
      late double inside;
      late double outside;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(2.0),
          ),
          child: Builder(
            builder: (context) {
              outside = MediaQuery.textScalerOf(context).scale(10);
              return ClampedTextScale(
                child: Builder(
                  builder: (context) {
                    inside = MediaQuery.textScalerOf(context).scale(10);
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );
      expect(outside, closeTo(20, 0.001));
      expect(inside, closeTo(10 * LayoutUtils.maxTextScaleFactor, 0.001));
      expect(inside, lessThan(outside));
    });

    testWidgets('ClampedTextScale 不放大本就较小的缩放', (tester) async {
      late double inside;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(360, 640),
            textScaler: TextScaler.linear(1.1),
          ),
          child: ClampedTextScale(
            child: Builder(
              builder: (context) {
                inside = MediaQuery.textScalerOf(context).scale(10);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(inside, closeTo(11, 0.001));
    });
  });
}
