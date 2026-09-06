import 'package:flutter_test/flutter_test.dart';
import 'package:qingzhou_focus/data/models/feynman_unit.dart';
import 'package:qingzhou_focus/data/models/stumble_mark.dart';

void main() {
  test('费曼单元 JSON 往返并保留文字草稿', () {
    final u = FeynmanUnit(
      id: 'u',
      title: '极限',
      subject: '数学',
      chapter: '第一章',
      topic: '定义',
      startedAt: 1,
      textOutput: '用自己的话解释',
    );
    final restored = FeynmanUnit.fromJson(u.toJson());
    expect(restored.textOutput, '用自己的话解释');
    expect(restored.outputPlannedSeconds, 600);
  });
  test('输出计划至少为输入的一半', () {
    expect(
      () => FeynmanUnit(
        id: 'u',
        title: 'x',
        subject: '数学',
        startedAt: 1,
        inputPlannedSeconds: 1200,
        outputPlannedSeconds: 599,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
  test('卡点支持匿名先落盘及解决状态', () {
    final m = StumbleMark(
      id: 'm',
      unitId: 'u',
      subject: '数学',
      offsetSeconds: 42,
      createdAt: 2,
    );
    expect(m.keyword, isEmpty);
    final solved = m.copyWith(keyword: '定义', resolved: true, resolvedAt: 3);
    expect(solved.resolved, isTrue);
    expect(StumbleMark.fromJson(solved.toJson()).keyword, '定义');
  });
}
